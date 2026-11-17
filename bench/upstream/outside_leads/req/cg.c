#include <ruby.h>
#include <valgrind/callgrind.h>
static VALUE instr_on(VALUE self) { CALLGRIND_START_INSTRUMENTATION; return Qnil; }
static VALUE toggle(VALUE self) { CALLGRIND_TOGGLE_COLLECT; return Qnil; }
static VALUE dump(VALUE self) { CALLGRIND_DUMP_STATS; CALLGRIND_STOP_INSTRUMENTATION; return Qnil; }
void Init_reqcg(void) {
  VALUE m = rb_define_module("ReqCG");
  rb_define_singleton_method(m, "instr_on", instr_on, 0);
  rb_define_singleton_method(m, "toggle", toggle, 0);
  rb_define_singleton_method(m, "dump", dump, 0);
}
