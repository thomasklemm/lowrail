#define _GNU_SOURCE
#include <ruby.h>
#include <ruby/debug.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

/* Objects allocated per source line inside windows (lowrail/profile): a
 * request (Rails::Engine#call), a job (perform_now), a mail (build or
 * delivery) or an Action Cable channel action. One internal NEWOBJ hook, as
 * objspace's allocation tracing uses, but it keeps counts instead of
 * per-object records, so GC stays on and nothing is retained. The hook never
 * allocates Ruby objects or calls Ruby; its tables use libc malloc so it
 * cannot start a GC. Lines are attributed like
 * ObjectSpace.allocation_sourcefile/sourceline: the nearest Ruby frame. */

#define KINDS 4

typedef struct {
    uint64_t key;      /* via << 63 | kind << 61 | path id << 35 | line << 5 | ruby type; 0 = empty */
    uint64_t count;
    uint64_t requests; /* windows in which the line allocated */
    uint64_t last;     /* last window seen */
    uint64_t first;    /* objects in the first window that reached the line */
    uint64_t first_window;
} site_t;

static site_t *sites;
static size_t sites_cap, sites_len;

/* Interned strings: source paths and window names ("RoomsController#show"). */
static char **paths;
static size_t *path_lens;
static size_t paths_len, paths_cap;
static size_t *path_index; /* open addressing: path id + 1; 0 = empty */
static size_t path_index_cap;

static struct { VALUE str; size_t id; } path_cache[1024];

/* Per window name (kind, name id + 1; 0 = no name): windows, objects
 * ObjectSpace can see, and those of its first window in this process. */
typedef struct { uint64_t kind, name, windows, objects, first; } action_t;
static action_t *actions;
static size_t actions_cap, actions_len;

/* Attribution (the repeat run): per window name, allocating line and the
 * nearest app frame (path id + 1 << 32 | line; caller 0 = none). Each window
 * buffers its own pairs per thread until it ends and its name is known. */
typedef struct { uint64_t site, caller, count; } pend_t;
typedef struct { uint64_t kind, name, site, caller, count, first; } attrib_t;
static attrib_t *attribs;
static size_t attribs_cap, attribs_len;
static int attributing;
static char *app_root;
static size_t app_root_len;

