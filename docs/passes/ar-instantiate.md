# Active Record instantiation variants

Opt in with `lowrail build APP --ar-instantiate`. This is a narrow
homogeneous-result loader variant, not attribute-reader specialization and
not a replacement for Active Record objects. It is not enabled by default.

**Result:** a real load-only win on the pinned 8.2 alpha (20/200 rows
−38.9%/−37.0%, four fewer allocations per row), but **no demonstrated
request-level speedup**. Rails 8.1 already caches the builder and usually
gets slower with this pass. Keep it opt-in, not a general recommendation.

## What is specialized

The measured path is `_load_from_sql` → `instantiate_instance_of` →
`attributes_builder.build_from_database` → `allocate.init_with_attributes`.
The latter still calls the real `init_internals`, find callbacks and initialize
callbacks, in Rails' order. The pass emits a normal `_load_from_sql` `def` on
each model's singleton class, with its own ISeq and `super` fallback.

For homogeneous results it removes `instantiate_instance_of` dispatch and
reuses the model's attributes builder. Rails 8.1 already memoizes this builder;
the pinned 8.2 alpha reconstructs it on every lookup, including allocating a
primary-key-defaults subset. This difference matters more than empty callback
dispatch. No callback or initializer is inlined, no values are eagerly cast,
and the per-result `column_types.reject` remains live: it depends on the
actual SQL projection, not merely the model's schema.

The original instrumentation boundary and `record_count` / `class_name`
payload remain, including the frozen event-name literal from Rails' compiler
contract. Empty results return without instrumentation. STI-column
results call the live `instantiate`, retaining discrimination and subclass
behavior. Homogeneous rows call live `allocate.init_with_attributes`; yield,
callback, custom initializer and custom internals ordering is unchanged.
Relation freezing, readonly, strict loading and inverse assignment remain
with their existing callers.

## Guards and refusal boundaries

- Build certifies the native querying, persistence and model-schema bodies
  against audited full-file hashes for Rails 8.1.3, 8.1.4 and the corpus's
  alpha revision. Runtime requires the exact Rails version, source hashes
  and original method owner/location. A missing/stale/incompatible build
  installs nothing; per-model installation failures are declined silently.
- Custom `_load_from_sql`, `instantiate_instance_of` or `attributes_builder`
  implementations are refused. Alpha additionally certifies the schema-context
  getter/builder closure and builder constructor/accessors, refuses custom
  metadata getters, and records method facts for that closure. Its schema
  context body has an audited hash too.
- Method facts use `Lowrail::Guard`'s definition/include/prepend/extend
  invalidation, not per-call method snapshots. Each entry validation checks
  the underlying original method as well. Inherited singleton getters record
  their real defining singleton class, not the receiving subclass.
- The builder is obtained lazily at the original first-row point, after
  instrumentation starts and only on the homogeneous branch. Its
  `Lowrail::AR.epoch(model)` is captured there, not prematurely at boot.
  Every row checks both method state and that epoch. A mutation inside a
  notification, callback or yield sends subsequent rows to live Rails without
  replaying the first row. A changed epoch conservatively disables that
  recipe until rebuild/restart; it does not silently accept a new schema.
- A new subclass cannot reuse its parent's entry. Existing subclasses have
  separate entries. Overrides of initialization/internals are dispatched
  normally. Non-main Ractors go directly to `super`, before accessing the
  main Ractor's unshareable plan; alpha schema attributes are Ractor-local.
- Current scope, connected role/shard, query cache and relation strict loading
  are not cached. SQL execution stays outside the replacement. The audited
  alpha model schema context is not selected afresh by role/shard/scoping;
  normal schema/connection changes invalidate through `Lowrail::AR`.

The general guard holes documented in `guard.rb` still apply (e.g. hooks
overridden without `super`, C redefinitions and refinements). Direct mutation
of private schema/type/builder storage is not an invalidation API. This pass
does not claim that object identity/allocation tracing or ISeq introspection
is unchanged; removing repeated builder allocations is the optimization.

## Reproduction protocol

Use the `script/corpus` pins and their normal database/assets/auth setup
(`bench/campfire_setup.rb`, `bench/inertia_setup.rb`). Test builds use the
default test environment; benchmark builds must use `--env production`.
The measurements use Ruby 4.0.7 with YJIT, local databases, Redis for Campfire
and the Starter Kit's SSR process. No build/test jobs run alongside timing.

