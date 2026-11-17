#define _GNU_SOURCE
#include <ruby.h>
#include <ruby/debug.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Objects allocated per source line inside request windows (lowrail/profile).
 * One internal NEWOBJ hook, as objspace's allocation tracing uses, but it keeps
 * counts instead of per-object records, so GC stays on and nothing is retained.
 * The hook never allocates Ruby objects or calls Ruby; its tables use libc
 * malloc so it cannot start a GC. Lines are attributed like
 * ObjectSpace.allocation_sourcefile/sourceline: the nearest Ruby frame. */

typedef struct {
    uint64_t key;      /* path id << 37 | line << 5 | ruby type; 0 = empty */
    uint64_t count;
    uint64_t requests; /* request windows in which the line allocated */
    uint64_t last;     /* last request window seen */
    uint64_t first;    /* objects in the first window that reached the line */
    uint64_t first_window;
} site_t;

static site_t *sites;
static size_t sites_cap, sites_len;

static char **paths;
static size_t *path_lens;
static size_t paths_len, paths_cap;
static size_t *path_index; /* open addressing: path id + 1; 0 = empty */
static size_t path_index_cap;

static struct { VALUE str; size_t id; } path_cache[1024];

/* Watched lines (path id + 1 << 32 | line) and, per watched allocation, the
 * nearest frame under the app root: key = site, caller = caller site. */
typedef struct { uint64_t site, caller, count; } caller_t;
static uint64_t *watched;
static size_t watched_cap;
static caller_t *callers;
static size_t callers_cap, callers_len;
static char *app_root;
static size_t app_root_len;

static uint64_t requests, objects, window_seq, dropped;
static __thread int depth;
static __thread uint64_t window;
static VALUE tracepoint = Qnil;

static uint64_t
mix(uint64_t x)
{
    x ^= x >> 33; x *= 0xff51afd7ed558ccdULL; x ^= x >> 33;
    return x;
}

static uint64_t
str_hash(const char *p, size_t n)
{
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) h = (h ^ (unsigned char)p[i]) * 1099511628211ULL;
    return h;
}

static int
path_index_grow(void)
{
    size_t cap = path_index_cap ? path_index_cap * 2 : 1024;
    size_t *index = calloc(cap, sizeof(size_t));
    if (!index) return 0;
    for (size_t id = 0; id < paths_len; id++) {
        size_t i = str_hash(paths[id], path_lens[id]) & (cap - 1);
        while (index[i]) i = (i + 1) & (cap - 1);
        index[i] = id + 1;
    }
    free(path_index);
    path_index = index;
    path_index_cap = cap;
    return 1;
}

/* SIZE_MAX when out of memory. */
static size_t
path_id(VALUE str)
{
    const char *p = RSTRING_PTR(str);
    size_t n = RSTRING_LEN(str);
    size_t slot = (str >> 3) & 1023;
    size_t cached = path_cache[slot].id;
    if (path_cache[slot].str == str && path_lens[cached] == n && memcmp(paths[cached], p, n) == 0) return cached;
    if ((paths_len + 1) * 2 > path_index_cap && !path_index_grow()) return SIZE_MAX;
    size_t i = str_hash(p, n) & (path_index_cap - 1);
    while (path_index[i]) {
        size_t id = path_index[i] - 1;
        if (path_lens[id] == n && memcmp(paths[id], p, n) == 0) {
            path_cache[slot].str = str;
            path_cache[slot].id = id;
            return id;
        }
        i = (i + 1) & (path_index_cap - 1);
    }
    if (paths_len == paths_cap) {
        size_t cap = paths_cap ? paths_cap * 2 : 512;
        char **np = realloc(paths, cap * sizeof(char *));
        if (!np) return SIZE_MAX;
        paths = np;
        size_t *nl = realloc(path_lens, cap * sizeof(size_t));
        if (!nl) return SIZE_MAX;
        path_lens = nl;
        paths_cap = cap;
    }
    char *copy = malloc(n + 1);
    if (!copy) return SIZE_MAX;
    memcpy(copy, p, n);
    copy[n] = 0;
    paths[paths_len] = copy;
    path_lens[paths_len] = n;
    path_index[i] = paths_len + 1;
    path_cache[slot].str = str;
    path_cache[slot].id = paths_len;
    return paths_len++;
}

