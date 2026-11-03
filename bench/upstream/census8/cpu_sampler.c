/* Census 8 CPU sampler: instruction-triggered Ruby stack samples under the
 * patched Callgrind (cpu-valgrind.patch, built from
 * bench/experiments/hotspots-valgrind.patch with a settable interval).
 * Each sample captures rb_profile_frames and the line of every frame, as
 * StackProf does on MRI >= 3; samples taken inside GC are counted apart.
 * The handler's own instructions and the marking of retained frames are
 * excluded from the sampled work. Measurement only. */
#include <ruby.h>
#include <ruby/debug.h>
#include <valgrind/callgrind.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>

#define DEPTH 512
/* Stacks are kept as a prefix tree, outermost frame at the root, so the long
 * shared prefixes of Rails stacks are stored once. Node 0 is the root. */
#define NODES (1 << 21)
#define BUCKETS (1 << 22)
static uint32_t *parents, *buckets, used;
static VALUE *node_frames;
static int *node_lines;
static uint64_t *counts;
static volatile sig_atomic_t active;
static uint64_t gc, empty, truncated, dropped, signals, hooks, lag_sum, lag_max;
static VALUE gc_root;

#define REQUEST(id, a, b) VALGRIND_DO_CLIENT_REQUEST_EXPR(0, VG_USERREQ_TOOL_BASE('C','T') + id, a, b, 0, 0, 0)

/* The child of `parent` for (frame, line), added if new; 0 when the tree is full. */
static uint32_t child(uint32_t parent, VALUE frame, int line) {
    uint64_t hash = (((uint64_t)parent * 0x9E3779B97F4A7C15ULL) ^ (uint64_t)frame) * 0xC2B2AE3D27D4EB4FULL ^ (uint64_t)(uint32_t)line;
    hash *= 0x165667B19E3779F9ULL;
    uint32_t slot = (hash >> 32) & (BUCKETS - 1);
    while (buckets[slot]) {
        uint32_t id = buckets[slot];
        if (parents[id] == parent && node_frames[id] == frame && node_lines[id] == line) return id;
        slot = (slot + 1) & (BUCKETS - 1);
    }
    if (used + 1 == NODES) return 0;
    uint32_t id = ++used;
    parents[id] = parent;
    node_frames[id] = frame;
    node_lines[id] = line;
    counts[id] = 0;
    buckets[slot] = id;
    return id;
}

static void sample(int sig) {
    uint64_t lag = REQUEST(103, 0, 0);
    if (!active) return;
    uint64_t begin = REQUEST(100, 0, 0);
    signals++;
    lag_sum += lag;
    if (lag > lag_max) lag_max = lag;
    if (rb_during_gc()) { gc++; goto done; }
    VALUE frames[DEPTH];
    int lines[DEPTH];
    int n = rb_profile_frames(0, DEPTH, frames, lines);
    if (n == DEPTH) truncated++;
    if (!n) { empty++; goto done; }
    uint32_t node = 0;
    for (int i = n - 1; i >= 0; i--) {
        node = child(node, frames[i], lines[i]);
        if (!node) { dropped++; goto done; }
    }
    counts[node]++;
done:
    hooks += REQUEST(100, 0, 0) - begin;
}

static void mark(void *unused) {
    if (active) REQUEST(104, 1, 0);
    for (uint32_t i = 1; i <= used; i++) rb_gc_mark(node_frames[i]);
    if (active) REQUEST(104, 0, 0);
}

static const rb_data_type_t root_type = { "CensusCpuFrames", { mark, NULL, NULL } };

/* CensusCpu.measure(seed, interval) { work } -> sampled client Ir. interval
 * is a power of two; samples fall every interval/2 .. 3*interval/2 Ir.
 * interval 0 only yields (a JIT warmup window through the same call). */
static VALUE measure(VALUE self, VALUE seed, VALUE interval) {
    if (NUM2ULONG(interval) == 0) return rb_yield(Qnil);
    memset(buckets, 0, BUCKETS * sizeof(uint32_t));
    used = 0;
    gc = empty = truncated = dropped = signals = hooks = lag_sum = lag_max = 0;
    CALLGRIND_START_INSTRUMENTATION;
    CALLGRIND_ZERO_STATS;
    active = 1;
    if (!REQUEST(101, NUM2ULONG(seed), NUM2ULONG(interval))) rb_raise(rb_eRuntimeError, "patched Callgrind required");
    int state = 0;
    rb_protect(rb_yield, Qnil, &state);
    uint64_t work = REQUEST(102, 0, 0);
    uint64_t issued = REQUEST(105, 0, 0);
    active = 0;
    CALLGRIND_STOP_INSTRUMENTATION;
    if (state) rb_jump_tag(state);
    VALUE row = rb_hash_new();
#define FIELD(name, value) rb_hash_aset(row, ID2SYM(rb_intern(name)), ULL2NUM(value))
    FIELD("work_ir", work); FIELD("issued", issued); FIELD("signals", signals); FIELD("gc", gc);
    FIELD("empty", empty); FIELD("truncated", truncated); FIELD("dropped", dropped);
    FIELD("handler_ir", hooks); FIELD("lag_sum_ir", lag_sum); FIELD("lag_max_ir", lag_max);
    return row;
}

/* [[[[frame_id, line], ...], count], ...] innermost frame first, and the
 * frames as [path, label, first_lineno]. */
static VALUE stacks(VALUE self) {
    VALUE ids = rb_hash_new(), frames = rb_ary_new(), out = rb_ary_new();
    for (uint32_t leaf = 1; leaf <= used; leaf++) {
        if (!counts[leaf]) continue;
        VALUE stack = rb_ary_new();
        for (uint32_t node = leaf; node; node = parents[node]) {
            VALUE frame = node_frames[node];
            VALUE key = ULL2NUM((uintptr_t)frame), id = rb_hash_aref(ids, key);
            if (NIL_P(id)) {
                id = LONG2NUM(RARRAY_LEN(frames));
                VALUE path = rb_profile_frame_absolute_path(frame);
                if (!RB_TYPE_P(path, T_STRING)) path = rb_profile_frame_path(frame);
                VALUE label = rb_profile_frame_qualified_method_name(frame);
                if (NIL_P(label)) label = rb_profile_frame_full_label(frame);
                rb_ary_push(frames, rb_ary_new_from_args(3, path, label, rb_profile_frame_first_lineno(frame)));
                rb_hash_aset(ids, key, id);
            }
            rb_ary_push(stack, rb_ary_new_from_args(2, id, INT2NUM(node_lines[node])));
        }
        rb_ary_push(out, rb_ary_new_from_args(2, stack, ULL2NUM(counts[leaf])));
    }
    return rb_ary_new_from_args(2, frames, out);
}

void Init_census_cpu_sampler(void) {
    parents = calloc(NODES, sizeof(uint32_t));
    node_frames = calloc(NODES, sizeof(VALUE));
    node_lines = calloc(NODES, sizeof(int));
    counts = calloc(NODES, sizeof(uint64_t));
    buckets = calloc(BUCKETS, sizeof(uint32_t));
    if (!parents || !node_frames || !node_lines || !counts || !buckets) rb_memerror();
    gc_root = TypedData_Wrap_Struct(rb_cObject, &root_type, parents);
    rb_global_variable(&gc_root);
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = sample;
    action.sa_flags = SA_RESTART;
    sigemptyset(&action.sa_mask);
    sigaction(SIGPROF, &action, NULL);
    VALUE mod = rb_define_module("CensusCpu");
    rb_define_singleton_method(mod, "measure", measure, 2);
    rb_define_singleton_method(mod, "stacks", stacks, 0);
}
