#include <ruby.h>
#include <valgrind/callgrind.h>

/* Start after boot/warmup, not at process entry. N=0 subtracts this seam. */
static VALUE start(VALUE self) {
    CALLGRIND_START_INSTRUMENTATION;
    CALLGRIND_ZERO_STATS;
    return Qnil;
}

static VALUE finish(VALUE self) {
    CALLGRIND_DUMP_STATS;
    CALLGRIND_STOP_INSTRUMENTATION;
    return Qnil;
}

void Init_lowrail_callgrind(void) {
    VALUE module = rb_define_module("LowrailCallgrindBench");
    rb_define_singleton_method(module, "start", start, 0);
    rb_define_singleton_method(module, "finish", finish, 0);
}
