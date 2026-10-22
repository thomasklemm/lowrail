# Bet J: fewer objects, more collections

## Preregistered screen (2026-10-22; no measurements yet)

Hypothesis, not diagnosis: Lowrail's on arm leaves less usable capacity in a
size pool after boot/warmup. Measure every Puma worker's complete `GC.stat`
and `GC.stat_heap` at worker boot, post-warmup, three times during load
(0.25 s, midpoint, 0.5 s before the end), and post-load. Snapshots are
non-atomic, allocating observers, identical in all arms, not exclusive request
counters. No objspace, forced GC, altered growth policy or app/config edits.

Retain runtime/harness lineage `6510cd2` (runtime includes `5ac665c`), retained
blog source `86ebd4a8`, fresh BlogShowGetOnly schema/seed, unchanged denylist,
rebuilt three-unit YJIT artifact. Stock Ruby 4.0.7 / Rails 8.1.4. Use existing
`script/rps`: three rotated off-A/on/off-B rounds, 5 s warmup / 5 s load,
Puma 4 workers × 1 thread, c16, server CPUs 0–3 / client CPUs 4–7. Keep native
GC tags and passive wire capture identical from every first load window,
including screens. Two-seed cold/warm exact checks and separate coverage
preflight; retain every observation and any setup failures. No throughput
price from the short screen, retries, exclusions or pooling.

Inspect A/A first. Confirm the hypothesis only if the excess collection rate
reproduces and the on arm consistently has less available capacity/reclaimed
slots in an allocation-active size pool than both off arms, beyond their
observed spread. Raw free-slot snapshots alone do not prove causality: GC
phase changes them. Pool allocation and freed-object deltas plus page growth
must support the account. Otherwise stop with a five-line DECISIONS note.

Only if confirmed, derive **one common**, opt-in pool floor/policy from the
measured maximum steady-state pool capacities; apply it identically in all
three arms first. One further short screen under the same protocol must show
a resolved improvement: its GC-collections/1,000 on-arm change must exceed
both screens' maximum absolute off-A/off-B spreads, or its p99 change must
clear that corresponding noise floor. Preserve exactness, errors and pins.
Otherwise kill, not another variant.

At most one confirmatory RPS cohort is conditional on that short-screen gate:
20 rotated rounds, 5 s warmup / 20 s load, otherwise the `44a33c4`/`544ad8d`
protocol and all observers above. Preregister actual common floor/policy
before launch. A/A paired RPS 95% CI must contain zero and on/off lower bound
must exceed A/A upper bound, existing seed41231/5,000-bootstrap mean paired
percentage deltas. Report p50/p90/p99, all GC/RSS/heap effects and costs even
if worse. No retries, exclusions, relaxed rule or README/main promotion.

## Authorized bounded site diagnosis (declared after the screen)

The smaller-heap screen fails its gate; **no shaping and no RPS cohort**.
The coordinator authorizes one untimed allocation-site follow-up to the
observed on-only 320-byte-pool `force_major_gc_count` increments. Run three
fresh off-A/on/off-B workers with the same source/artifact/seed, counters off,
stock YJIT and 500 real Rack warm requests. Trace boot/warm allocations;
after three full collections, census their retained 320-byte objects. Then
clear tracing metadata, disable GC only for twenty traced requests, and count
sites by the dump's actual **`slot_size:320`**, not `memsize` alone. Restore
GC, collect three times with FREEOBJ tracing active, and census survivors.
Export only type/site/count/size metadata, no values, addresses or heap dumps.

This deliberately perturbs heap history and removes Puma/background activity:
it identifies allocations, **not** natural GC frequency, p99 or a causal
explanation of the historical cohort. Compare each size pool's allocation
counter with enumerated objects and retain any residual. No runtime change,
heap variant or performance rerun follows. Keep the bet open only if the
result names a concrete lowering-side fix; otherwise include it in the kill.
