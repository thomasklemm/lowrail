#include <ruby.h>
#include <ruby/debug.h>
#include <valgrind/callgrind.h>

static int active, exclude_gc;
static unsigned long gc_segments;

/* ENTER/EXIT bracket each collector segment, including incremental marking
 * and lazy sweeping. START..END_SWEEP would also exclude intervening Ruby.
 * Internal-event callbacks must not allocate or invoke Ruby APIs. */
static void gc_event(rb_event_flag_t event, VALUE data, VALUE self, ID mid, VALUE klass) {
    if (!active) return;
    if (exclude_gc) CALLGRIND_TOGGLE_COLLECT;
    if (event == RUBY_INTERNAL_EVENT_GC_ENTER) gc_segments++;
}

/* Start after boot/warmup, not at process entry. N=0 subtracts this seam. */
static VALUE start(int argc, VALUE *argv, VALUE self) {
    VALUE exclude = Qfalse;
    rb_scan_args(argc, argv, "01", &exclude);
    exclude_gc = RTEST(exclude);
    gc_segments = 0;
    active = 1;
    CALLGRIND_START_INSTRUMENTATION;
    CALLGRIND_ZERO_STATS;
    return Qnil;
}

static VALUE finish(VALUE self) {
    active = 0;
    CALLGRIND_DUMP_STATS;
    CALLGRIND_STOP_INSTRUMENTATION;
    return ULONG2NUM(gc_segments);
}

void Init_lowrail_callgrind(void) {
    VALUE module = rb_define_module("LowrailCallgrindBench");
    rb_define_singleton_method(module, "start", start, -1);
    rb_define_singleton_method(module, "finish", finish, 0);
    rb_add_event_hook(gc_event, RUBY_INTERNAL_EVENT_GC_ENTER | RUBY_INTERNAL_EVENT_GC_EXIT, Qnil);
}
