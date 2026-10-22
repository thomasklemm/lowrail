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

## Result: stop; no supported heap or lowering fix

Completed one three-round screen at
[`266ecc4`](https://github.com/thomasklemm/lowrail/commit/266ecc482148fc9419aa0ec24ac4d72c87a8600f).
**A/A first:** RPS mean +2.447%, nominal paired 95% interval
**[−2.346%, +7.650%]**, maximum absolute round spread 7.650%. The raw on/off
interval [+6.933%, +15.001%] does not clear that A/A upper bound, even if
this short screen were eligible for pricing. It is not. No new speed or
p99 claim, accepted RPS cohort, retries, discarded window or pooling.

Descriptive arm medians (three windows each), **off-A / on / off-B**:

| Diagnostic | off-A | on | off-B |
|---|---:|---:|---:|
| Allocated objects / completion | 2680.22 | 2301.71 | 2679.62 |
| Collections / 1,000 completions | 14.423 | 17.345 | 14.325 |
| Freed objects / collection | 185,233 | 132,725 | 186,554 |
| GC ms / 1,000 completions | 148.07 | 173.99 | 146.11 |
| p99, ms | 18.942 | 15.136 | 19.380 |

Retain **every** collection rate: off-A [14.469, 14.358, 14.423], on
[17.479, 17.345, 17.238], off-B **[14.325, 14.261, 22.946]**. The last off-B
window alone has a +59.098% GC-rate difference from its paired off-A. It
must not be excluded to manufacture a resolved on excess. Snapshot and
background allocations are included; the in-load metrics observer adds
15–28 HTTP requests per window, with variable worker coverage attempts.

### Smaller capacity does not explain this screen

Median **sums across four workers** of eden pages; these are descriptive,
non-atomic sums, not four workers sharing one GC allocation budget:

| Phase / arm | 40 B | 80 B | 160 B | 320 B | 640 B |
|---|---:|---:|---:|---:|---:|
| Worker boot, off-A | 692 | 336 | 312 | 52 | 60 |
| Worker boot, on | 796 | 516 | 372 | 56 | 60 |
| Worker boot, off-B | 688 | 332 | 304 | 52 | 60 |
| Post-warmup, off-A | 772 | 361 | 439 | 60 | 88 |
| Post-warmup, on | 800 | 367 | 419 | 62 | 89 |
| Post-warmup, off-B | 781 | 349 | 374 | 60 | 88 |
| During load, off-A | 803 | 382 | 462 | 61 | 91 |
| During load, on | 797 | 367 | 426 | 63 | 90 |
| During load, off-B | 779 | 358 | 401 | 60 | 88 |

The on arm does **not** consistently have less capacity than both off arms
in any pool. Free slots also vary with collection phase, without a consistent
on deficit. For example the four-worker 320-byte free-slot sums after warmup
are off-A [3366, 4809, 3350], on [3147, 4480, 6129], off-B [5170, 5581, 4910].
All boot, warm, three in-load and final per-worker slot/page/counter records
are in the [JSON export](gc-heap.json), not just these sums.

**The concrete lead:** pool 3 (320 bytes) has **7 / 2 / 4** on-arm
`force_major_gc_count` increments, zero in every other pool/arm. These match
the on windows' major-count increases (13 total), versus zero majors off.
Several on snapshots explicitly show `major_by:nofree`; every sampled
`gc_by` is `newobj`. This is not a per-event proof of the historical cohort's
cause. In the pinned Ruby
[`gc_sweep_finish_heap`](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/gc/default/default.c#L3789-L3828),
that pool counter increments when swept slots miss the pool's minimum and
growth cannot cover the shortfall after the early post-major cycles.
Overall objects/request cannot express that pool/phase-specific constraint.
Ruby's
[`GC.config` implementation](https://github.com/ruby/ruby/blob/229531a6cfbf07e3caef30dbac24a2a3f3fed482/gc/default/default.c#L7768-L7790)
only offers `rgengc_allow_full_mark`, not arbitrary heap sizing; disabling
major GC would not be a justified fix. No heap policy was changed.

### Bounded 320-byte allocation-site diagnosis

Declaration
[`bd4c326`](https://github.com/thomasklemm/lowrail/commit/bd4c326), followed
by the standalone untimed workers described above. All three on admissions
are active, counters off, no activation refusal. Use **actual slot size**:
a Hash with a 992-byte `memsize` can occupy a 160-byte slot, so filtering on
`memsize == 320` is not an equivalent census.

| 320-byte allocation site | off-A / req | on / req | off-B / req |
|---|---:|---:|---:|
| `output_safety.rb:71`, SafeBuffer initialize | 11 | 10 | 11 |
| `tag_helper.rb:484`, stock tag String | 5 | 0 | 5 |
| `render_units.rb:205`, lowered token String | 0 | 4 | 0 |
| `tag_helper.rb:232`, content-tag Strings | 4 | 4 | 4 |
| `persistence.rb:313`, AR object allocate | 3 | 3 | 3 |
| Seven other sites (one each; full export) | 7 | 7 | 7 |
| **Enumerable total** | **30** | **28** | **30** |
| **Pool allocation-counter total** | **32** | **30** | **32** |

The equal **two unenumerated allocations/request** stay explicit. The
320-byte pool's request allocation total goes **down**, not up. There are
no new large embedded Array/Hash sites in these request samples. The on-only
token site produces four **embedded Strings of 144 bytes**, each occupying
a 320-byte slot, not four additional allocations: it replaces the stock
tag path's four corresponding Strings. The fifth stock tag and one
SafeBuffer allocation disappear with the lowered form path.

Starting a token output in a small mutable String and appending into an
external buffer could plausibly move those four outputs out of the 320-byte
pool. It would trade embedding for external allocation/copy costs, and the
stock counterpart already occupies that same pool. This census supplies
**no evidence that such a change fixes on-only GC pressure**, so it is not
a justified lowering fix and no variant is implemented or priced.

**Retention:** after warmup and three full GCs, live 320-byte slots are
**966 / 1026 / 966**, while traced/enumerated retained boot+warm objects are
**881 / 879 / 881**. Traced retained types are String 806/804/806, Array
32/32/32, other object 43/43/43. No on-only traced source site gains more
than two objects. The twenty-request sample has **zero traced 320-byte
survivors** after full GC. This rejects a sampled 320-byte request-buffer
leak, not all retention.

The **extra 60 live slots on remain unattributed**: tracing began in the
worker script after `RUBYOPT` had already loaded `lowrail/setup`, and
`ObjectSpace.each_object` also omits VM-internal objects. The census cannot
distinguish those coverage gaps or prove which objects pin which pages.
Do not turn that residual into a claimed manifest leak or proven cause.
This bounded lead does not name a concrete fix: **the bet is killed**.

### Receipt integrity, failures and reproduction

All 12 servers (three coverage + nine measured) pass both seeds' literal
cold status/body/all-Rack-header checks; all nine measured servers pass warm
checks. All **78,701 load + 65,165 warmup completions** are HTTP 200, zero
transport errors. **216 worker snapshots**, stable four-worker PID sets,
all modes/refusals/source pins pass. No app source/config patch. The orb
exposes 16 logical CPUs (different from the earlier orb); the declared
server 0–3 / client 4–7 / capture 7 affinities remain unchanged.

All **78,701** oha completions join to native request and wire records;
zero native/kernel drops, open GC intervals or sequence gaps. The parser
also retains **192 unmatched metrics-only wire requests**, exactly the
in-load snapshot attempts. They are not client errors, shifted ordinals or
unmatched oha requests. Capture cost and native CPU accounting remain in
the export, not a no-observer overhead ablation. All managed services stopped.

An independent Python audit recomputes every raw oha count/rate/percentile,
receipt hash, three-round paired ratio/mean and bootstrap extrema, every
worker/pool delta, snapshot coverage/order, and native/oha counts. Full
private result SHA256:
`e7880916e0359ab4e1974a2660234c56422fa04ded549ddf2d309b2746a186d9`.
The JSON export retains full nonsecret snapshots, source/receipt hashes,
site metadata, residuals and the unmodified short-screen summaries.

Two setup/reporting failures are retained: the first artifact build lacked
the production secret setting and failed before load (corrected by the
existing dummy-secret option); the first site worker completed its off-arm
census but failed reporting an absent disabled `Lowrail::Stats` constant.
No comparative result was written. Its log hash is in the export. The
reporter now uses the existing guarded check; a fresh bounded diagnostic
completes all three arms. No HTTP-load screen/cohort was rerun or replaced.

```sh
# Existing external config includes puma_setup=bench/experiments/gc_heap.rb,
# heap_observer=true and the same GC/wire observers in every arm.
mise exec ruby@4.0.7 -- ruby script/rps --config PRIVATE_CONFIG.json --output NEW_SCREEN
python3 bench/rps_attribution.py NEW_SCREEN > PRIVATE_ATTRIBUTION.json
mise exec ruby@4.0.7 -- ruby bench/experiments/gc_heap_sites.rb PRIVATE_CONFIG.json NEW_SITES
```

Harness checks: **4 runs / 76 assertions**, parser regression passes, Ruby
syntax checks pass. No runtime change, common-heap control, performance
cohort, README/main update or upstream issue/PR/comment. Fewer objects and
more collections remain compatible with pool-specific GC constraints;
the historical excess/p99 and the unattributed 60 slots are **not solved**.
