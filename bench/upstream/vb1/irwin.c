// Callgrind windows for Ruby with stock Valgrind: IrWin.instr_on starts instrumentation (run with
// --instr-atstart=no), IrWin.zero zeroes the counters, and IrWin.dump(name) writes them to a numbered dump
// file whose "totals:" line is the window's Ir, then zeroes them again.
#include <ruby.h>
#include <valgrind/callgrind.h>

static VALUE instr_on(VALUE self) { CALLGRIND_START_INSTRUMENTATION; return Qnil; }
static VALUE zero(VALUE self) { CALLGRIND_ZERO_STATS; return Qnil; }
static VALUE dump(VALUE self, VALUE name) { CALLGRIND_DUMP_STATS_AT(StringValueCStr(name)); return Qnil; }
static VALUE running(VALUE self) { return RUNNING_ON_VALGRIND ? Qtrue : Qfalse; }

void Init_irwin(void) {
  VALUE m = rb_define_module("IrWin");
  rb_define_module_function(m, "instr_on", instr_on, 0);
  rb_define_module_function(m, "zero", zero, 0);
  rb_define_module_function(m, "dump", dump, 1);
  rb_define_module_function(m, "running?", running, 0);
}
