# Current-source blog interpreter re-price: accepted

**−15.022961% total interpreter Ir [−15.051352, −14.996655]** on blog
`GET /articles/1`, using the production form/token/collection artifact at
[`b059fc9`](https://github.com/thomasklemm/lowrail/commit/b059fc9fbcdbc4cff6a7bc523defb01e7783385c).
GC-excluded: **−15.021453% [−15.044109, −14.967704]**. This is one endpoint
and fixture, not native latency, YJIT, test-tier admission or a whole-app claim.
Default, quarantined and guarded passes are unchanged.

The source includes both helper-dispatch fixes and the
[token allocation prefix/suffix split](token-allocation.md). Token-only is
approximately allocation-neutral; that is not a standalone allocation win.
The frozen source also includes main's guard no-match allocation fix. Do not
attribute the difference from an earlier cohort solely to the token split.

## Prospective rule, not a rescue of rejected data

The owner authorized one new cohort and published its rule in
[`b059fc9` DECISIONS](../DECISIONS.md#token-allocation-fix-and-one-new-rule-blog-cohort-preregistered-2026-10-21)
**before counting**. Both total and no-GC A/A nominal 95% intervals must lie
wholly within **±0.1%**; zero containment is not required. The rationale:
the previous [+0.009283,+0.062511]% interval is immaterial relative to the
effect being priced, and the old rule rejected precision rather than material
bias. This cohort changes only its driver's A/A acceptance predicate; shared
estimates and all other gates remain unchanged. Four distinguishing synthetic
controls checked both positive/negative in-band acceptance and either metric's
out-of-band rejection before any requests/counters.

The [`62f8a6b` cohort stays rejected](production-dispatch-reprice.md) under
its original zero-containing/±0.5% rule. It is not re-scored, pooled or
discarded. The old **−15.225536%** remains defective-`553e7aa` source evidence
only, not this runtime's price. YJIT seam work remains paused.

## Frozen source and finite protocol

Clean detached `b059fc9`, one logical Callgrind slot (1), **18 serial workers,
six rounds, jobs=1**, seed 41231, N0/N50, warmup50 and balanced phase order.
Same historical worker, SHA-256
`c47b1adb13b8af544744bd20eb21e206481c26d6a359a452fd329458b865ed78`;
new preregistered driver SHA-256
`018534a689dd9a40db88b77c66e01f6b2f1c695c514549beb1446238a93e33c4`.
The pinned Valgrind 3.19.0 brk512 tool and floors
`[1000000,250000,100000,20000,10000]` are unchanged.

The public production interpreter artifact has **exactly three units**, no
source files/templates, manifest SHA-256
`ac31aa193040867aa4065e5de8535737f7729aa1f0e4e5af3a111cbfe97afbc4`.
Statistics are off inside counted work; actual holder checks, epoch checks,
context dispatch and saved-value continuations remain charged. No idle/JIT
companion applies to interpreter. No measurement retry or excluded round.

## Result

Per-request medians and nominal bootstrap 95% intervals over the six round
pairs, not independent samples for every request:

| Metric | Off-A / request | Production / request | Production Δ% [95% interval] | Off-B/A Δ% [95% interval] |
|---|---:|---:|---:|---:|
| Total Ir | 8,806,701.97 | 7,484,421.65 | **−15.022961 [−15.051352, −14.996655]** | −0.006435 [−0.068389, +0.004169] |
| GC-excluded Ir | 8,806,941.09 | 7,485,106.55 | **−15.021453 [−15.044109, −14.967704]** | −0.017653 [−0.077337, +0.033586] |
| Allocated objects (diagnostic) | 2,281.25 | 1,903.90 | −16.543562 [−16.570109, −16.522204] | −0.018849 [−0.027608, +0.043404] |

Both instruction A/A intervals are wholly within ±0.1%. All five heap
ranges, exact-page targets, brk and actual-interpreter gates pass. Every
window has zero minor/major collections. Total/no-GC are separate executions,
not GC savings. No peer worker-process or counter-window overlap; unrelated
host load is not censused and migration counts remain unavailable.

Independent read-only reconciliation verifies **72 dump totals and self-cost
sums, 36 N=0 subtractions, 18 before/after source certificates, 681 source
pins**, every round median and the prospective A/A predicate. All six on
workers finish with the three admissions active and no refusal.

Fresh pre/post gates both pass: raw entropy remains `rejected_off_control`;
both seeded cold off/off/on companions match status/body/all headers, SQL,
events, effects, loads and completion. Both **192-pair** controls (none and
render subscriber) match responses/observables, with hits **104/398/87** and
62 intentional collection fallbacks each. Native 50-show coverage is
**50/200/50**, zero fallbacks/refusals; epoch deopt adds **1/4/1** fallbacks
without additional hits. This is not broader subscriber/app support.

## Retained launch refusals and evidence

The first supervised launch dirtied a tracked Amp port-registry file and
failed the clean-source gate **before creating output or counter workers**.
Only that service-owned metadata change was restored; supervision moved to
`/tmp`, outside the frozen checkout. After the finite cohort finished, service
auto-restarts hit the existing-output refusal before any counter work until
the service was stopped. Exactly 18 worker certificates / 72 dumps exist;
these launcher refusals are not hidden measurement retries. Slot 1 is released.

[Complete export](production-aa01-reprice-results.json) includes samples,
summaries, source/worker pins, both correctness reports and the exact driver.
Private raw archive SHA-256:
`ca6b2d030ded1464717db310e0ff8dc8155dc719c8d6a110b1c32f40ba95d5e2`.
No README/results renderer input is changed by this publication.