static int
sites_grow(void)
{
    size_t cap = sites_cap ? sites_cap * 2 : 1 << 14;
    site_t *table = calloc(cap, sizeof(site_t));
    if (!table) return 0;
    for (size_t j = 0; j < sites_cap; j++) {
        if (!sites[j].key) continue;
        size_t i = mix(sites[j].key) & (cap - 1);
        while (table[i].key) i = (i + 1) & (cap - 1);
        table[i] = sites[j];
    }
    free(sites);
    sites = table;
    sites_cap = cap;
    return 1;
}

static int
is_watched(uint64_t site)
{
    if (!watched_cap) return 0;
    size_t i = mix(site) & (watched_cap - 1);
    while (watched[i]) {
        if (watched[i] == site) return 1;
        i = (i + 1) & (watched_cap - 1);
    }
    return 0;
}

static int
callers_grow(void)
{
    size_t cap = callers_cap ? callers_cap * 2 : 4096;
    caller_t *table = calloc(cap, sizeof(caller_t));
    if (!table) return 0;
    for (size_t j = 0; j < callers_cap; j++) {
        if (!callers[j].site) continue;
        size_t i = mix(callers[j].site ^ mix(callers[j].caller)) & (cap - 1);
        while (table[i].site) i = (i + 1) & (cap - 1);
        table[i] = callers[j];
    }
    free(callers);
    callers = table;
    callers_cap = cap;
    return 1;
}

/* No Ruby calls: rb_profile_frames reads frames without allocating. */
static void
record_caller(uint64_t site)
{
    VALUE frames[128];
    int lines[128];
    uint64_t caller = 0;
    int n = rb_profile_frames(0, 128, frames, lines);
    for (int f = 0; f < n; f++) {
        VALUE fpath = rb_profile_frame_path(frames[f]);
        if (!RB_TYPE_P(fpath, T_STRING) || lines[f] <= 0 || (size_t)RSTRING_LEN(fpath) <= app_root_len) continue;
        if (memcmp(RSTRING_PTR(fpath), app_root, app_root_len) != 0) continue;
        /* Gems vendored under the app (vendor/bundle, gems/) are not the app. */
        const char *rest = RSTRING_PTR(fpath) + app_root_len;
        size_t rest_len = RSTRING_LEN(fpath) - app_root_len;
        if ((rest_len > 5 && memcmp(rest, "gems/", 5) == 0) || memmem(rest, rest_len, "/gems/", 6)) continue;
        size_t id = path_id(fpath);
        if (id != SIZE_MAX) caller = ((uint64_t)(id + 1) << 32) | (uint32_t)lines[f];
        break;
    }
    if ((callers_len + 1) * 2 > callers_cap && !callers_grow()) return;
    size_t i = mix(site ^ mix(caller)) & (callers_cap - 1);
    while (callers[i].site && (callers[i].site != site || callers[i].caller != caller)) i = (i + 1) & (callers_cap - 1);
    if (!callers[i].site) { callers[i].site = site; callers[i].caller = caller; callers_len++; }
    callers[i].count++;
}

