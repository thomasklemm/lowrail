#define _GNU_SOURCE
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <string.h>
#include "all_thread_callgrind.h"

#ifndef __x86_64__
#error "Known instruction control requires x86_64"
#endif

/* Independent instruction oracle: test/jz/ret plus 4n or 6n instructions.
 * Build without CET/stack instrumentation. Padding/UD2 is never executed. */
__attribute__((naked, noinline, noclone)) void request_work(unsigned long n) {
    __asm__("test %rdi,%rdi; jz 2f; 1: add $1,%rax; xor %rdx,%rdx; dec %rdi; jnz 1b; 2: ret");
}
__attribute__((naked, noinline, noclone)) void background_work(unsigned long n) {
    __asm__("test %rdi,%rdi; jz 2f; 1: add $1,%rax; xor %rdx,%rdx; nop; nop; dec %rdi; jnz 1b; 2: ret");
}

static pthread_barrier_t go, done;
static unsigned long background_n, background_tid;
static long background_lwp;
static int stop;
static struct lowrail_cg_counts start_counts[LOWRAIL_CG_THREAD_LIMIT];
static void check(int result) { if (result) abort(); }
static void barrier(pthread_barrier_t *p) {
    int result = pthread_barrier_wait(p);
    if (result && result != PTHREAD_BARRIER_SERIAL_THREAD) abort();
}
static void *background(void *unused) {
    background_tid = lowrail_cg_tid();
    background_lwp = syscall(SYS_gettid);
    check(lowrail_cg_register());
    barrier(&done);
    for (;;) {
        barrier(&go);
        if (stop) return NULL;
        lowrail_cg_tick_begin();
        background_work(background_n);
        lowrail_cg_tick_end();
        barrier(&done);
    }
}
static void work(unsigned long request_n, unsigned long other_n) {
    background_n = other_n;
    barrier(&go);
    request_work(request_n);
    barrier(&done);
}
static void reset(void) {
    struct lowrail_cg_counts after[LOWRAIL_CG_THREAD_LIMIT];
    lowrail_cg_snapshot(start_counts);
    check(lowrail_cg_zero_all());
    lowrail_cg_snapshot(after);
    check(memcmp(start_counts, after, sizeof(start_counts)));
}
static void dump(const char *label) {
    struct lowrail_cg_counts before[LOWRAIL_CG_THREAD_LIMIT], after[LOWRAIL_CG_THREAD_LIMIT];
    lowrail_cg_snapshot(before);
    check(lowrail_cg_dump_all());
    lowrail_cg_snapshot(after);
    check(memcmp(before, after, sizeof(before)));
    printf("DUMP %s\n", label);
    printf("TICKS %s %lu %lu %lu %lu\n", label,
        start_counts[background_tid].started, start_counts[background_tid].completed,
        before[background_tid].started, before[background_tid].completed);
    memcpy(start_counts, before, sizeof(start_counts));
}

int main(void) {
    pthread_t thread;
    check(pthread_barrier_init(&go, NULL, 2));
    check(pthread_barrier_init(&done, NULL, 2));
    check(pthread_create(&thread, NULL, background, NULL));
    barrier(&done);
    if (!RUNNING_ON_VALGRIND || !background_tid) abort();
    check(lowrail_cg_register());
    printf("MAP request %lu %ld\nMAP background %lu %ld\n",
        lowrail_cg_tid(), syscall(SYS_gettid), background_tid, background_lwp);
    CALLGRIND_START_INSTRUMENTATION;
    reset(); work(0, 0); dump("empty");
    reset(); work(37, 113); dump("asymmetric_a");
    reset(); work(257, 19); dump("asymmetric_b");
    work(997, 1499);
    reset(); work(7, 41); dump("reset_all");
    /* No zero: the preceding all-thread dump must have rebaselined both. */
    work(9, 67); dump("dump_rebaseline");
    work(997, 1499);
    CALLGRIND_ZERO_STATS; work(7, 41); dump("negative_current_reset");
    reset(); work(37, 113);
    CALLGRIND_DUMP_STATS_AT("negative_current_dump");
    puts("DUMP negative_current_dump");
    dump("negative_dump_background_retained");
    reset();
    CALLGRIND_TOGGLE_COLLECT;
    work(5, 29);
    CALLGRIND_TOGGLE_COLLECT;
    request_work(7); dump("request_only_exclusion");
    reset();
    /* Background is parked at go, never released in this window. */
    request_work(43); dump("parked_background");
    reset(); work(37, 50000); dump("calibrate_off_a");
    reset(); work(10000, 50000); dump("calibrate_off_b");
    reset(); work(20000, 50000); dump("calibrate_on");
    CALLGRIND_STOP_INSTRUMENTATION;
    stop = 1; barrier(&go);
    check(pthread_join(thread, NULL));
    check(pthread_barrier_destroy(&go));
    check(pthread_barrier_destroy(&done));
    return 0;
}
