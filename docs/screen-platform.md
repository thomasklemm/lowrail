# Bet P: reusable interpreter request screen

`script/screen APP ROUTE... --artifact DIR --output NEW_DIRECTORY` reuses
`RequestPairs.heap_instructions`, `HeapWindows`, the pinned
`script/bench-valgrind` tool, and the existing native screen's Rack/fixture
adapters and exact-response checks. It is not a new counter or estimator.
There is no wall-time significance rule and no automatic retry.

## Contract and scope

- Two independent off processes and one on process per round; six rounds,
  seed 41231, seeded arm shuffle, serial workers, alternating total/no-GC
  phase order, warmup50, N=0/50. Subtract each arm's own empty window.
- Per-route allocated objects/request, total interpreter Ir and GC-excluded
  interpreter Ir, with medians and 5,000 whole-paired-round bootstrap nominal
  95% intervals. Never bootstrap individual requests as independent boots.
- Both per-route total/no-GC A/A intervals must lie wholly within ±0.1%;
  zero containment is not required. The aggregate control, all five heap
  capacities, exact pages, brk512, observed interpreter and unchanged-source
  gates remain required. Default historical `RequestPairs` callers retain
  their original zero-containing rule.
- Exact status, complete body bytes and complete headers at seeds 0 and 1,
  before **and** after windows. Existing pinned entropy companions control
  only their named nondeterministic sites; no response normalization.
  Generic apps without a companion use literal raw responses and may reject
  (for example, differing `X-Runtime` or cookies), never silently pass.
- Per-window cache event counts with hashed keys, FileStore file-byte SHA-256
  snapshots before/after, loaded-feature additions, minor/major collections,
  and connection-pool reap/flush calls. Background comparison checks all
  three arms. Changes, regeneration, loads, maintenance, mismatched event/GC
  mixes, or unknown cache-state adapters reject, rather than disappear from
  the estimate. NullStore has no stored state. Other stores explicitly report
  byte-state unavailable; their numbers are diagnostic, not accepted.
- Counted dump call signatures expose Marshal dump, deflate, binwrite,
  rename and require/load work. They are explanatory, never subtracted.
  GC counts/endpoints remain available even in the GC-excluded execution.
- Cache/reaper event instrumentation is charged identically to all arms;
  filesystem/feature/coverage snapshots are outside endpoints. These are
  instrumented synchronous warm-request prices, not native latency, whole-app
  admission, or a census of every possible application background thread.

JSON output includes prospective `protocol.json` with input/toolchain source
pins, raw `samples.json`, shared `summary.json`, and `result.json` with each
gate and every worker/window. Existing output refuses before spawning.
Private logs/configs can contain app data: do not publish them unreviewed.
`--budget` runs only three tool=none workers and records exactness, background
state, heap endpoints and fast-path counters in `budget.json`, **not Ir**.
This is the inexpensive place to diagnose fixture/observer/control failures
before preregistering a finite counted cohort. `--counter native` retains the
earlier diagnostic native screen, not this instruction acceptance rule.

## Time and background-state controls: no app/config patches

`--reset-cache` explicitly clears the disposable app's configured cache before
warmup. Use it only with a dedicated disposable cache, never a shared Redis
or production cache. `--epoch 1767312000` optionally fixes `Time.now` **before
boot**, identically for off-A/off-B/on, throughout that worker. Calls still
create fresh Time objects and preserve timezone arguments. Monotonic clocks,
Rack runtime timing and random generation in measured work remain real.
This is a fixed-instant workload; it makes no claim about advancing-time
behavior. The independent exactness companion uses the same epoch.

For Lobsters, clear then warm the unchanged FileStore at that fixed instant.
Its TTL still exists, but cannot expire during any window. Do not remove
expiry checks, substitute cache results, reuse mutable deserialized graphs,
or modify cache policy. Endpoint byte hashes and cache-hit/generation events
prove the actual cache state and hit mix seen by both controls and on; equal
response digests alone would not prove this. A real-FileStore regression
waits beyond a short TTL and checks both remaining TTL and fresh mutable
values under the harness clock.

Preliminary tool=none Lobsters work exposed one off-B window containing
`reap` plus `flush` while the other arms had neither. For this synchronous
read-only protocol the harness holds each already-created pool's existing
Rails `reaper_lock` across heap preparation and request windows. Threads stay
alive; no pool config changes and no killed reapers. Maintenance is deferred
outside the sequence, identically in all arms, and the control/pool count is
recorded in every window. This is **not** a price including asynchronous
pool maintenance. New pools or synchronous maintenance are not hidden: their
reap/flush calls are still observed and reject a contaminated window.
Workloads that require cross-thread pool maintenance/reload are outside this
screen's read-only scope.

