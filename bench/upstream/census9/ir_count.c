/* Census 9: read the measuring thread's exact Callgrind Ir from Ruby, so one
 * process measures many cases (needs census 8's patched Callgrind, request
 * 100 of cpu-valgrind.patch). Run with --instr-atstart=no: boot and setup run
 * uninstrumented until IrCount.start. Measurement only. */
#include <ruby.h>
#include <valgrind/callgrind.h>

#define REQUEST(id, a, b) VALGRIND_DO_CLIENT_REQUEST_EXPR(0, VG_USERREQ_TOOL_BASE('C','T') + id, a, b, 0, 0, 0)

static VALUE start(VALUE self) {
    CALLGRIND_START_INSTRUMENTATION;
    return Qnil;
}

static VALUE now(VALUE self) {
    return ULL2NUM((unsigned long long)REQUEST(100, 0, 0));
}

static VALUE running(VALUE self) {
    return RUNNING_ON_VALGRIND ? Qtrue : Qfalse;
}

void Init_ir_count(void) {
    VALUE mod = rb_define_module("IrCount");
    rb_define_singleton_method(mod, "start", start, 0);
    rb_define_singleton_method(mod, "now", now, 0);
    rb_define_singleton_method(mod, "running?", running, 0);
}
