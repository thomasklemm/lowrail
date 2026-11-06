# QueryRequest / QueryIntent prototype (PM1b)

This measures an architectural refactor, not an optimization. The record and
decision are in [perf-round-main](../../../docs/upstream/perf-round-main.md#pm1b-queryrequest-holds-query-data-2026-11-06).

Run the driver with the Ruby being measured, a bundle containing Active Record's
dependencies and sqlite3 2.5.0, and three Rails trees (main, independent main
control, candidate):

```sh
BUNDLE_GEMFILE=/path/to/Gemfile ruby bench/upstream/query_request/run.rb \
  /new/output/directory /rails/main /rails/main-control /rails/candidate
```

The driver uses `~/vg-brk512/bin/valgrind` by default (`VALGRIND` overrides it).
It compiles Lowrail's existing Callgrind client extension for the current Ruby.
The bundle is identical in all arms; the worker prepends the selected tree's
Active Support, Active Model and Active Record libraries before requiring them.
Every worker records its loaded gem versions and Rails commit. No Lowrail runtime
or query cache is enabled.

Three fresh-process rounds rotate main/control/candidate order. Each case has
500 warmups, then N=0 and N=500 GC-disabled windows. Instructions, allocated
objects and allocated heap-slot bytes are differences divided by N. Slot bytes
are the sum of per-pool allocation counts times slot size, not retained memory
or RSS. `HeapWindows` fixes all Ruby pools; the driver rejects growth, unequal
capacity across workers and Valgrind brk overflow. Object layout is observed
after the windows, without instrumenting the measured execution.

The driver's exact-slot-equality check is **stricter** than Lowrail's published
one-page rounding rule. The record reports both, preserving the extra rejection
without calling it a failure of the published heap rule. These three-round,
GC-disabled micros do not claim the full six-round total/no-GC admission protocol.
Descriptive paired-round bootstrap intervals use `RequestPairs.estimate`.

The fixture has three rows, two matching `where`; the bound lookup, selection,
update count, async selection and proxy result are checked before warmup.
The async case waits for its future before consuming it, with at most 30,000
one-millisecond sleeps; the wait itself is inside the instruction window. Its
instruction count is scheduler-sensitive, so a failed A/A remains rejected.
The proxy case exercises
the actual proxy adapter, request marshaling and physical-side execution in the
main Ractor. It does **not** measure worker/main messaging latency. Real worker
Ractor correctness is covered separately by Rails' Ractor suites.

An earlier executor-counter-wait cohort is retained separately as rejected:
its first async A/A failed, and a later control stalled with completed/scheduled
counts 548/549, an empty queue and idle workers. It was stopped, not rerun until
green. A second, busy-polling per-future attempt spent minutes in the async
window; debugger inspection was followed by a clock syscall error. That
incomplete/debugged attempt is discarded, not attributed to Rails or pooled
with the final cohort. Sleeping instead of spinning avoids counting an
unbounded volume of polling instructions; no async CPU improvement is claimed.

`BENCH_JIT=zjit` selects the pinned master's ZJIT and Lowrail's existing
`JitStability` warmup/observation controls. The complete control result is retained,
including missing counters; a failed flatness gate admits no JIT speed claim.
ZJIT out-of-memory counts are recorded. Interpreter is the default.