static uint64_t windows[KINDS], objects[KINDS], window_seq, dropped;
static __thread int depth;
static __thread uint64_t window, kind, name, window_objects;
static __thread pend_t *pend;
static __thread size_t pend_cap, pend_len;
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
intern(const char *p, size_t n)
{
    if ((paths_len + 1) * 2 > path_index_cap && !path_index_grow()) return SIZE_MAX;
    size_t i = str_hash(p, n) & (path_index_cap - 1);
    while (path_index[i]) {
        size_t id = path_index[i] - 1;
        if (path_lens[id] == n && memcmp(paths[id], p, n) == 0) return id;
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
    return paths_len++;
}

static size_t
path_id(VALUE str)
{
    const char *p = RSTRING_PTR(str);
    size_t n = RSTRING_LEN(str);
    size_t slot = (str >> 3) & 1023;
    size_t cached = path_cache[slot].id;
    if (path_cache[slot].str == str && cached < paths_len && path_lens[cached] == n && memcmp(paths[cached], p, n) == 0) return cached;
    size_t id = intern(p, n);
    if (id != SIZE_MAX) {
        path_cache[slot].str = str;
        path_cache[slot].id = id;
    }
    return id;
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

static uint64_t
attrib_hash(uint64_t k, uint64_t n, uint64_t site, uint64_t caller)
{
    return mix(site ^ mix(caller ^ mix((n << 2) | k)));
}

static int
attribs_grow(void)
{
    size_t cap = attribs_cap ? attribs_cap * 2 : 1 << 14;
    attrib_t *table = calloc(cap, sizeof(attrib_t));
    if (!table) return 0;
    for (size_t j = 0; j < attribs_cap; j++) {
        attrib_t *a = &attribs[j];
        if (!a->site) continue;
        size_t i = attrib_hash(a->kind, a->name, a->site, a->caller) & (cap - 1);
        while (table[i].site) i = (i + 1) & (cap - 1);
        table[i] = *a;
    }
    free(attribs);
    attribs = table;
    attribs_cap = cap;
    return 1;
}

static int
pend_grow(void)
{
    size_t cap = pend_cap ? pend_cap * 2 : 1024;
    pend_t *table = calloc(cap, sizeof(pend_t));
    if (!table) return 0;
    for (size_t j = 0; j < pend_cap; j++) {
        if (!pend[j].site) continue;
        size_t i = mix(pend[j].site ^ mix(pend[j].caller)) & (cap - 1);
        while (table[i].site) i = (i + 1) & (cap - 1);
        table[i] = pend[j];
    }
    free(pend);
    pend = table;
    pend_cap = cap;
    return 1;
}

/* The nearest frame in the app's own code: under the app root, but not gems
 * vendored there (vendor/bundle, gems/) and not the test suite (test/, spec/),
 * whose request calls sit under every request. No Ruby calls:
 * rb_profile_frames reads frames without allocating. */
static uint64_t
app_caller(void)
{
    VALUE frames[128];
    int lines[128];
    int n = rb_profile_frames(0, 128, frames, lines);
    for (int f = 0; f < n; f++) {
        VALUE fpath = rb_profile_frame_path(frames[f]);
        if (!RB_TYPE_P(fpath, T_STRING) || lines[f] <= 0 || (size_t)RSTRING_LEN(fpath) <= app_root_len) continue;
        if (memcmp(RSTRING_PTR(fpath), app_root, app_root_len) != 0) continue;
        const char *rest = RSTRING_PTR(fpath) + app_root_len;
        size_t rest_len = RSTRING_LEN(fpath) - app_root_len;
        if (rest_len > 5 && (memcmp(rest, "gems/", 5) == 0 || memcmp(rest, "test/", 5) == 0 || memcmp(rest, "spec/", 5) == 0)) continue;
        if (memmem(rest, rest_len, "/gems/", 6)) continue;
        size_t id = path_id(fpath);
        return id == SIZE_MAX ? 0 : ((uint64_t)(id + 1) << 32) | (uint32_t)lines[f];
    }
    return 0;
}

static void
attribute(uint64_t site)
{
    uint64_t caller = app_caller();
    if ((pend_len + 1) * 2 > pend_cap && !pend_grow()) { dropped++; return; }
    size_t i = mix(site ^ mix(caller)) & (pend_cap - 1);
    while (pend[i].site && (pend[i].site != site || pend[i].caller != caller)) i = (i + 1) & (pend_cap - 1);
    if (!pend[i].site) { pend[i].site = site; pend[i].caller = caller; pend_len++; }
    pend[i].count++;
}

static int
visible(VALUE obj)
{
    switch (BUILTIN_TYPE(obj)) {
      case T_NONE: case T_IMEMO: case T_NODE: case T_ICLASS: case T_ZOMBIE: case T_MOVED: return 0;
      default: return 1;
    }
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
    objects[kind]++;
    int seen = visible(obj);
    if (seen) window_objects++;
    size_t id = RB_TYPE_P(path, T_STRING) ? path_id(path) : 0;
    if (id == SIZE_MAX || line >= (1ULL << 30) || id + 1 >= (1ULL << 26)) { dropped++; return; }
    /* Path id 0 means no Ruby frame: real ids are shifted by one. */
    uint64_t pid = RB_TYPE_P(path, T_STRING) ? id + 1 : 0;
    uint64_t key = via | (kind << 61) | (pid << 35) | (line << 5) | (BUILTIN_TYPE(obj) & 31);
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
    if (attributing && seen && pid) attribute((pid << 32) | line);
}

static action_t *
action_for(uint64_t k, uint64_t n)
{
    if ((actions_len + 1) * 2 > actions_cap) {
        size_t cap = actions_cap ? actions_cap * 2 : 256;
        action_t *table = calloc(cap, sizeof(action_t));
        if (!table) return NULL;
        for (size_t j = 0; j < actions_cap; j++) {
            if (!actions[j].windows) continue;
            size_t i = mix((actions[j].name << 2) | actions[j].kind) & (cap - 1);
            while (table[i].windows) i = (i + 1) & (cap - 1);
            table[i] = actions[j];
        }
        free(actions);
        actions = table;
        actions_cap = cap;
    }
    size_t i = mix((n << 2) | k) & (actions_cap - 1);
    while (actions[i].windows && (actions[i].kind != k || actions[i].name != n)) i = (i + 1) & (actions_cap - 1);
    if (!actions[i].windows) { actions[i].kind = k; actions[i].name = n; actions_len++; }
    return &actions[i];
}

/* The window ended: its objects and attributed pairs go to its name. */
static void
close_window(void)
{
    action_t *a = action_for(kind, name);
    int first = a && a->windows == 0;
    if (a) {
        a->windows++;
        a->objects += window_objects;
        if (first) a->first += window_objects;
    }
    for (size_t j = 0; pend_len && j < pend_cap; j++) {
        pend_t *p = &pend[j];
        if (!p->site) continue;
        if ((attribs_len + 1) * 2 > attribs_cap && !attribs_grow()) { dropped += p->count; }
        else {
            size_t i = attrib_hash(kind, name, p->site, p->caller) & (attribs_cap - 1);
            attrib_t *e;
            while ((e = &attribs[i])->site && (e->kind != kind || e->name != name || e->site != p->site || e->caller != p->caller))
                i = (i + 1) & (attribs_cap - 1);
            if (!e->site) { e->kind = kind; e->name = name; e->site = p->site; e->caller = p->caller; attribs_len++; }
            e->count += p->count;
            if (first) e->first += p->count;
        }
        p->site = 0;
        p->caller = 0;
        p->count = 0;
    }
    pend_len = 0;
}

/* Lowrail::Profile.enter(kind) / leave bracket a window on the current
 * thread. Nested windows (mounted engines, a mail inside a request or job)
 * count as the outermost one. */
static VALUE
profile_enter(VALUE self, VALUE k)
{
    if (depth++ == 0) {
        kind = NUM2UINT(k) % KINDS;
        name = 0;
        window_objects = 0;
        window = __atomic_add_fetch(&window_seq, 1, __ATOMIC_RELAXED);
        __atomic_add_fetch(&windows[kind], 1, __ATOMIC_RELAXED);
    }
    return Qnil;
}

static VALUE
profile_leave(VALUE self)
{
    if (depth > 0 && --depth == 0) close_window();
    return Qnil;
}

/* Lowrail::Profile.label(klass, separator, name): the current window's name,
 * "Klass#name", once per window (the outermost controller, job, mailer or
 * channel). Builds no Ruby objects. */
static VALUE
profile_label(VALUE self, VALUE klass, VALUE sep, VALUE action)
{
    if (depth <= 0 || name) return Qnil;
    VALUE cname = rb_mod_name(klass);
    if (!RB_TYPE_P(cname, T_STRING) || !RB_TYPE_P(sep, T_STRING)) return Qnil;
    if (RB_TYPE_P(action, T_SYMBOL)) action = rb_sym2str(action);
    if (!RB_TYPE_P(action, T_STRING)) return Qnil;
    size_t a = RSTRING_LEN(cname), b = RSTRING_LEN(sep), c = RSTRING_LEN(action);
    if (a + b + c > 4096) return Qnil;
    char buf[4096];
    memcpy(buf, RSTRING_PTR(cname), a);
    memcpy(buf + a, RSTRING_PTR(sep), b);
    memcpy(buf + a + b, RSTRING_PTR(action), c);
    size_t id = intern(buf, a + b + c);
    if (id != SIZE_MAX) name = id + 1;
    return Qnil;
}

/* Lowrail::Profile.attribute(app_root): record the nearest app frame of every
 * allocation, per window name. Allocates nothing, so counts stay comparable. */
static VALUE
profile_attribute(VALUE self, VALUE root)
{
    StringValue(root);
    char *copy = malloc(RSTRING_LEN(root) + 1);
    if (!copy) rb_raise(rb_eNoMemError, "lowrail profile attribute");
    memcpy(copy, RSTRING_PTR(root), RSTRING_LEN(root));
    copy[RSTRING_LEN(root)] = 0;
    app_root = copy;
    app_root_len = RSTRING_LEN(root);
    attributing = 1;
    return Qnil;
}

static void
reset(void)
{
    if (sites) memset(sites, 0, sites_cap * sizeof(site_t));
    sites_len = 0;
    if (actions) memset(actions, 0, actions_cap * sizeof(action_t));
    actions_len = 0;
    if (attribs) memset(attribs, 0, attribs_cap * sizeof(attrib_t));
    attribs_len = 0;
    if (pend) memset(pend, 0, pend_cap * sizeof(pend_t));
    pend_len = 0;
    memset(windows, 0, sizeof(windows));
    memset(objects, 0, sizeof(objects));
    dropped = 0;
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

static VALUE
interned(uint64_t id)
{
    return id ? rb_str_new(paths[id - 1], path_lens[id - 1]) : Qnil;
}

static VALUE
counts(uint64_t *values)
{
    VALUE ary = rb_ary_new_capa(KINDS);
    for (int k = 0; k < KINDS; k++) rb_ary_push(ary, ULL2NUM(values[k]));
    return ary;
}

/* [windows per kind, objects per kind, dropped,
 *  [[path or nil, line, type, count, windows, first, via, kind], ...],
 *  [[kind, name or nil, windows, objects, first], ...],
 *  [[kind, name or nil, path, line, caller path or nil, caller line, count, first], ...]] */
static VALUE
profile_snapshot(VALUE self)
{
    /* Copy first: building Ruby objects below runs outside any window, but a
     * request on another thread could still grow the tables meanwhile. */
    size_t n = 0, na = 0, nt = 0;
    site_t *copy = malloc((sites_len + 1) * sizeof(site_t));
    action_t *acopy = malloc((actions_len + 1) * sizeof(action_t));
    attrib_t *tcopy = malloc((attribs_len + 1) * sizeof(attrib_t));
    if (!copy || !acopy || !tcopy) { free(copy); free(acopy); free(tcopy); rb_raise(rb_eNoMemError, "lowrail profile snapshot"); }
    for (size_t j = 0; j < sites_cap && n <= sites_len; j++) if (sites[j].key) copy[n++] = sites[j];
    for (size_t j = 0; j < actions_cap && na <= actions_len; j++) if (actions[j].windows) acopy[na++] = actions[j];
    for (size_t j = 0; j < attribs_cap && nt <= attribs_len; j++) if (attribs[j].site) tcopy[nt++] = attribs[j];
    uint64_t w[KINDS], o[KINDS], d = dropped;
    memcpy(w, windows, sizeof(w));
    memcpy(o, objects, sizeof(o));
    VALUE rows = rb_ary_new_capa(n);
    for (size_t j = 0; j < n; j++) {
        uint64_t key = copy[j].key, id = (key >> 35) & ((1ULL << 26) - 1);
        VALUE row = rb_ary_new_from_args(8, interned(id), ULL2NUM((key >> 5) & ((1ULL << 30) - 1)), INT2FIX(key & 31),
            ULL2NUM(copy[j].count), ULL2NUM(copy[j].requests), ULL2NUM(copy[j].first), (key >> 63) ? Qtrue : Qfalse,
            INT2FIX((key >> 61) & 3));
        rb_ary_push(rows, row);
    }
    VALUE arows = rb_ary_new_capa(na);
    for (size_t j = 0; j < na; j++) {
        action_t a = acopy[j];
        rb_ary_push(arows, rb_ary_new_from_args(5, INT2FIX(a.kind), interned(a.name), ULL2NUM(a.windows),
            ULL2NUM(a.objects), ULL2NUM(a.first)));
    }
    VALUE trows = rb_ary_new_capa(nt);
    for (size_t j = 0; j < nt; j++) {
        attrib_t t = tcopy[j];
        rb_ary_push(trows, rb_ary_new_from_args(8, INT2FIX(t.kind), interned(t.name), interned(t.site >> 32),
            ULL2NUM(t.site & 0xffffffffULL), interned(t.caller >> 32), ULL2NUM(t.caller & 0xffffffffULL),
            ULL2NUM(t.count), ULL2NUM(t.first)));
    }
    free(copy);
    free(acopy);
    free(tcopy);
    return rb_ary_new_from_args(6, counts(w), counts(o), ULL2NUM(d), rows, arows, trows);
}

void
Init_lowrail_profile(void)
{
    VALUE lowrail = rb_define_module("Lowrail");
    VALUE profile = rb_define_module_under(lowrail, "Profile");
    rb_define_singleton_method(profile, "start", profile_start, 0);
    rb_define_singleton_method(profile, "enter", profile_enter, 1);
    rb_define_singleton_method(profile, "leave", profile_leave, 0);
    rb_define_singleton_method(profile, "label", profile_label, 3);
    rb_define_singleton_method(profile, "reset", profile_reset, 0);
    rb_define_singleton_method(profile, "snapshot", profile_snapshot, 0);
    rb_define_singleton_method(profile, "attribute", profile_attribute, 1);
}
