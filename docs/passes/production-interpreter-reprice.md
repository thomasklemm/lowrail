# Corrected production specimen: interpreter re-price

**Accepted: −15.23% total interpreter Ir on one endpoint and fixture.** This
is production form/token/collection on **BlogShowGetOnly GET /articles/1**,
Ruby 4.0.7 / Rails 8.1.4, including the `ea44cf3` token-continuation safety
fix. It is not native latency, YJIT, whole-app performance or test admission.
The historical −15.49% remains a result for `ae025b0`, not this source.

**Later correctness finding:** measured `553e7aa` still had the production
private-helper / reflective-send dispatch defect. **−15.225536% remains a
price for that exact source and specimen only**, not the subsequently fixed
runtime. The [dispatch fix and correctness gates](sealed-production.md#helper-dispatch-safety)
do not remeasure it. The separately authorized
[dispatch-corrected cohort](production-dispatch-reprice.md) is **rejected A/A**;
there is no accepted replacement price. The original record below is retained.

## Frozen source and finite protocol

The clean detached measured harness/runtime is published
[`553e7aa`](https://github.com/thomasklemm/lowrail/commit/553e7aafa88754fd32359e5e11ba0cc5bfcd6f65).
Every worker records that exact SHA and a clean tree before and after, plus
runtime/harness/app/framework/native/Ruby/tool/fixture/artifact hashes.
Later publication commits carry the report, not a claim of execution at a
rebased SHA. The fresh public `--sealed --jit interpreter` artifact has exactly
three units and zero files/templates; manifest SHA-256:
`cf6e7f2593164db3a69a9cdcdb028c1d357ac3c8b0b1cf20370efe935dc131ec`.

This was **one authorized cohort, slot 1, no retry or exclusions**. The accepted
`50a01ac`/`ae025b0` interpreter method is unchanged: six randomized rounds,
seed 41231, off-A/off-B/production, N0/N50 subtraction, balanced phase order,
fixed five floors `[1000000,250000,100000,20000,10000]`, exact-page/brk512
controls, and both total AND GC-excluded A/A 95% intervals containing zero
within ±0.5%. All 18 workers ran sequentially. The private worker is byte-identical
to the historical worker; the detached driver changes only pins, gate reference
and one-slot metadata. Both complete sources are in the
[numeric export](production-interpreter-reprice-results.json).

No YJIT component or idle companion ran in this cohort. The JIT-specific idle
control is not applicable, not an executed pass. All actual warm-request guard,
witness-state, dispatch and original-continuation work remains charged;
statistics are off inside counter workers. One-time admission/witness work is
outside these warm windows, not a cold-latency estimate. No production/default/
quarantine code changed.

## Result

Per-request medians and nominal bootstrap 95% intervals over **six independent
round pairs**, not 50 independent request samples per worker:

| Metric | Off-A / request | Production / request | Production Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|---:|---:|
| Total Ir | 8,815,822.38 | 7,472,806.32 | **−15.225536 [−15.253476, −15.205974]** | +0.001751 [−0.033267, +0.030652] |
| GC-excluded Ir | 8,816,209.51 | 7,471,051.29 | **−15.254650 [−15.278100, −15.199984]** | −0.010726 [−0.025117, +0.023088] |
| Allocated objects (diagnostic) | 2,281.17 | 1,886.43 | −17.304337 [−17.313753, −17.281653] | +0.009206 [−0.012273, +0.038140] |

Both A/A controls, all five heaps/exact-page targets, brk preflight/worker
checks and interpreter-mode gates pass. Independently reconciled **72 dumps**
and **36 N0 subtractions**, and all 18 before/after source certificates.
All windows have zero minor/major collections. Total and no-GC are separate
executions; their difference is not GC savings. Every retained placement
endpoint reports no peer process/window overlap in this sequential cohort.
This is not a census of host load. Migration counts remain unavailable;
matching endpoint CPUs do not prove no migration. Slot 1 is released.

Fresh **pre- and post-cohort** production checks pass: both seeded cold
off/off/on controls, both **192-pair** controls, and native/deopt. Paired hits
are **104/398/87**, with **62 intentionally exercised collection fallbacks**
per control. Native 50 shows **50/200/50 hits and zero fallbacks/refusals**;
global deopt gives **1/4/1 fallbacks**, no extra hits. All six measured on
workers finish with all three admissions active and no refusal. Raw entropy
remains `rejected_off_control`; nothing was normalized to obtain equality.

This replaces the earlier price **for the corrected source and this specimen**,
not retrospectively for `ae025b0` or any other fixture. The native YJIT method
remains rejected and its v2 design unexecuted. No YJIT cohort is authorized.
