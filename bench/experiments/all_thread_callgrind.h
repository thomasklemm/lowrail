#ifndef LOWRAIL_ALL_THREAD_CALLGRIND_H
#define LOWRAIL_ALL_THREAD_CALLGRIND_H
#include <valgrind/callgrind.h>
#include <stdatomic.h>
#include <sys/syscall.h>
#include <unistd.h>

/* NON_SIMD_CALL runs on the host, passes its scheduler ThreadId, does no I/O.
 * IDs can be reused after exit: the caller must retain native-ID/lifetime data. */
static unsigned long lowrail_cg_return_tid(unsigned long tid) { return tid; }
static unsigned long lowrail_cg_tid(void) {
    return VALGRIND_NON_SIMD_CALL0(lowrail_cg_return_tid);
}

/* Bench-only, explicit activity marks. These do NOT observe Rails reaper ticks.
 * Never infer an unmarked tick from elapsed time or an instruction count.
 * Registration happens before a window; ID reuse/overflow is a refusal. */
#define LOWRAIL_CG_THREAD_LIMIT 1024
struct lowrail_cg_activity {
    _Atomic unsigned long lwp, started, completed;
};
struct lowrail_cg_counts {
    unsigned long lwp, started, completed;
};
static struct lowrail_cg_activity lowrail_cg_activities[LOWRAIL_CG_THREAD_LIMIT];
static _Thread_local struct lowrail_cg_activity *lowrail_cg_current;
static int lowrail_cg_register(void) {
    unsigned long tid = lowrail_cg_tid(), lwp = syscall(SYS_gettid);
    if (!RUNNING_ON_VALGRIND || !tid || tid >= LOWRAIL_CG_THREAD_LIMIT) return 1;
    struct lowrail_cg_activity *slot = &lowrail_cg_activities[tid];
    if (atomic_load(&slot->lwp) && atomic_load(&slot->lwp) != lwp) return 1;
    atomic_store(&slot->lwp, lwp);
    lowrail_cg_current = slot;
    return 0;
}
/* Keep symbols so the synthetic profile reports these primitives' own Ir. */
__attribute__((noinline, noclone)) static void lowrail_cg_tick_begin(void) {
    atomic_fetch_add(&lowrail_cg_current->started, 1);
}
__attribute__((noinline, noclone)) static void lowrail_cg_tick_end(void) {
    atomic_fetch_add(&lowrail_cg_current->completed, 1);
}
static void lowrail_cg_snapshot(struct lowrail_cg_counts *out) {
    for (int i = 0; i < LOWRAIL_CG_THREAD_LIMIT; i++) {
        out[i].lwp = atomic_load(&lowrail_cg_activities[i].lwp);
        out[i].started = atomic_load(&lowrail_cg_activities[i].started);
        out[i].completed = atomic_load(&lowrail_cg_activities[i].completed);
    }
}
static int lowrail_cg_zero_all(void) {
    return !RUNNING_ON_VALGRIND || VALGRIND_MONITOR_COMMAND("zero");
}
static int lowrail_cg_dump_all(void) {
    return !RUNNING_ON_VALGRIND || VALGRIND_MONITOR_COMMAND("dump lowrail-window");
}
#endif
