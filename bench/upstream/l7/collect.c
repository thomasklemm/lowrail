/* Lead 7: toggle Callgrind's event collection from Ruby, for a profile of one
 * window (run with --collect-atstart=no). Measurement only. */
#include <ruby.h>
#include <valgrind/callgrind.h>

static VALUE toggle(VALUE self) {
    CALLGRIND_TOGGLE_COLLECT;
    return Qnil;
}

void Init_collect(void) {
    rb_define_singleton_method(rb_define_module("Collect"), "toggle", toggle, 0);
}
