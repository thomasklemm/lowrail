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

Results will be appended here after the preregistered finite experiments;
the preregistration and every failed budget remain in history/evidence.