static void
newobj(VALUE tpval, void *data)
{
    if (depth <= 0) return;
    rb_trace_arg_t *arg = rb_tracearg_from_tracepoint(tpval);
    VALUE obj = rb_tracearg_object(arg);
    VALUE path = rb_tracearg_path(arg);
    uint64_t line = NUM2ULONG(rb_tracearg_lineno(arg));
    uint64_t via = 0;
    /* Ruby's own <internal:...> frames (Pathname, Kernel#tap, ...) are charged
     * to their nearest caller outside them, flagged in bit 63. */
    if (RB_TYPE_P(path, T_STRING) && RSTRING_LEN(path) > 10 && memcmp(RSTRING_PTR(path), "<internal:", 10) == 0) {
        VALUE frames[16];
        int lines[16];
        int n = rb_profile_frames(0, 16, frames, lines);
        for (int f = 0; f < n; f++) {
            VALUE fpath = rb_profile_frame_path(frames[f]);
            if (!RB_TYPE_P(fpath, T_STRING) || lines[f] <= 0) continue;
            if (RSTRING_LEN(fpath) > 10 && memcmp(RSTRING_PTR(fpath), "<internal:", 10) == 0) continue;
            path = fpath;
            line = lines[f];
            via = 1ULL << 63;
            break;
        }
    }
    objects++;
    size_t id = RB_TYPE_P(path, T_STRING) ? path_id(path) : 0;
    if (id == SIZE_MAX || line >= (1ULL << 32) || id + 1 >= (1ULL << 26)) { dropped++; return; }
    /* Path id 0 means no Ruby frame: real ids are shifted by one. */
    uint64_t key = via | ((uint64_t)(RB_TYPE_P(path, T_STRING) ? id + 1 : 0) << 37) | (line << 5) | (BUILTIN_TYPE(obj) & 31);
    if (!key) key = 1ULL << 5; /* never collide with the empty marker */
    if ((sites_len + 1) * 2 > sites_cap && !sites_grow()) { dropped++; return; }
    size_t i = mix(key) & (sites_cap - 1);
    while (sites[i].key && sites[i].key != key) i = (i + 1) & (sites_cap - 1);
    site_t *s = &sites[i];
    if (!s->key) { s->key = key; sites_len++; }
    s->count++;
    if (s->last != window) {
        if (!s->requests) s->first_window = window;
        s->last = window;
        s->requests++;
    }
    if (window == s->first_window) s->first++;
    if (watched_cap && id + 1 < (1ULL << 26)) {
        uint64_t site = ((uint64_t)(id + 1) << 32) | line;
        if (RB_TYPE_P(path, T_STRING) && is_watched(site)) record_caller(site);
    }
}

/* Lowrail::Profile.watch([[path, line], ...], app_root): record callers. */
static VALUE
profile_watch(VALUE self, VALUE list, VALUE root)
{
    Check_Type(list, T_ARRAY);
    StringValue(root);
    size_t cap = 64;
    while (cap < (size_t)RARRAY_LEN(list) * 2) cap *= 2;
    uint64_t *table = calloc(cap, sizeof(uint64_t));
    char *copy = malloc(RSTRING_LEN(root) + 1);
    if (!table || !copy) rb_raise(rb_eNoMemError, "lowrail profile watch");
    for (long j = 0; j < RARRAY_LEN(list); j++) {
        VALUE pair = rb_ary_entry(list, j);
        VALUE path = rb_ary_entry(pair, 0);
        StringValue(path);
        size_t id = path_id(path);
        if (id == SIZE_MAX) continue;
        uint64_t site = ((uint64_t)(id + 1) << 32) | NUM2UINT(rb_ary_entry(pair, 1));
        size_t i = mix(site) & (cap - 1);
        while (table[i] && table[i] != site) i = (i + 1) & (cap - 1);
        table[i] = site;
    }
    memcpy(copy, RSTRING_PTR(root), RSTRING_LEN(root));
    copy[RSTRING_LEN(root)] = 0;
    app_root = copy;
    app_root_len = RSTRING_LEN(root);
    watched = table;
    watched_cap = cap;
    return Qnil;
}

