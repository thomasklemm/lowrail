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
 * ObjectSpace.allocation_sourcefile/sourceline: the nearest Ruby frame.
 *
 * Every function runs in the main Ractor with the GVL held (lowrail/profile
 * calls none of them from another Ractor, and NEWOBJ hooks are per Ractor),
 * so the process-global tables need no lock. They are not Ractor-safe. */

#define KINDS 4
/* Lowrail::Profile::API: lowrail/profile refuses an extension built from
 * other sources (an older cache) before it hooks anything. */
#define API 2

typedef struct {
    uint64_t key;      /* via << 63 | kind << 61 | path id << 35 | line << 5 | ruby type; 0 = empty */
    uint64_t count;
    uint64_t requests; /* windows in which the line allocated */
    uint64_t first;    /* objects of its first window: the one that reached the line first */
    uint64_t owner;    /* that window's id, reserved at its first touch, before it closes */
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
 * buffers its own pairs until it ends and its name is known. */
typedef struct { uint64_t site, caller, count; } pend_t;
typedef struct { uint64_t kind, name, site, caller, count, first; } attrib_t;
static attrib_t *attribs;
static size_t attribs_cap, attribs_len;
static int attributing;
static char *app_root;
static size_t app_root_len;

/* An open window, owned by the fiber (and its Ruby thread) that entered it,
 * so overlapping threads (M:N included) and independent fibers each have
 * their own. Its sites and pairs are merged once when it closes; the slot
 * and its buffers are then reused, so threads that come and go leave
 * nothing behind. The owner is marked (pinned) while the window is open, so
 * a fiber abandoned inside a window stays alive; past MAX_OPEN open windows
 * the oldest one off the current fiber is dropped (counted in dropped),
 * which bounds that. (Ruby 4.0 exports no weak marking to extensions.) */
typedef struct { uint64_t key, count; } seen_t;
typedef struct {
    VALUE thread, fiber; /* fiber 0 = free slot */
    int depth;
    uint64_t id, kind, name, objects;
    seen_t *seen;
    size_t seen_cap, seen_len;
    pend_t *pend;
    size_t pend_cap, pend_len;
} win_t;
static win_t *wins;
static size_t wins_cap, wins_open;
/* Buffers larger than this are freed when their window closes. */
#define KEEP_CAP (1 << 16)
#define MAX_OPEN 1024

static uint64_t windows[KINDS], objects[KINDS], dropped, window_seq;
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

/* Open addressing on {key, count} pairs (window sites, attribution pairs). */
static int
grow_pairs(void **table, size_t *cap, size_t size, size_t key_words)
{
    size_t ncap = *cap ? *cap * 2 : 256;
    char *next = calloc(ncap, size);
    if (!next) return 0;
    char *old = *table;
    for (size_t j = 0; j < *cap; j++) {
        uint64_t *e = (uint64_t *)(old + j * size);
        if (!e[0]) continue;
        uint64_t h = e[0];
        for (size_t w = 1; w < key_words; w++) h ^= mix(e[w]);
        size_t i = mix(h) & (ncap - 1);
        while (*(uint64_t *)(next + i * size)) i = (i + 1) & (ncap - 1);
        memcpy(next + i * size, e, size);
    }
    free(old);
    *table = next;
    *cap = ncap;
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
attribute(win_t *w, uint64_t site)
{
    uint64_t caller = app_caller();
    if ((w->pend_len + 1) * 2 > w->pend_cap && !grow_pairs((void **)&w->pend, &w->pend_cap, sizeof(pend_t), 2)) { dropped++; return; }
    size_t i = mix(site ^ mix(caller)) & (w->pend_cap - 1);
    while (w->pend[i].site && (w->pend[i].site != site || w->pend[i].caller != caller)) i = (i + 1) & (w->pend_cap - 1);
    if (!w->pend[i].site) { w->pend[i].site = site; w->pend[i].caller = caller; w->pend_len++; }
    w->pend[i].count++;
}

static int
visible(VALUE obj)
{
    switch (BUILTIN_TYPE(obj)) {
      case T_NONE: case T_IMEMO: case T_NODE: case T_ICLASS: case T_ZOMBIE: case T_MOVED: return 0;
      default: return 1;
    }
}

static win_t *
window_of(VALUE fiber)
{
    for (size_t i = 0; i < wins_cap; i++) if (wins[i].fiber == fiber) return &wins[i];
    return NULL;
}

/* The current fiber's open window, or NULL. A thread with no open window
 * returns before asking for its fiber: rb_fiber_current allocates a root
 * fiber's object the first time. A thread with one has it already (enter
 * asked, and switching to any other fiber creates the root's). */
static win_t *
current_window(void)
{
    if (!wins_open) return NULL;
    VALUE thread = rb_thread_current();
    size_t i = 0;
    while (i < wins_cap && !(wins[i].fiber && wins[i].thread == thread)) i++;
    if (i == wins_cap) return NULL;
    return window_of(rb_fiber_current());
}

static site_t *site_for(uint64_t key);

static void
newobj(VALUE tpval, void *data)
{
    win_t *w = current_window();
    if (!w) return;
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
    objects[w->kind]++;
    int seen = visible(obj);
    if (seen) w->objects++;
    size_t id = RB_TYPE_P(path, T_STRING) ? path_id(path) : 0;
    if (id == SIZE_MAX || line >= (1ULL << 30) || id + 1 >= (1ULL << 26)) { dropped++; return; }
    /* Path id 0 means no Ruby frame: real ids are shifted by one. */
    uint64_t pid = RB_TYPE_P(path, T_STRING) ? id + 1 : 0;
    uint64_t key = via | (w->kind << 61) | (pid << 35) | (line << 5) | (BUILTIN_TYPE(obj) & 31);
    if (!key) key = 1ULL << 5; /* never collide with the empty marker */
    if ((w->seen_len + 1) * 2 > w->seen_cap && !grow_pairs((void **)&w->seen, &w->seen_cap, sizeof(seen_t), 1)) { dropped++; return; }
    size_t i = mix(key) & (w->seen_cap - 1);
    while (w->seen[i].key && w->seen[i].key != key) i = (i + 1) & (w->seen_cap - 1);
    if (!w->seen[i].key) {
        w->seen[i].key = key;
        w->seen_len++;
        /* The first window to touch a line owns its first count, however the
         * windows close; the global entry is reserved now, merged at close. */
        site_t *s = site_for(key);
        if (s && !s->owner && !s->requests) s->owner = w->id;
    }
    w->seen[i].count++;
    if (attributing && seen && pid) attribute(w, (pid << 32) | line);
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

static site_t *
site_for(uint64_t key)
{
    if ((sites_len + 1) * 2 > sites_cap && !sites_grow()) return NULL;
    size_t i = mix(key) & (sites_cap - 1);
    while (sites[i].key && sites[i].key != key) i = (i + 1) & (sites_cap - 1);
    if (!sites[i].key) { sites[i].key = key; sites_len++; }
    return &sites[i];
}

static void
release(win_t *w)
{
    if (w->seen_cap > KEEP_CAP) { free(w->seen); w->seen = NULL; w->seen_cap = 0; }
    else if (w->seen) memset(w->seen, 0, w->seen_cap * sizeof(seen_t));
    w->seen_len = 0;
    if (w->pend_cap > KEEP_CAP) { free(w->pend); w->pend = NULL; w->pend_cap = 0; }
    else if (w->pend) memset(w->pend, 0, w->pend_cap * sizeof(pend_t));
    w->pend_len = 0;
    w->fiber = w->thread = 0;
    w->depth = 0;
    wins_open--;
}

/* The window ended: each line it reached counts the window once, and its
 * objects and attributed pairs go to its name. */
static void
close_window(win_t *w)
{
    uint64_t kind = w->kind, name = w->name;
    action_t *a = action_for(kind, name);
    int first = a && a->windows == 0;
    if (a) {
        a->windows++;
        a->objects += w->objects;
        if (first) a->first += w->objects;
    }
    for (size_t j = 0; w->seen_len && j < w->seen_cap; j++) {
        seen_t *e = &w->seen[j];
        if (!e->key) continue;
        site_t *s = site_for(e->key);
        if (!s) { dropped += e->count; continue; }
        if (s->owner == w->id || (!s->owner && !s->requests)) s->first = e->count;
        s->requests++;
        s->count += e->count;
    }
    for (size_t j = 0; w->pend_len && j < w->pend_cap; j++) {
        pend_t *p = &w->pend[j];
        if (!p->site) continue;
        if ((attribs_len + 1) * 2 > attribs_cap && !attribs_grow()) { dropped += p->count; continue; }
        size_t i = attrib_hash(kind, name, p->site, p->caller) & (attribs_cap - 1);
        attrib_t *e;
        while ((e = &attribs[i])->site && (e->kind != kind || e->name != name || e->site != p->site || e->caller != p->caller))
            i = (i + 1) & (attribs_cap - 1);
        if (!e->site) { e->kind = kind; e->name = name; e->site = p->site; e->caller = p->caller; attribs_len++; }
        e->count += p->count;
        if (first) e->first += p->count;
    }
    release(w);
}

/* Lowrail::Profile.enter(kind) / leave bracket a window on the current
 * fiber. Nested windows (mounted engines, a mail inside a request or job)
 * count as the outermost one. Neither raises: enter returns false when it
 * cannot open a window (out of memory), and the code runs uncounted. */
static VALUE
profile_enter(VALUE self, VALUE k)
{
    VALUE thread = rb_thread_current();
    VALUE fiber = rb_fiber_current();
    win_t *w = window_of(fiber);
    if (w) { w->depth++; return Qtrue; }
    w = window_of(0);
    if (!w && wins_open >= MAX_OPEN) {
        win_t *oldest = NULL;
        for (size_t i = 0; i < wins_cap; i++)
            if (wins[i].fiber && wins[i].fiber != fiber && (!oldest || wins[i].id < oldest->id)) oldest = &wins[i];
        /* Its objects are lost, so the capture says so (compare refuses it). */
        if (oldest) { release(oldest); dropped++; w = oldest; }
    }
    if (!w) {
        size_t cap = wins_cap ? wins_cap * 2 : 16;
        win_t *next = realloc(wins, cap * sizeof(win_t));
        if (!next) return Qfalse;
        memset(next + wins_cap, 0, (cap - wins_cap) * sizeof(win_t));
        w = next + wins_cap;
        wins = next;
        wins_cap = cap;
    }
    w->thread = thread;
    w->fiber = fiber;
    w->depth = 1;
    w->id = ++window_seq;
    w->kind = (FIXNUM_P(k) ? (uint64_t)FIX2LONG(k) : 0) % KINDS;
    w->name = 0;
    w->objects = 0;
    wins_open++;
    windows[w->kind]++;
    return Qtrue;
}

static VALUE
profile_leave(VALUE self)
{
    if (!wins_open) return Qnil;
    win_t *w = window_of(rb_fiber_current());
    if (w && --w->depth == 0) close_window(w);
    return Qnil;
}

/* Lowrail::Profile.label(klass, separator, name): the current window's name,
 * "Klass#name", once per window (the outermost controller, job, mailer or
 * channel). Builds no Ruby objects. */
static VALUE
profile_label(VALUE self, VALUE klass, VALUE sep, VALUE action)
{
    if (!wins_open) return Qnil;
    win_t *w = window_of(rb_fiber_current());
    if (!w || w->name || !RB_TYPE_P(klass, T_CLASS)) return Qnil;
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
    if (id != SIZE_MAX) w->name = id + 1;
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
    free(app_root);
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
    for (size_t i = 0; i < wins_cap; i++) if (wins[i].fiber) release(&wins[i]);
    memset(windows, 0, sizeof(windows));
    memset(objects, 0, sizeof(objects));
    dropped = 0;
}

static VALUE
profile_reset(VALUE self)
{
    reset();
    return Qnil;
}

static void
wins_mark(void *ptr)
{
    for (size_t i = 0; i < wins_cap; i++) {
        if (!wins[i].fiber) continue;
        rb_gc_mark(wins[i].fiber);
        rb_gc_mark(wins[i].thread);
    }
}

static const rb_data_type_t wins_type = { "lowrail_profile_windows", { wins_mark, NULL, NULL, }, 0, 0, 0 };

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
    for (size_t j = 0; j < sites_cap && n <= sites_len; j++) if (sites[j].key && sites[j].requests) copy[n++] = sites[j];
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
    VALUE holder = TypedData_Wrap_Struct(0, &wins_type, &wins);
    rb_gc_register_mark_object(holder);
    rb_define_const(profile, "API", INT2FIX(API));
    rb_define_singleton_method(profile, "start", profile_start, 0);
    rb_define_singleton_method(profile, "enter", profile_enter, 1);
    rb_define_singleton_method(profile, "leave", profile_leave, 0);
    rb_define_singleton_method(profile, "label", profile_label, 3);
    rb_define_singleton_method(profile, "reset", profile_reset, 0);
    rb_define_singleton_method(profile, "snapshot", profile_snapshot, 0);
    rb_define_singleton_method(profile, "attribute", profile_attribute, 1);
}
