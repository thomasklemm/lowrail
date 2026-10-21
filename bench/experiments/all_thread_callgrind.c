#define _GNU_SOURCE
#include <ruby.h>
#include <ruby/debug.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <string.h>
#include "all_thread_callgrind.h"

/* Experimental alternative extension, never loaded by the accepted worker by
 * default. Monitor requests are synchronous all-thread endpoints. */
static int active, exclude_gc;
static unsigned long owner, gc_segments;
static struct lowrail_cg_counts start_counts[LOWRAIL_CG_THREAD_LIMIT];
static struct lowrail_cg_counts end_counts[LOWRAIL_CG_THREAD_LIMIT];
static struct lowrail_cg_counts scratch_counts[LOWRAIL_CG_THREAD_LIMIT];

static void gc_event(rb_event_flag_t event, VALUE data, VALUE self, ID mid, VALUE klass) {
    if (!active || !exclude_gc || lowrail_cg_tid() != owner) return;
    /* Exclude only request-thread GC; background Ir remains complete in both
     * modes. No Ruby APIs, allocations, all-thread reset or dump in this hook. */
    CALLGRIND_TOGGLE_COLLECT;
    if (event == RUBY_INTERNAL_EVENT_GC_ENTER) gc_segments++;
}

static VALUE identity(VALUE self) {
    unsigned long tid = lowrail_cg_tid();
    if (lowrail_cg_register()) rb_raise(rb_eRuntimeError, "Valgrind thread identity unavailable");
    return rb_ary_new_from_args(2, ULONG2NUM(tid), LONG2NUM(syscall(SYS_gettid)));
}

static VALUE tick_begin(VALUE self) {
    if (!lowrail_cg_current && lowrail_cg_register()) rb_raise(rb_eRuntimeError, "activity identity unavailable");
    if (atomic_load(&lowrail_cg_current->started) != atomic_load(&lowrail_cg_current->completed))
        rb_raise(rb_eRuntimeError, "nested activity begin");
    lowrail_cg_tick_begin();
    return Qnil;
}

static VALUE tick_end(VALUE self) {
    if (!lowrail_cg_current || atomic_load(&lowrail_cg_current->started) != atomic_load(&lowrail_cg_current->completed) + 1)
        rb_raise(rb_eRuntimeError, "unpaired activity end");
    lowrail_cg_tick_end();
    return Qnil;
}

static VALUE window_activity(VALUE self) {
    if (active) rb_raise(rb_eRuntimeError, "counter still active");
    VALUE rows = rb_ary_new();
    for (int i = 1; i < LOWRAIL_CG_THREAD_LIMIT; i++) {
        if (!end_counts[i].lwp) continue;
        rb_ary_push(rows, rb_ary_new_from_args(6, INT2NUM(i), ULONG2NUM(end_counts[i].lwp),
            ULONG2NUM(start_counts[i].started), ULONG2NUM(start_counts[i].completed),
            ULONG2NUM(end_counts[i].started), ULONG2NUM(end_counts[i].completed)));
    }
    return rows;
}

static VALUE start(int argc, VALUE *argv, VALUE self) {
    VALUE exclude = Qfalse;
    rb_scan_args(argc, argv, "01", &exclude);
    if (active) rb_raise(rb_eRuntimeError, "counter already active");
    if (!RUNNING_ON_VALGRIND) rb_raise(rb_eRuntimeError, "Callgrind required");
    owner = lowrail_cg_tid();
    if (lowrail_cg_register()) rb_raise(rb_eRuntimeError, "request thread identity unavailable");
    exclude_gc = RTEST(exclude);
    gc_segments = 0;
    CALLGRIND_START_INSTRUMENTATION;
    lowrail_cg_snapshot(start_counts);
    if (lowrail_cg_zero_all()) rb_raise(rb_eRuntimeError, "all-thread reset unavailable");
    lowrail_cg_snapshot(scratch_counts);
    if (memcmp(start_counts, scratch_counts, sizeof(start_counts))) rb_raise(rb_eRuntimeError, "activity crossed reset endpoint");
    active = 1;
    return Qnil;
}

static VALUE finish(VALUE self) {
    if (!active || lowrail_cg_tid() != owner) rb_raise(rb_eRuntimeError, "counter owner mismatch");
    active = 0;
    lowrail_cg_snapshot(end_counts);
    if (lowrail_cg_dump_all()) rb_raise(rb_eRuntimeError, "all-thread dump unavailable");
    lowrail_cg_snapshot(scratch_counts);
    CALLGRIND_STOP_INSTRUMENTATION;
    if (memcmp(end_counts, scratch_counts, sizeof(end_counts))) rb_raise(rb_eRuntimeError, "activity crossed dump endpoint");
    return ULONG2NUM(gc_segments);
}

void Init_lowrail_all_thread_callgrind(void) {
    VALUE module = rb_define_module("LowrailCallgrindBench");
    rb_define_singleton_method(module, "start", start, -1);
    rb_define_singleton_method(module, "finish", finish, 0);
    rb_define_singleton_method(module, "thread_identity", identity, 0);
    rb_define_singleton_method(module, "tick_begin", tick_begin, 0);
    rb_define_singleton_method(module, "tick_end", tick_end, 0);
    rb_define_singleton_method(module, "window_activity", window_activity, 0);
    rb_add_event_hook(gc_event, RUBY_INTERNAL_EVENT_GC_ENTER | RUBY_INTERNAL_EVENT_GC_EXIT, Qnil);
}