```sh
target/debug/lowrail build .corpus/campfire --ar-instantiate
PARALLEL_WORKERS=1 LOWRAIL_SQL_TRACE=full target/debug/lowrail verify \
  .corpus/campfire -- bin/rails test --seed 41231

RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 target/debug/lowrail build .corpus/campfire \
  --env production --ar-instantiate
BENCH_SECONDS=0.15 ruby bench/ar_instantiate_runs.rb \
  .corpus/campfire /tmp/ar-campfire breakdown
BENCH_SECONDS=0.3 ruby bench/ar_instantiate_runs.rb \
  .corpus/campfire /tmp/ar-campfire micro
BENCH_SECONDS=3 BENCH_PROFILES=1 ruby bench/ar_instantiate_runs.rb \
  .corpus/campfire /tmp/ar-campfire requests
```

The driver enables only `active_record/instantiate` units, alternates order
off/on then on/off, and starts a fresh `ruby --yjit` for each mode in each
of five pairs. Timed runs have counters/reporters disabled. Requests use the
existing `bench/requests.rb`, its 200-request warmup and authenticated HTML
headers; Campfire has `CAMPFIRE_RESPONSE_CACHE_MB=0` throughout. HTTP status
must be 2xx. Separate counted probes establish actual request hits/fallbacks.
These are end-to-end Lowrail-on/off measurements, not a subtraction of the
runtime's general cost: disabled view/route units can still incur their
fallback guards. The isolated loader microbenchmarks have no view/route work.

Microbenchmarks repeat real SQL rows to construct exact 1/20/200-row results;
they do not time database execution. They measure loading alone and loading
plus reading all attributes, so lazy-casting cost is visible. Indexed-result
construction, type filtering and instrumentation are measured separately per
result. Builder allocation, initialization, internals and callbacks are
non-additive component probes, not a claim their isolated times sum to total
loading time. The row-wise guard and epoch lookup are measured separately.
The breakdown also collects CPU StackProf at 100 µs on 200-row load+read;
request profiles use wall StackProf at 100 µs. Micro/request tables report
median and min–max of five fresh-process means; components use five internal
rounds per process. These are not request percentiles or confidence intervals.

## Measurements (2026-10-20)