Lobsters is only the existing ruby-bench
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716)
measured workload, with the already-published Lowrail dependency overlay.
No authored code, documentation, fixture, generated plan or patch is written
into its tree. Only unchanged-app runtime cache/log/db output is allowed
there, disposable and never committed or published. All harness code, copy
plan compilation and reports live in Lowrail. No upstream proposal/activity.

## Preregistration (before any Bet P counted windows)

This commit freezes the following finite experiments. Tool=none budgets are
not counted cohorts. **No counted retries or exclusions**, no tolerance
changes and no selecting routes/rounds after seeing counts.

1. **Blog calibration first.** One six-round off/off/on cohort on
   real-blog-r4 `GET /articles/1`, Ruby 4.0.7 / Rails 8.1.4, interpreter,
   public sealed artifact with exactly form/token/collection units and no
   source/template delivery. Same `BlogShowGetOnly` fixture as the accepted
   [`b059fc9` price](passes/production-aa01-reprice.md): three articles, three
   comments, fixed timestamps, four restored databases and no queued jobs.
   Use the existing pinned blog entropy companion and a disposable fixed
   secret; no global fixed epoch is needed for this uncached route. Require
   the accepted total −15.022961% reference to fall within the new nominal
   95% effect interval, in addition to all screen gates. Report discrepancies,
   not an automatic retune/retry. Native budget coverage must be 50/200/50
   hits per full window, no fallbacks.
