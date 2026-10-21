/* Measurement only. Bounded native buffers: no Ruby allocations in requests
 * or GC callbacks. Capture GC ENTER/EXIT pauses, not entire lazy GC cycles. */
#include <ruby.h>
#include <ruby/debug.h>
#include <ruby/io.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <time.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define REQUESTS 32768
#define PAUSES 131072
typedef struct { uint64_t start, end, mono_start, mono_end; size_t gc_before, gc_after; unsigned port; } request;
typedef struct { uint64_t start, end; } pause_record;
static request *requests;
static pause_record *pauses;
static unsigned request_count, pause_count, request_dropped, pause_dropped;
static int active, in_gc;
static VALUE trace;
static uint64_t request_cpu_ns, pause_cpu_ns;

static uint64_t now(clockid_t clock) {
    struct timespec value;
    clock_gettime(clock, &value);
    return (uint64_t)value.tv_sec * 1000000000ULL + value.tv_nsec;
}

static void gc_event(VALUE tracepoint, void *unused) {
    if (!active) return;
    uint64_t cpu = now(CLOCK_THREAD_CPUTIME_ID);
    rb_event_flag_t event = rb_tracearg_event_flag(rb_tracearg_from_tracepoint(tracepoint));
    if (event == RUBY_INTERNAL_EVENT_GC_ENTER) {
        if (pause_count == PAUSES) { pause_dropped++; return; }
        pauses[pause_count].start = now(CLOCK_REALTIME);
        pauses[pause_count].end = 0;
        in_gc = 1;
    } else if (in_gc) {
        pauses[pause_count++].end = now(CLOCK_REALTIME);
        in_gc = 0;
    }
    pause_cpu_ns += now(CLOCK_THREAD_CPUTIME_ID) - cpu;
}

static VALUE start_capture(VALUE self) {
    if (active) return Qnil;
    if (!requests) requests = calloc(REQUESTS, sizeof(request));
    if (!pauses) pauses = calloc(PAUSES, sizeof(pause_record));
    if (!requests || !pauses) rb_memerror();
    request_count = pause_count = request_dropped = pause_dropped = 0;
    request_cpu_ns = pause_cpu_ns = 0;
    in_gc = 0;
    active = 1;
    rb_tracepoint_enable(trace);
    return Qnil;
}

static VALUE begin_request(VALUE self, VALUE socket) {
    if (!active) return Qnil;
    uint64_t cpu = now(CLOCK_THREAD_CPUTIME_ID);
    if (request_count == REQUESTS) { request_dropped++; return Qnil; }
    struct sockaddr_in peer;
    socklen_t length = sizeof(peer);
    if (getpeername(rb_io_descriptor(socket), (struct sockaddr *)&peer, &length) || peer.sin_family != AF_INET)
        rb_raise(rb_eRuntimeError, "GC tags require direct IPv4 HTTP sockets");
    unsigned index = request_count++;
    request *r = &requests[index];
    r->port = ntohs(peer.sin_port);
    r->start = now(CLOCK_REALTIME);
    r->mono_start = now(CLOCK_MONOTONIC);
    r->end = 0;
    r->gc_before = rb_gc_count();
    request_cpu_ns += now(CLOCK_THREAD_CPUTIME_ID) - cpu;
    return UINT2NUM(index);
}

static VALUE end_request(VALUE self, VALUE index) {
    if (NIL_P(index)) return Qnil;
    uint64_t cpu = now(CLOCK_THREAD_CPUTIME_ID);
    request *r = &requests[NUM2UINT(index)];
    r->gc_after = rb_gc_count();
    r->mono_end = now(CLOCK_MONOTONIC);
    r->end = now(CLOCK_REALTIME);
    request_cpu_ns += now(CLOCK_THREAD_CPUTIME_ID) - cpu;
    return Qnil;
}

static VALUE dump(VALUE self, VALUE path) {
    active = 0;
    rb_tracepoint_disable(trace);
    FILE *file = fopen(StringValueCStr(path), "w");
    if (!file) rb_sys_fail("GC tags dump");
    fprintf(file, "# pid=%ld request_dropped=%u pause_dropped=%u open_gc=%d request_cpu_ns=%llu pause_cpu_ns=%llu\n",
            (long)getpid(), request_dropped, pause_dropped, in_gc,
            (unsigned long long)request_cpu_ns, (unsigned long long)pause_cpu_ns);
    for (unsigned i = 0; i < request_count; i++) {
        request *r = &requests[i];
        fprintf(file, "R,%u,%u,%llu,%llu,%llu,%llu,%zu,%zu\n", i, r->port,
                (unsigned long long)r->start, (unsigned long long)r->end,
                (unsigned long long)r->mono_start, (unsigned long long)r->mono_end,
                r->gc_before, r->gc_after);
    }
    for (unsigned i = 0; i < pause_count; i++)
        fprintf(file, "G,%llu,%llu\n", (unsigned long long)pauses[i].start,
                (unsigned long long)pauses[i].end);
    if (fclose(file)) rb_sys_fail("GC tags close");
    return rb_ary_new_from_args(4, UINT2NUM(request_count), UINT2NUM(pause_count),
                               UINT2NUM(request_dropped), UINT2NUM(pause_dropped));
}

void Init_rps_gc_tags(void) {
    VALUE mod = rb_define_module("RpsGcTags");
    rb_define_singleton_method(mod, "start", start_capture, 0);
    rb_define_singleton_method(mod, "begin_request", begin_request, 1);
    rb_define_singleton_method(mod, "end_request", end_request, 1);
    rb_define_singleton_method(mod, "dump", dump, 1);
    trace = rb_tracepoint_new(Qnil, RUBY_INTERNAL_EVENT_GC_ENTER | RUBY_INTERNAL_EVENT_GC_EXIT, gc_event, NULL);
    rb_global_variable(&trace);
}
