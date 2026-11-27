// Sets the VM interrupt flag the way GC's deferred finalization does (a postponed job), either synchronously
// (Trig.set) or from a background pthread every PERIOD µs while Trig.mode = true.
#include <ruby.h>
#include <ruby/debug.h>
#include <pthread.h>
#include <time.h>
static rb_postponed_job_handle_t h;
static volatile unsigned long fired, ran;
static volatile int period_us, mode;
static void job(void *d) { ran++; }
static VALUE t_set(VALUE s) { rb_postponed_job_trigger(h); fired++; return Qnil; }
static VALUE t_noop(VALUE s) { return Qnil; }
static void *loop_fn(void *a) {
  struct timespec ts;
  while (period_us > 0) {
    ts.tv_sec = period_us / 1000000; ts.tv_nsec = (long)(period_us % 1000000) * 1000;
    nanosleep(&ts, 0);
    if (mode) { rb_postponed_job_trigger(h); fired++; }
  }
  return 0;
}
static VALUE t_start(VALUE s, VALUE us) { pthread_t t; period_us = NUM2INT(us); pthread_create(&t, 0, loop_fn, 0); pthread_detach(t); return Qnil; }
static VALUE t_mode(VALUE s, VALUE m) { mode = RTEST(m); return m; }
static VALUE t_counts(VALUE s) { return rb_ary_new_from_args(2, ULONG2NUM(fired), ULONG2NUM(ran)); }
void Init_trig(void) {
  h = rb_postponed_job_preregister(0, job, NULL);
  VALUE m = rb_define_module("Trig");
  rb_define_module_function(m, "set", t_set, 0);
  rb_define_module_function(m, "noop", t_noop, 0);
  rb_define_module_function(m, "start", t_start, 1);
  rb_define_module_function(m, "mode=", t_mode, 1);
  rb_define_module_function(m, "counts", t_counts, 0);
}
