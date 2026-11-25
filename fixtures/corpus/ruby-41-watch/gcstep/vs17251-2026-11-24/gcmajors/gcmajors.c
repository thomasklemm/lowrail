/* Per-GC record for attributing majors (measurement only, loaded by the shipit harness when GCMAJORS_SO is set).
 * GC_START: cumulative GC.stat(:time) and old_objects before the GC. GC_END_SWEEP: the same GC's major_by,
 * old_objects and old_objects_limit after it, and GC.stat(:time) again, so a GC's time covers its marking and all of
 * its lazy sweep steps. GCMajors.records => [[major_by or nil, ms, old_before, old_after, limit_after], ...]. */
#include <ruby.h>
#include <ruby/debug.h>

#define MAX 65536
static struct { VALUE by; size_t ms, old_before, old_after, limit; } rec[MAX];
static size_t n, start_ms, start_old;
static int on;
static VALUE sym_time, sym_old, sym_limit, sym_major_by;

static void
hook(VALUE tpval, void *data)
{
    if (!on) return;
    rb_trace_arg_t *arg = rb_tracearg_from_tracepoint(tpval);
    if (rb_tracearg_event_flag(arg) == RUBY_INTERNAL_EVENT_GC_START) {
        start_ms = rb_gc_stat(sym_time);
        start_old = rb_gc_stat(sym_old);
    }
    else if (n < MAX) {
        rec[n].by = rb_gc_latest_gc_info(sym_major_by);
        rec[n].ms = rb_gc_stat(sym_time) - start_ms;
        rec[n].old_before = start_old;
        rec[n].old_after = rb_gc_stat(sym_old);
        rec[n].limit = rb_gc_stat(sym_limit);
        n++;
    }
}

static VALUE
start(VALUE self)
{
    n = 0;
    on = 1;
    return Qnil;
}

static VALUE
records(VALUE self)
{
    on = 0;
    VALUE a = rb_ary_new_capa(n);
    for (size_t i = 0; i < n; i++) {
        rb_ary_push(a, rb_ary_new_from_args(5, rec[i].by, SIZET2NUM(rec[i].ms), SIZET2NUM(rec[i].old_before),
            SIZET2NUM(rec[i].old_after), SIZET2NUM(rec[i].limit)));
    }
    return a;
}

void
Init_gcmajors(void)
{
    sym_time = ID2SYM(rb_intern("time"));
    sym_old = ID2SYM(rb_intern("old_objects"));
    sym_limit = ID2SYM(rb_intern("old_objects_limit"));
    sym_major_by = ID2SYM(rb_intern("major_by"));
    VALUE m = rb_define_module("GCMajors");
    rb_define_module_function(m, "start", start, 0);
    rb_define_module_function(m, "records", records, 0);
    VALUE tp = rb_tracepoint_new(0, RUBY_INTERNAL_EVENT_GC_START | RUBY_INTERNAL_EVENT_GC_END_SWEEP, hook, NULL);
    rb_gc_register_mark_object(tp);
    rb_tracepoint_enable(tp);
}
