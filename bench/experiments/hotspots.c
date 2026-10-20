/* Measurement only: instruction-triggered MRI stack sampling. Like StackProf
 * 0.2.28 on MRI >= 3, capture interpreter frames in SIGPROF, never during GC.
 * No timer, TracePoint, app patch or Lowrail runtime is installed. */
#include <ruby.h>
#include <ruby/debug.h>
#include <valgrind/callgrind.h>
#include <signal.h>
#include <stdint.h>
#include <string.h>

#define DEPTH 256
#define RECORDS 16384
#define BUCKETS 65536
#define WINDOWS 4
typedef struct { VALUE frames[DEPTH]; int depth; uint64_t counts[WINDOWS]; } record;
static record *records;
static unsigned *buckets, used;
static volatile sig_atomic_t active, window_index;
static uint64_t gc[WINDOWS], empty[WINDOWS], truncated[WINDOWS], dropped[WINDOWS];
static uint64_t hooks[WINDOWS], lag_sum[WINDOWS], lag_max[WINDOWS], signals[WINDOWS];
static uint64_t work[WINDOWS], issued[WINDOWS];
static VALUE gc_root;

#define REQUEST(id, arg) VALGRIND_DO_CLIENT_REQUEST_EXPR(0, VG_USERREQ_TOOL_BASE('C','T') + id, arg, 0, 0, 0, 0)

static void sample(int sig) {
    uint64_t lag = REQUEST(103, 0);
    if (!active) return;
    uint64_t begin = REQUEST(100, 0);
    int w = window_index;
    signals[w]++;
    lag_sum[w] += lag;
    if (lag > lag_max[w]) lag_max[w] = lag;
    if (rb_during_gc()) gc[w]++;
    else {
        VALUE frames[DEPTH];
        int lines[DEPTH];
        int n = rb_profile_frames(0, DEPTH, frames, lines);
        if (n == DEPTH) truncated[w]++;
        if (!n) empty[w]++;
        uint64_t hash = 1469598103934665603ULL;
        for (int i = 0; i < n; i++) hash = (hash ^ frames[i]) * 1099511628211ULL;
        unsigned slot = hash & (BUCKETS - 1);
        while (buckets[slot]) {
            record *r = &records[buckets[slot] - 1];
            if (r->depth == n && !memcmp(r->frames, frames, n * sizeof(VALUE))) break;
            slot = (slot + 1) & (BUCKETS - 1);
        }
        if (!buckets[slot]) {
            if (used == RECORDS) { dropped[w]++; goto done; }
            record *r = &records[used];
            r->depth = n;
            memcpy(r->frames, frames, n * sizeof(VALUE));
            buckets[slot] = ++used;
        }
        records[buckets[slot] - 1].counts[w]++;
    }
done:
    hooks[w] += REQUEST(100, 0) - begin;
}

static void mark(void *unused) {
    uint64_t begin = 0;
    if (active) { REQUEST(104, 1); begin = REQUEST(100, 0); }
    for (unsigned r = 0; r < used; r++)
        for (int i = 0; i < records[r].depth; i++) rb_gc_mark(records[r].frames[i]);
    if (active) { hooks[window_index] += REQUEST(100, 0) - begin; REQUEST(104, 0); }
}

static const rb_data_type_t root_type = { "LowrailHotspotFrames", { mark, NULL, NULL } };

static VALUE measure(VALUE self, VALUE index, VALUE seed) {
    window_index = NUM2INT(index);
    if (window_index < 0 || window_index >= WINDOWS) rb_raise(rb_eArgError, "window index");
    active = 1;
    if (!REQUEST(101, NUM2ULONG(seed))) rb_raise(rb_eRuntimeError, "patched Callgrind required");
    rb_yield(Qnil);
    work[window_index] = REQUEST(102, 0);
    issued[window_index] = REQUEST(105, 0);
    active = 0;
    return Qnil;
}

static VALUE results(VALUE self) {
    VALUE result = rb_hash_new(), stacks = rb_ary_new(), windows = rb_ary_new();
    for (unsigned r = 0; r < used; r++) {
        VALUE paths = rb_ary_new(), counts = rb_ary_new();
        for (int i = 0; i < records[r].depth; i++) {
            VALUE path = rb_profile_frame_absolute_path(records[r].frames[i]);
            if (!RB_TYPE_P(path, T_STRING)) path = rb_profile_frame_path(records[r].frames[i]);
            /* Charge native primitives to their nearest Ruby caller. */
            if (RB_TYPE_P(path, T_STRING) && strcmp(StringValueCStr(path), "<cfunc>")) rb_ary_push(paths, path);
        }
        for (int w = 0; w < WINDOWS; w++) rb_ary_push(counts, ULL2NUM(records[r].counts[w]));
        rb_ary_push(stacks, rb_ary_new_from_args(2, paths, counts));
    }
    for (int w = 0; w < WINDOWS; w++) {
        VALUE row = rb_hash_new();
#define FIELD(name, value) rb_hash_aset(row, rb_str_new_cstr(name), ULL2NUM(value[w]))
        FIELD("signals", signals); FIELD("gc", gc); FIELD("empty", empty);
        FIELD("truncated", truncated); FIELD("dropped", dropped);
        FIELD("handler_ir", hooks); FIELD("lag_sum_ir", lag_sum); FIELD("lag_max_ir", lag_max);
        FIELD("work_ir", work); FIELD("issued", issued);
        rb_ary_push(windows, row);
    }
    rb_hash_aset(result, rb_str_new_cstr("stacks"), stacks);
    rb_hash_aset(result, rb_str_new_cstr("windows"), windows);
    return result;
}

void Init_lowrail_hotspots(void) {
    records = calloc(RECORDS, sizeof(record)); buckets = calloc(BUCKETS, sizeof(unsigned));
    if (!records || !buckets) rb_memerror();
    gc_root = TypedData_Wrap_Struct(rb_cObject, &root_type, records);
    rb_global_variable(&gc_root);
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = sample;
    action.sa_flags = SA_RESTART;
    sigemptyset(&action.sa_mask);
    sigaction(SIGPROF, &action, NULL);
    VALUE mod = rb_define_module("HotspotProbe");
    rb_define_singleton_method(mod, "measure", measure, 2);
    rb_define_singleton_method(mod, "results", results, 0);
}