/* [[path, line, caller path or nil, caller line, count], ...] */
static VALUE
profile_callers(VALUE self)
{
    VALUE rows = rb_ary_new();
    for (size_t j = 0; j < callers_cap; j++) {
        caller_t c = callers[j];
        if (!c.site) continue;
        size_t sid = (c.site >> 32) - 1, cid = c.caller >> 32;
        rb_ary_push(rows, rb_ary_new_from_args(5, rb_str_new(paths[sid], path_lens[sid]), ULL2NUM(c.site & 0xffffffffULL),
            cid ? rb_str_new(paths[cid - 1], path_lens[cid - 1]) : Qnil, ULL2NUM(c.caller & 0xffffffffULL), ULL2NUM(c.count)));
    }
    return rows;
}

/* Lowrail::Profile.enter / leave bracket a request on the current thread.
 * Nested windows (mounted engines) count as one request. */
static VALUE
profile_enter(VALUE self)
{
    if (depth++ == 0) {
        window = __atomic_add_fetch(&window_seq, 1, __ATOMIC_RELAXED);
        __atomic_add_fetch(&requests, 1, __ATOMIC_RELAXED);
    }
    return Qnil;
}

static VALUE
profile_leave(VALUE self)
{
    if (depth > 0) depth--;
    return Qnil;
}

static void
reset(void)
{
    if (sites) memset(sites, 0, sites_cap * sizeof(site_t));
    sites_len = 0;
    if (callers) memset(callers, 0, callers_cap * sizeof(caller_t));
    callers_len = 0;
    requests = objects = dropped = 0;
    depth = 0;
}

static VALUE
profile_reset(VALUE self)
{
    reset();
    return Qnil;
}

static VALUE
profile_start(VALUE self)
{
    if (NIL_P(tracepoint)) {
        tracepoint = rb_tracepoint_new(0, RUBY_INTERNAL_EVENT_NEWOBJ, newobj, NULL);
        rb_gc_register_mark_object(tracepoint);
        rb_tracepoint_enable(tracepoint);
    }
    return Qnil;
}

/* [requests, objects, dropped, [[path or nil, line, type, count, requests, first, via], ...]] */
static VALUE
profile_snapshot(VALUE self)
{
    /* Copy first: building Ruby objects below runs outside any window, but a
     * request on another thread could still grow the table meanwhile. */
    size_t n = 0;
    site_t *copy = malloc((sites_len + 1) * sizeof(site_t));
    if (!copy) rb_raise(rb_eNoMemError, "lowrail profile snapshot");
    for (size_t j = 0; j < sites_cap && n <= sites_len; j++) if (sites[j].key) copy[n++] = sites[j];
    VALUE rows = rb_ary_new_capa(n);
    for (size_t j = 0; j < n; j++) {
        uint64_t key = copy[j].key, id = (key >> 37) & ((1ULL << 26) - 1);
        VALUE path = id ? rb_str_new(paths[id - 1], path_lens[id - 1]) : Qnil;
        VALUE row = rb_ary_new_from_args(7, path, ULL2NUM((key >> 5) & 0xffffffffULL), INT2FIX(key & 31),
            ULL2NUM(copy[j].count), ULL2NUM(copy[j].requests), ULL2NUM(copy[j].first), (key >> 63) ? Qtrue : Qfalse);
        rb_ary_push(rows, row);
    }
    free(copy);
    return rb_ary_new_from_args(4, ULL2NUM(requests), ULL2NUM(objects), ULL2NUM(dropped), rows);
}

void
Init_lowrail_profile(void)
{
    VALUE lowrail = rb_define_module("Lowrail");
    VALUE profile = rb_define_module_under(lowrail, "Profile");
    rb_define_singleton_method(profile, "start", profile_start, 0);
    rb_define_singleton_method(profile, "enter", profile_enter, 0);
    rb_define_singleton_method(profile, "leave", profile_leave, 0);
    rb_define_singleton_method(profile, "reset", profile_reset, 0);
    rb_define_singleton_method(profile, "snapshot", profile_snapshot, 0);
    rb_define_singleton_method(profile, "watch", profile_watch, 2);
    rb_define_singleton_method(profile, "callers", profile_callers, 0);
}
