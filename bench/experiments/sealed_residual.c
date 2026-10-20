/* Diagnostic boundary counters on the SAME pinned Callgrind. No sampler or
 * patched VM. Nested selected boundaries count once. N=0 removes the seam.
 * Other boundaries can overlap across separate runs: do not add their prices. */
#include <ruby.h>
#include <valgrind/callgrind.h>
static int active, selected, depth;
static VALUE start(VALUE self, VALUE scope) {
    selected = NUM2INT(scope); depth = 0; active = 1;
    if (selected) CALLGRIND_TOGGLE_COLLECT;
    return Qnil;
}
static VALUE finish(VALUE self) {
    if (depth) rb_raise(rb_eRuntimeError, "unbalanced residual boundary");
    if (selected) CALLGRIND_TOGGLE_COLLECT;
    active = 0;
    return Qnil;
}
static VALUE leave(VALUE unused) {
    if (!--depth) CALLGRIND_TOGGLE_COLLECT;
    return Qnil;
}
static VALUE body(VALUE unused) { return rb_yield(Qnil); }
static VALUE record(VALUE self, VALUE scope) {
    if (!active || NUM2INT(scope) != selected || !selected) return rb_yield(Qnil);
    if (!depth++) CALLGRIND_TOGGLE_COLLECT;
    return rb_ensure(body, Qnil, leave, Qnil);
}
void Init_sealed_residual(void) {
    VALUE mod = rb_define_module("SealedResidual");
    rb_define_singleton_method(mod, "start", start, 1);
    rb_define_singleton_method(mod, "finish", finish, 0);
    rb_define_singleton_method(mod, "record", record, 1);
}