These final runs include the frozen-notification-literal fix in
[`d666ea3`](https://github.com/thomasklemm/lowrail/commit/d666ea3).

### Per-row and per-result budget

Times below are µs, including the measurement loop. Native Rails is measured
except for the two guard probes, which require the installed variant. Model
order is Article / Message / Organization / Proposal / User. All five have
empty find and initialize callback chains in these production boots.

| Probe | real-blog | Campfire | PingCRM | Redprints | Starter |
|---|---:|---:|---:|---:|---:|
| `attributes_builder` lookup / row | 0.122 | 1.106 | 0.108 | 0.104 | 0.113 |
| `allocate` / row | 0.338 | 0.261 | 0.282 | 0.243 | 0.236 |
| `build_from_database` / row | 0.480 | 0.601 | 0.423 | 0.383 | 0.368 |
| `allocate.init_with_attributes` / row, inclusive | 0.636 | 0.664 | 0.642 | 0.588 | 0.599 |
| `init_internals` / row | 0.400 | 0.417 | 0.412 | 0.388 | 0.391 |
| Both empty callback chains / row | 0.120 | 0.114 | 0.125 | 0.111 | 0.117 |
| `instantiate_instance_of` / row, inclusive | 0.921 | 2.348 | 0.897 | 0.913 | 0.777 |
| Instrumentation / result | 0.847 | 3.339 | 0.809 | 0.770 | 0.772 |
| Fresh result + indexed rows, 1 row | 1.071 | 1.299 | 2.352 | 2.450 | 1.233 |
| Fresh result + indexed rows, 20 rows | 2.506 | 2.683 | 4.089 | 4.420 | 2.766 |
| Fresh result + indexed rows, 200 rows | 15.795 | 17.153 | 18.590 | 18.061 | 14.452 |
| `column_types` + reject / result, 1 row | 1.352 | 2.293 | 2.517 | 2.644 | 1.352 |
| `column_types` + reject / result, 20 rows | 1.188 | 2.289 | 2.467 | 2.537 | 1.326 |
| `column_types` + reject / result, 200 rows | 1.222 | 2.225 | 2.884 | 2.537 | 1.364 |
| Complete row guard, including epoch | 0.153 | 0.151 | 0.147 | 0.157 | 0.139 |
| Epoch lookup alone | 0.129 | 0.139 | 0.131 | 0.134 | 0.130 |

These probes overlap; do not add them. In particular the epoch cost is
already inside the row guard, and initialization already includes internals
and callbacks. The harness matters at sub-microsecond scale. Skipping empty
callbacks would save little while introducing more assumptions. The clear
candidate was alpha's builder lookup: **four allocations and 1.106 µs/row**,
versus zero allocations and about 0.1 µs on 8.1. Type filtering costs roughly
1–3 µs **per result**, not per row, and remains projection-dependent.

### Full loader, with lazy casting separated

Each time is **median [min–max] µs per result**, over five alternating
fresh-process pairs. Allocations are objects per result, off / on. `read`
means calling `attributes` on every loaded record; it is deliberately more
casting than many requests need. The load-only result has warmed indexed
rows; fresh-result/index construction is listed separately above.

| Model/app | Rows and work | Off µs | On µs | Median change | Allocations off/on |
|---|---|---:|---:|---:|---:|
| Article / blog | 1 load | 3.11 [3.03–4.91] | 3.53 [3.41–4.58] | +13.5% | 10 / 10 |
| | 20 load | 16.90 [12.80–25.30] | 20.02 [18.21–25.56] | +18.5% | 105 / 105 |
| | 200 load | 147.09 [114.87–207.09] | 187.07 [139.51–227.72] | +27.2% | 1,005 / 1,005 |
| | 1 load + read | 11.25 [10.97–18.50] | 12.64 [11.48–15.75] | +12.3% | 35 / 35 |
| | 20 load + read | 172.38 [168.88–194.63] | 181.75 [170.88–218.99] | +5.4% | 605 / 605 |
| | 200 load + read | 1,672.05 [1,655.47–2,261.13] | 1,776.19 [1,763.76–1,963.75] | +6.2% | 6,005 / 6,005 |
| Message / Campfire | 1 load | 10.65 [10.17–12.43] | 8.89 [8.40–9.26] | −16.6% | 23 / 19 |
| | 20 load | 60.81 [60.34–65.93] | 37.18 [36.66–37.45] | −38.9% | 213 / 133 |
| | 200 load | 476.95 [462.34–488.31] | 300.33 [292.60–335.99] | −37.0% | 2,013 / 1,213 |
| | 1 load + read | 20.29 [19.62–25.32] | 18.99 [18.88–21.48] | −6.4% | 52 / 48 |
| | 20 load + read | 250.27 [223.66–301.12] | 213.11 [207.26–225.88] | −14.8% | 793 / 713 |
| | 200 load + read | 2,071.57 [2,007.71–2,262.16] | 2,018.45 [1,978.79–2,371.98] | −2.6% | 7,813 / 7,013 |
| Organization / PingCRM | 1 load | 4.95 [4.57–5.53] | 5.10 [4.87–5.21] | +3.0% | 10 / 10 |
| | 20 load | 18.70 [14.49–20.35] | 24.94 [23.02–45.92] | +33.4% | 105 / 105 |
| | 200 load | 120.41 [108.46–184.33] | 205.27 [175.55–225.06] | +70.5% | 1,005 / 1,005 |
| | 1 load + read | 20.69 [20.34–25.04] | 21.40 [20.17–21.76] | +3.5% | 52 / 52 |
| | 20 load + read | 332.74 [306.03–362.94] | 328.85 [304.09–332.80] | −1.2% | 949 / 949 |
| | 200 load + read | 3,181.09 [2,973.11–3,298.18] | 3,284.52 [3,056.97–5,267.60] | +3.3% | 9,445 / 9,445 |
| Proposal / Redprints | 1 load | 6.18 [5.67–6.83] | 5.81 [5.36–6.24] | −6.0% | 10 / 10 |
| | 20 load | 26.28 [23.82–29.37] | 26.55 [22.65–42.59] | +1.0% | 105 / 105 |
| | 200 load | 181.72 [149.50–237.57] | 211.45 [197.68–238.57] | +16.4% | 1,005 / 1,005 |
| | 1 load + read | 29.45 [24.80–34.31] | 25.36 [21.87–25.97] | −13.9% | 56 / 56 |
| | 20 load + read | 397.65 [384.85–595.63] | 393.33 [384.72–449.96] | −1.1% | 1,025 / 1,025 |
| | 200 load + read | 4,423.13 [3,829.05–5,138.09] | 3,970.35 [3,573.10–4,156.11] | −10.2% | 10,205 / 10,205 |
| User / Starter | 1 load | 4.19 [3.73–4.93] | 4.73 [3.98–5.24] | +13.0% | 10 / 10 |
| | 20 load | 20.07 [16.03–22.02] | 23.65 [20.78–34.23] | +17.8% | 105 / 105 |
| | 200 load | 160.13 [147.70–205.49] | 227.80 [169.72–254.72] | +42.3% | 1,005 / 1,005 |
| | 1 load + read | 15.45 [15.20–20.72] | 16.06 [15.51–18.43] | +4.0% | 38 / 38 |
| | 20 load + read | 242.06 [233.58–244.38] | 251.16 [240.61–313.43] | +3.8% | 665 / 665 |
| | 200 load + read | 2,321.59 [2,273.00–2,672.57] | 2,411.57 [2,362.87–2,736.40] | +3.9% | 6,605 / 6,605 |

Alpha's load-only ranges are separated at all three sizes. Its 200-row
load+read change, however, is **within noise**, despite 800 fewer allocations.
8.1's cached getter offers no comparable allocation saving; row guards and
dispatch outweigh it. Mixed load+read movements with overlapping ranges are
not independent wins: the pass does not change casting, and the native 8.1
load-only medians mostly get worse.

### Five interleaved request pairs per app

Authenticated HTML through `bench/requests.rb`; milliseconds per request,
**median [min–max]**, with allocations off / on. Campfire's response cache
is disabled. Starter includes its live SSR process.

| App / route | Off ms | On ms | Median change | Allocations off/on |
|---|---:|---:|---:|---:|
| real-blog / articles | 2.061 [1.992–2.126] | 2.586 [2.291–3.069] | +25.5% | 2,378 / 2,378 |
| Campfire / room | 22.822 [21.216–23.500] | 23.466 [19.326–27.302] | +2.8% | 22,675 / 22,539 |
| PingCRM / organizations | 4.445 [3.911–4.893] | 4.633 [3.979–4.975] | +4.2% | 2,946 / 2,946 |
| Redprints / proposals | 2.815 [2.609–3.327] | 2.907 [2.490–3.403] | +3.3% | 3,418 / 3,418 |
| Starter / dashboard | 6.847 [5.503–8.508] | 7.645 [5.900–7.728] | +11.7% | 1,975 / 1,978 |

**No request win.** The blog slowdown is repeatable: every pair is slower
with Lowrail and the aggregate ranges are separated. The other four have
overlapping ranges and mixed paired directions; those changes are within
the observed noise/inconclusive, not evidence of acceleration. Campfire's
136 fewer objects/request match four objects × 34 fast-path rows, but save
only a few tens of microseconds of builder work in a roughly 23 ms request.
The end-to-end slowdown cannot all be assigned to this loader: these runs
also include general Lowrail delivery and disabled-unit fallback guards.

### StackProf budget, not a speed claim

Fresh request profiles show this broad type/attribute/instantiation boundary
(inclusive, including generated `lowrail:ar_instantiate:*` frames):

| App | Off sample share | On sample share |
|---|---:|---:|
| real-blog | 3.89% | 3.97% |
| Campfire | 18.46% | 17.53% |
| PingCRM | 4.81% | 4.87% |
| Redprints | 11.06% | 10.75% |
| Starter | 2.23% | 2.53% |

The 200-row load+read CPU profiles narrow the candidate further:

| Model | `_load_from_sql` inclusive, off/on | Builder lookup inclusive, off/on |
|---|---:|---:|
| Article | 7.13% / 9.29% | 0.08% / 0.00% |
| Message | 14.08% / 11.07% | 7.60% / 0.00% |
| Organization | 3.84% / 4.56% | 0.08% / 0.00% |
| Proposal | 3.76% / 5.20% | 0.00% / 0.00% |
| User | 5.68% / 7.29% | 0.16% / 0.00% |

Alpha's builder hotspot disappears, but most work in a load+read operation
is elsewhere. Initialization/internals/callback boundaries are nested, not
additive opportunities to remove real work. The five-second CPU profiles
contain only 1,247–1,250 samples despite a requested 100 µs interval; their
percentages are coarse. Request wall profiles contain 37,421–69,176 samples
with 1,424–3,315 missed samples; percentages use reported total samples, not
only recovered stacks. Profiling runs occur after the timed request loop,
and their inclusive shares are not performance deltas or removable budgets.

**Decision:** retain only guarded builder reuse and homogeneous dispatch as
an opt-in experiment. Do not inline callbacks/initializers, eagerly cast
attributes, cache a projection-dependent type reject under schema alone,
or revive the already-negative attribute-reader specialization. There is
still no general request-level speedup from this pass.

## Correctness gates (2026-10-20)

These are the new pass's counters, not the combined route/view counters.
All builds include `--ar-instantiate`. SQL comparisons gate a single process
(`PARALLEL_WORKERS=1`), with full traces retained for diagnosis.

| App | Outcomes off/on | Ordered same-thread queries | Instantiation hits | Fallbacks |
|---|---:|---:|---:|---:|
| real-blog, Rails 8.1.4 | 21 identical, all pass | 125 identical | 41 | 0 |
| Campfire, pinned Rails 8.2 alpha | 634 identical, 632 pass / 2 existing libvips skips | 15,108 identical | 2,651 | 3,129, all explained below |
| PingCRM, Rails 8.1.4, including browser tests | 26 identical, all pass | 812 identical | 217 | 0 |
| Redprints CFP, Rails 8.1.3, non-system | 50 identical, all pass | 692 identical | 227 | 0 |
| Redprints CFP, browser | 12 identical, all pass | 260 identical | 147 | 0 |
| React Starter Kit, Rails 8.1.4, including browser tests | 36 identical, all pass | 264 identical | 80 | 0 |

PingCRM has 9 tests with advisory other-thread trace differences; those
concurrent query sequences are not claimed identical. Campfire has 1 such
advisory. No final gate needed an unstable-SQL exclusion or extra off-run
control: all same-thread traces matched directly.

The full gem suite passes after syncing concurrent main: **77 tests,
1,418 assertions, 0 failures/errors,
3 optional skips**. Rust: **26 unit + 3 integration tests pass**.
`gem/test/preload_plans_test.rb` passes **3 tests / 76 assertions**, including
the inherited-singleton-getter owner regression. The independent
`build --preload-plans` real-blog control also verifies 21 outcomes and
125 queries identical, with **1 completed preload hit**, zero fallbacks
(58 combined hits). No preload eligibility was silently lost.

The real SQLite regression exercises asymmetric rows with and without the
pass, unit-disabled and stale-source controls. It checks late initialize
callbacks, a default added inside the first yield, schema-column addition
and reset, a dispatch override between rows, custom initializer/internals,
a newly introduced subclass, an STI subclass row, readonly/strict loading,
inverses, frozen relation records, block order, lazy casts, projection types
and notification payloads. The same scenario was additionally executed
against the actual alpha bundle: identical observable output, **14 real
hits**, and custom metadata getters declined. Removing the per-row guard in
a temporary mutation control made the second row miss its newly added
attribute: that check is necessary, not speculative defensive code.

### Every Campfire fallback

The seed-41231 diagnostic run records the exact branch and invalidating
epoch event, not merely a guessed cause:

- **958 STI rows:** Room 851, Rooms::Closed 72, Rooms::Direct 13,
  Rooms::Open 22. The discriminator path intentionally stays in Rails.
- **2,171 calls after epoch invalidation:** User 1,079; Account 381;
  Session 183; Message 166; ActionText::RichText 96; Boost 77;
  Membership 68; ActiveStorage::Blob 45; ActiveStorage::Attachment 36;
  Push::Subscription 19; Webhook 12; ActiveStorage::VariantRecord 8;
  Search 1. The captured stack is Rails' schema-test task →
  SQLiteDatabaseTasks#purge → #create → #establish_connection → global
  `Lowrail::AR` bump. Existing recipes correctly remain disabled after
  that connection switch. There are **no unexplained method-fact failures**.

Hits count homogeneous rows; an entry-guard fallback counts once per call,
whereas an STI fallback counts once per STI row. They are not interchangeable
denominators. Two Campfire models (Ban and EncryptedRichText) were unexercised;
the four STI models have no homogeneous hits. Optional attachment/queue/auth
models in other apps are also not all exercised: support is claimed for the
paths actually hit, not every model emitted by build.

Separate production request probes, 200 warmup + 1 checked request each,
exercise **6 / 34 / 12 / 21 / 2 fast-path rows per request** for blog /
Campfire / PingCRM / Redprints / Starter. Campfire additionally retains
**2 Room STI rows per request**; the other probes have zero pass fallbacks.
These counted runs are not included in timings.