2. **Then one new Lobsters M cohort**, both `GET /` and
   `GET /s/enr7ye` in each of the same 18 workers. Use byte-for-byte the
   copy-plan prototype and fixture setup from
   [`42d3e5a`](https://github.com/thomasklemm/lowrail/commit/42d3e5ade83922afc1ed39c632cc3c8ecee0dcd0),
   empty public artifact, shipped DB SHA-256
   `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`,
   existing `lobsters-rps` dependency overlay and entropy policy, cache clear,
   epoch 1767312000 and reaper-lock control above. Require both A/A intervals
   wholly inside ±0.1% **separately for each route**, along with every other
   screen gate. Budget must show two compiled plans, 50 hits per full window,
   zero capture refusals, identical cache bytes and hit/event/GC mixes.

**The Lobsters cohort is a new protocol after a diagnosed control artifact,
not a retry of the old protocol.** The
[`32933cd` cohort](https://github.com/thomasklemm/lowrail/commit/32933cd42ce87b0a24ed321b9f50757ccadae7ef)
stays rejected, including its diagnostic −5.20% front-page Ir. Its story
control contained extra Marshal dump/deflate/write work, consistent with its
live 60-second TTL. The new protocol prevents expiry and records byte-level
state rather than retrospectively excluding those windows. The new reaper
budget diagnosis likewise remains retained, not passed off as counted data.
Passing this screen would price a bench-only copy-plan specimen, **not**
certify model mutation, loader/admission or production-cache support.

## Running it

```sh
script/bench-valgrind /tmp/lowrail-vg # once; retain its provenance JSON
export PATH="/tmp/lowrail-vg/bin:$PATH" CPATH=/tmp/lowrail-vg/include
mise exec ruby@4.0.7 -- ruby script/screen --help
# Generic route; must already have a matching production interpreter artifact:
mise exec ruby@4.0.7 -- ruby script/screen .corpus/APP /path \
  --artifact .corpus/APP/.lowrail --output /tmp/NEW-budget --budget
mise exec ruby@4.0.7 -- ruby script/screen .corpus/APP /path \
  --artifact .corpus/APP/.lowrail --output /tmp/NEW-counted
```

`--config JSON` accepts the existing native harness's workload-specific
`workload`, `seed`, `gemfile`, `exploration_setup`, `exploration_only`,
`headers`, `entropy_policy`, plus `storage_seed`, `reset_cache` and `epoch`.
Paths in JSON are absolute; command-line options override JSON. Keep the
database seed outside the disposable app's `storage`; `storage_seed` restores
that directory before each boot. Authenticated corpus routes use their
existing scenario adapters, not app edits. The command always requires an
explicit new output directory; the frozen experiments above use warmup50
and requests50 regardless of other workloads' budgets.

## First calibration: REJECTED, retained (2026-10-22)

The first six-round cohort at
[`2b41f39`](https://github.com/thomasklemm/lowrail/commit/2b41f395da6885f1760c9fd6a6e3df5dfa675b9f)
completed all 18 workers / 72 windows in 372.86 seconds. Exact responses,
source pins, five heaps/exact pages, brk and interpreter gates pass. Total
A/A is [−0.029572,+0.032718]%, no-GC [−0.021656,+0.034918]%. No cache
events, loads, reaper work or collections occurred in any window.

Nevertheless it **fails calibration**: total −14.958363%
[−15.000937,−14.916683]% does not include the −15.022961% reference. It also
**fails background certification** because SolidCache had no raw-state
adapter. The earlier budgets predated the final fail-closed unavailable-state
predicate; their apparent background pass was insufficient. No old verdict
is rescored or silently replaced. No Lobsters Ir was counted.

### Untimed attribution and correction

The entropy companion captured backtraces even when its request-thread
context was nil. One raw-request ObjectSpace census attributes **119 objects**
to two wrapper lines: 96 random-site backtrace locations, eight backtrace
objects and eight arrays, two runtime-clock backtrace locations/objects/arrays,
and one native random-result String. Early nil-context delegation removes
**118 backtrace/array objects**. Ruby argument forwarding then avoids the
eight splat-argument arrays allocated at callers; normal argument/error
semantics and named seeded controls remain intact.

The final raw census sees only the native random-result String, not an
avoidable wrapper argument array. Uninstrumented/old/final companion native
allocation probes with the same fixed request ID give approximately
**2241.40 / 2367.07 / 2241.24 objects/request** over 200 requests. These are
untimed attribution probes, not a second Ir price. The final wrapper adds
no observed per-request objects above raw; its context checks and method
dispatch still cost instructions, identically in all arms. Earlier nil-only
intermediate probes retained eight extra arrays and are retained too.
Thus the initial net ~96-object excess versus the historical cohort was
not the full wrapper cost: other common request/boot/input differences also
affect cross-cohort absolute object counts. Do not label that unexplained
net residual as a particular allocation site.

SolidCache snapshots now select raw serialized/encrypted table rows in each
configured cache shard, outside endpoints, with query caching disabled and
no model deserialization or cache-read side effects. Loaded constants only;
unknown stores still refuse. A real-app scratch check verifies unchanged
repeated snapshots/read values and detection of a same-size value replacement.
The corrected three-arm budget reports identical empty cache rows, exact
seeded responses, no background work and the expected 50/200/50 hits in each
full window. The corrected Lobsters budget also passes with unchanged cache
bytes and 50 copy-plan hits per full window.

## Corrected calibration preregistration (before further counting)

The coordinator explicitly authorized **one prospective corrected blog
calibration**, with the first kept REJECTED, absolute saved work primary and
percentage change secondary. This commit freezes that replacement protocol.
There are **no further counted calibration retries**. If it fails any gate,
stop and report; **do not run M**. No old cohort is pooled, filtered or used
to adjust an estimate. This authorization does not authorize a second M run.

Keep every other experiment setting and gate above unchanged: six serial
off/off/on rounds, seed 41231, warmup50, N0/N50, original five floors,
brk512 tool, same fixture/artifact, two-seed exact responses, raw cache state,
background mix, unchanged sources and each total/no-GC A/A interval wholly
inside ±0.1%. Before counting, both corrected tool=none budgets must pass.

The public reference export supplies six independent paired samples.
Compute each round's **on minus off-A Ir/request**, then its median and
5,000-paired-round bootstrap interval using seed 41231, as for other effects.
Do not subtract aggregate medians or use instruction percentages as work.

| Metric | Reference paired median ΔIr/request | Preregistered absolute band |
|---|---:|---:|
| Total | −1,323,008.04 | [−1,336,238.1204, −1,309,777.9596] |
| No-GC | −1,323,162.07 | [−1,336,393.6907, −1,309,930.4493] |

**Primary acceptance:** each new absolute-change 95% interval must lie wholly
inside its reference median ±**1% of absolute saved Ir** band above. This
allows about 13.2k Ir/request, not 1% of the full 8.8M request; it bounds
changes to the measured saving while accommodating independent cohorts and
the retained reference uncertainty. Absolute `delta` intervals are now
included in every route/layer/metric report, with existing relative estimates
unchanged.

**Secondary acceptance:** each new relative-effect 95% interval must lie
wholly within **±0.20 percentage points** of the published reference: total
−15.022961%, no-GC −15.021453%. The broader relative band allows common
instrumentation/request-envelope work to move the denominator; it does not
relax the primary saved-work band or the ±0.1% A/A gates. Report the actual
relative intervals and whether they contain the historical point, even when
the calibration otherwise passes. No native latency inference follows.

Only after that calibration passes, run the **single previously declared
Lobsters M cohort** using this corrected harness and the byte-identical
`42d3e5a` copy plan. Its per-route ±0.1% controls and all other gates remain
unchanged. The first failed blog and all untimed probes remain retained.

## Corrected calibration: ACCEPTED (2026-10-22)

The one authorized corrected cohort at
[`e84cf55`](https://github.com/thomasklemm/lowrail/commit/e84cf55116600d676172a5531e78b6d08d28926c)
passes the prospective **absolute saved-work** criterion and secondary
percentage band. This does not reclassify the first rejected calibration.

| Blog GET /articles/1 | Total Ir | No-GC Ir |
|---|---:|---:|
| Paired on minus off-A, Ir/request | −1,321,506.99 | −1,321,185.72 |
| Absolute-change 95% interval | [−1,323,475.24, −1,320,106.79] | [−1,325,578.89, −1,318,351.35] |
| Historical absolute median inside new interval | yes | yes |
| Whole interval inside preregistered ±1% saving band | yes | yes |
| Relative change | −15.054825% | −15.049772% |
| Relative-change 95% interval | [−15.070921, −15.038712]% | [−15.098833, −15.022174]% |
| Historical relative point inside new interval | **no** | **no** |
| Whole interval inside preregistered ±0.20-point band | yes | yes |
| A/A 95% interval | [−0.023582, +0.037459]% | [−0.032358, +0.068011]% |

Off-A/off-B/on allocation medians are **2251.60 / 2250.91 / 1874.25**
objects/request; the median of paired allocation differences is −377.17
[−377.62, −377.10], not subtraction of aggregate medians. Common work and
the denominator differ from the reference; **do not claim the original
−15.022961% point was reproduced within the new relative interval**.

All screen gates pass: pre/post two-seed exact status/body/all-header hashes,
identical empty SolidCache raw-row state, no cache events/regeneration,
lazy loads, collections or reaper work, both ±0.1% controls, all five heaps
and exact pages, brk512, actual interpreter, unchanged input pins and no
Lowrail refusal. Independent reconciliation verifies 72 dump totals against
self-cost sums, 36 full-minus-empty subtractions and every paired estimate;
no overlapping worker/window envelopes. Eighteen workers / six rounds took
**370.90 seconds**, excluding tool/corpus/artifact construction. The final
three-worker tool=none blog budget took about **44 seconds**; these observed
costs are not performance promises for other apps.

This pass permits the one previously preregistered M cohort. No further blog
calibration, data pooling, round exclusion or tolerance adjustment occurred.

## Lobsters M: ACCEPTED scoped interpreter price (2026-10-22)

The single new-protocol cohort at the same `e84cf55` source completes all
18 workers / six rounds, **144 windows**, in **1515.54 seconds** (25.26
minutes). No retries, exclusions, route selection or pooling with the rejected
historical M cohort. These are two synchronous warm-request bench specimens,
not latency, whole-app support, production-cache admission or a default pass.

| Paired metric | GET / | GET /s/enr7ye |
|---|---:|---:|
| Total Ir change | **−5.183274%** | **−1.637261%** |
| Total change 95% interval | [−5.199424, −5.134288]% | [−1.665128, −1.591397]% |
| No-GC Ir change | **−5.382614%** | **−1.647801%** |
| No-GC change 95% interval | [−5.408094, −5.334706]% | [−1.665625, −1.604965]% |
| Total ΔIr/request | −3,580,097.18 | −254,325.87 |
| Total absolute-change 95% interval | [−3,590,926.70, −3,544,899.80] | [−258,678.41, −247,109.91] |
| No-GC ΔIr/request | −3,623,141.30 | −255,979.24 |
| No-GC absolute-change 95% interval | [−3,640,741.98, −3,590,091.62] | [−258,768.45, −249,237.77] |
| Total A/A 95% interval | [−0.056867, +0.004564]% | [−0.044815, +0.016905]% |
| No-GC A/A 95% interval | [−0.054387, −0.004275]% | [−0.052420, +0.005119]% |
| Allocations/request off-A / off-B / on | 13828.24 / 13828.40 / 13461.40 | 3440.56 / 3441.15 / 3366.99 |
| Paired allocation change | −366.89 [−367.31, −365.91] | −73.70 [−73.82, −73.37] |

Both routes' total/no-GC A/A intervals lie wholly within **±0.1%**. The
front-page no-GC interval does not contain zero; the prospectively declared
rule deliberately does not require that. Allocations above are measured
paired estimates, not a renewed claim of exact integer savings per request.

Every screen gate passes. Status/body/all-header digests match at both seeds
before and after windows. All **288 cache endpoints** have byte-state digest
`ca773e468c52e43176c3138f26cd33316b5427c0e4cf670e6536957e613c33d0`.
Each full window records exactly 50 cache reads/hits and 50 fetch-hit events;
empty windows have none. No regeneration, cache mutation, lazy load, reap,
flush, Marshal dump, deflate, binwrite, rename or require/load signature is
observed. All 48 round/route/mode/size comparisons are comparable. Front-page
full windows each have **two minor / zero major GCs** in every arm and mode;
story and empty windows have zero. No-GC excludes GC instructions, not the
collections themselves; these are separate executions, not a subtraction
of GC savings. One pool's existing maintenance lock is held, explicitly
deferring asynchronous reaping outside the synchronous request price.

All five heap ranges/exact pages, brk512, observed interpreter, unchanged
source/input pins and no-refusal gates pass. Independent reconciliation
checks **144 dump totals/self-cost sums, 72 subtractions and every paired
estimate**, with zero overlapping worker/window envelopes. The final
three-worker tool=none M budget took about **112 seconds**. No Lobsters
authored content, application/config patch or runtime/data publication is
included; only Lowrail's harness and sanitized numeric/hash evidence are
published. The unchanged copy-plan prototype is a branch-only specimen.

## Validation and retained evidence

`LOWRAIL_STRICT_GATES=1 mise exec ruby@4.0.7 -- ruby bench/screen_test.rb
--seed=1729` passes **3 tests / 43 assertions**; the shared counter tests
pass **17 / 312**, and the targeted entropy contracts pass **3 / 15**.
The clock regression exercises a real FileStore beyond its wall-time TTL,
independent mutable deserializations and timezone preservation. Cache
regressions distinguish a hit, regeneration, same-size byte replacement,
an unknown store and reaper contamination; A/A boundary tests exercise both
signs and either failed metric while preserving historical caller policy.

The unrelated stale-template expectation was reproduced once on a clean
`origin/main` at
[`f257ddd`](https://github.com/thomasklemm/lowrail/commit/f257ddd1d35284b1da4daad201852ab8cc2ee32e):
`LOWRAIL_STRICT_GATES=1 mise exec ruby@4.0.7 -- ruby bench/pass_test.rb
--verbose --seed=1729` reports **17 tests / 233 assertions / one failure** in
`PassBenchTest#test_stale_manifest_is_a_rejected_measurement_not_a_silent_noop`.
The ancestry-artifact refusal precedes the expected stale-build text.
The first local observation used seed 53337. This is **bench/pass_test.rb,
not the gem rake test suite**, so it does not contradict the recorded strict
193 / 6,792 gem pass. No fix is included; the coordinator owns routing it.

The shared counter suite requires the pinned tool's `bin` on `PATH` and its
`include` on `CPATH`, as in the running instructions. An unconfigured final
validation invocation failed to compile `valgrind/callgrind.h` (one failure,
two skips); setting those prerequisite paths, without source changes, gives
the 17 / 312 clean result above. This was not an app or counted-cohort retry.

The [sanitized results export](screen-platform-results.json) retains all
three counted cohorts, ten untimed budget attempts (including failures),
allocation probes, per-window background/heap/placement observations, paired
samples, dump/log hashes and independent reconciliations. The first blog
verdict remains false; corrected blog and M are true. Complete file pins
are deduplicated: a provenance `pins_ref` selects a `pin_sets` entry with
either `files`, or `base` plus `overrides` and `removed` paths. Reconstruction
was checked against every original protocol. `$REPO` replaces the workspace
root; fixed public fixture secret values and detailed entropy trace payloads
are omitted, retaining trace hashes/counts. No response/cache/database
contents or Lobsters runtime files are published. Full private raw evidence
is retained in this orb, not committed. README/results-index changes and
any application/runtime promotion belong to the owner, not this screen.
