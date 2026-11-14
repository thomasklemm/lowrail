/* Lead 6: zero and dump Callgrind's counters from Ruby, to take a callgrind_annotate profile of one measured
 * window. Measurement only. */
#include <ruby.h>
#include <valgrind/callgrind.h>

static VALUE zero(VALUE self) { CALLGRIND_ZERO_STATS; return Qnil; }
static VALUE dump(VALUE self, VALUE name) { CALLGRIND_DUMP_STATS_AT(StringValueCStr(name)); return Qnil; }

void Init_cg_ctl(void) {
    VALUE mod = rb_define_module("CgCtl");
    rb_define_singleton_method(mod, "zero", zero, 0);
    rb_define_singleton_method(mod, "dump", dump, 1);
}
