#include <ruby.h>
#include <valgrind/callgrind.h>

/* One Callgrind dump per call: each dump holds the instructions since the
 * previous one, so one dump after every iteration gives Ir per iteration. */
static VALUE dump(VALUE self) {
    CALLGRIND_DUMP_STATS;
    return Qnil;
}

void Init_ruby_bench_cg(void) {
    VALUE module = rb_define_module("RubyBenchCG");
    rb_define_singleton_method(module, "dump", dump, 0);
}
