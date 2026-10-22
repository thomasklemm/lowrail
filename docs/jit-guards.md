# Bet Y: non-creating guards

## Prospective protocol (2026-10-22)

Start from main and compare the external Fizzy DirectSite overlay at
[`936cc46`](https://github.com/thomasklemm/lowrail/commit/936cc462ffa2586a45458f6efa69d9717f965fe8)
with the same overlay using the existing native `exact_class?` primitive.
Do not remove method-body, visibility, schema, reflection, scope, connection
or mid-request checks. An existing singleton class, even an empty one, refuses
the new path. No app source/configuration edits or production admission.

Inventory and screen the unchanged main blog form/token/collection units too.
The necessary private implicit calls stay live: public sends and captured
helper bodies are not equivalent to Rails dispatch. Do not replay bet K's
rejected combined form/constant candidate as a new result.

Use Ruby 4.0.7 / Rails 8.1.4. Build official Ruby with
`--enable-yjit=stats --disable-install-doc` for diagnostic counters; use stock
`mise exec ruby@4.0.7 --` for allocations and interpreter checks. Pin
`BUNDLER_VERSION=4.0.20` before Bundler, and assert actual JIT state after
boot in every worker. Certificates match each actual Ruby build/mode.
Two-seed exact status/body/all-header comparisons and positive fast-path
hits with zero fallbacks precede measurement. Keep strict query shadows in
untimed coverage only. Use 2,000 warm requests and 500 stats requests, matching
K; retain every worker and all premeasurement failures.

**Screen gate:** singleton-send fallbacks must fall clearly from F's old-on
value to the same fixture's off value or below (historical target about
243/request). No allocation or interpreter-Ir regression. Report side exits,
all invalidation reasons, code GC, new compilation and window ratio-in-YJIT
separately; fallbacks are not exits. New compilation means diagnostic stats,
not a JIT-flat price. No ZJIT execution/speed claim from YJIT counters.

Only if exactness, counters and interpreter non-regression pass, run **one**
Fizzy `/buckets` real-Puma cohort using the existing `script/rps` harness at
`b1e239f` and the `44a33c4` / `544ad8d` protocol: 4 workers × 1 thread,
concurrency 16, 5 s warmup / 20 s load, 20 rotated off-A/on/off-B rounds.
Require A/A RPS's 95% interval to contain zero; treatment's RPS lower 95%
bound must exceed the A/A upper bound. All coverage workers must prove JIT
active, hits > 0 and fallback 0 before load. Run A/A admission first, retain
all rounds, no retries/exclusions. Record p50/p90/p99, allocations, GC and
worker state; no uniformly-faster claim when tails regress. Never push main.

## Guard inventory

| Unit / boundary | Exact facts and emitted shape | Decision |
|---|---|---|
| F `bucket_rows`, user | Actual User holder; live `persisted?`/integer ID; two effective public reader bodies. Old `singleton_methods.empty?` followed by captured `singleton_class.bind_call` and Module lookup | Replace creating lookup with native exact holder **after** live reads, then captured ordinary-class public/body checks. Keep ordinary ID/association sends visible. |
| F `Site#eligible?`, owner | Owner class, live persisted/integer ID, association/ID/persisted reader bodies and public visibility | Native exact holder before and after live reads; ordinary-class lookup only after that proof. Existing eigenclasses conservatively fall back. |
| F model and relation methods | Captured Module lookup and public visibility on model singleton class (class setup, not a record's eigenclass), model-specific relation delegates and WhereChain | Retain. No guard-created ordinary singleton class; hook-only or JIT-only invalidation cannot certify erased calls. |
| F schema/scope/reflection | Defaults, types/columns/table identity, current/global scope, role/shard, reflection identity/options/scope/keys, no query transformers | Retain live comparisons. JIT CME invalidation does not watch mutable data contents. |
| F association/connection | Actual association not loaded, no cached scope/public singleton overrides; connection/visitor identity and prepared mode; PID/database-config-qualified child rebind | Retain; singleton enumeration does not materialize an eigenclass. Fork rebinding is still bench-only. |
| Sealed admission, all three units | One natural original witness; source/binary/ISeq/visibility/holder/config/translation/route/template facts, mutex, one attempt, epoch before publication | Cold, not a per-request guard. No runtime autoload/materialization or new guard hooks. |
| Form hot entry | Main Ractor/epoch; exact Array/Proc/view/Article/Comment holders, options/block source, builder/buffer holder/context, locale and blank/unpersisted child | Existing native holder primitive creates no eigenclass. Captured ivar and block-source `bind_call` avoid app reflection overrides. Keep checks. |
| Form live helper boundary | Captured stock `BasicObject#instance_exec` invokes private `tag_builder`, `output_buffer`, `url_for`, `token_tag`; named route retains original public_send/new String | Retain. A public send changes private/method_missing semantics; a captured method body bypasses legitimate overrides. No new method/ancestry shim. |
| Token hot entry/continuation | Main Ractor/epoch, nil token, exact options/view/builder and view-context link; after generation/conversion recheck epoch and String/builder holders | Retain non-creating native checks and saved-value stock continuation. Never regenerate a token or reconvert its name. |
| Token live helper boundary | Captured instance_exec for defined?/private protection, generator/name calls, live autocomplete getter and fallback tag | Retain implicit dispatch. K's five constant-cache exits are known, but its combined capture/split candidate failed its screen; not claimed fixed here. |
| Collection hot entry/body | Main Ractor/epoch, exact renderer/view, nonnil template/no layout; lexical PartialIteration-shadow refusal at witness | Already ordinary method, constant and live iterator/Template sends. Preserve preload/locals/cache-key/render/event effects; no singleton/instance_exec rewrite needed. |

Runtime counters are window-wide, not per-guard attribution. Public Ruby APIs
cannot assign every side exit, invalidation or ratio to an individual guard.
The old/new F pair isolates its two holder-guard changes; unit ablations on
blog can locate aggregate costs but do not make counters additive.

## Completed admission screens

Two-seed literal status/body/all-header digests match across all arms on both
apps. Every coverage worker asserts actual YJIT; Fizzy old/new each complete
20 hits and 20 strict SQL/bind shadows in ten requests, zero fallback. Blog
form/token/collection/stack hit deltas are 10/40/10/(10+40+10), zero fallback.
Stats workers use the independently built `--enable-yjit=stats` Ruby 4.0.7;
stock workers use mise Ruby 4.0.7. Both use Bundler 4.0.20 before app boot.

| Fizzy, per request | off-A | old F | new guard | off-B |
|---|---:|---:|---:|---:|
| Stock objects | 9084.796 | 8507.846 | **8417.880** | 9085.070 |
| Singleton-send fallbacks | 243 | 469 | **243** | 243 |
| Side exits | 42 | 38 | 38 | 42 |
| Window ratio-in-YJIT, % | 99.763683 | 99.801331 | 99.795969 | 99.763683 |

All four stats windows have zero invalidations/code GC and two newly compiled
ISeqs. This is a clear singleton-send counter improvement, **not** a JIT-flat
price or an across-the-board improvement: ratio-in-YJIT is slightly lower
than old F. Stock objects fall by about 90 versus F and 667 versus off.

| Blog, per request | off-A | form | token | collection | stack | off-B |
|---|---:|---:|---:|---:|---:|---:|
| Stock objects | 2286.326 | 1908.106 | 2286.272 | 2286.104 | 1908.438 | 2286.610 |
| Singleton-send fallbacks | 106 | 106 | 106 | 106 | 106 | 106 |
| Side exits | 11 | 12 | 15 | 11 | 16 | 11 |
| Constant-cache exits | 0 | 1 | 4 | 0 | 5 | 0 |
| Window ratio-in-YJIT, % | 99.742789 | 99.689520 | 99.727858 | 99.752880 | 99.658967 | 99.742789 |

Every blog stats window also has zero invalidations/code GC and two new
ISeqs. No blog runtime rewrite: the necessary implicit/private-dispatch
blocks remain, with K's five CREF-sensitive constant-cache exits explicitly
retained rather than rebranding K's rejected combined candidate.

### Incremental interpreter gate: pass, one attempt

Measured clean
[`c968daa`](https://github.com/thomasklemm/lowrail/commit/c968daa6db34ee6b35362bef272862d963137011),
old-on A / new-on / old-on B. These are **not new-versus-off prices** and must
not be added to F's earlier, pre-worker-binding-fix price.

| Metric | Old A / request | New / request | New/old paired change [95%], % | A/A [95%], % |
|---|---:|---:|---:|---:|
| Total Ir | 37,956,069.80 | 37,722,639.65 | **−0.621986 [−0.657997, −0.609650]** | [−0.017925, +0.034873] |
| No-GC Ir | 37,957,220.95 | 37,725,681.45 | **−0.610000 [−0.654673, −0.582798]** | [−0.036947, +0.042471] |

All 18 serial workers / 72 windows pass interpreter mode, source/tool/pin,
exact-page and zero-new-page gates. Targets 2047/367/1128/148/199 pages;
each full window completes 20 hits, zero fallback, shadows off. Four
tool=none preflight workers / 16 windows pass too. Both A/A intervals lie
wholly within the preregistered ±0.1%; both treatment upper bounds are ≤ 0.
No measurement retry/exclusion. All automatic GC counts in these small
fixed-heap windows are zero; the no-GC measurement is still separately kept.

### Mutation/fork coverage and its limits

Native primitive regression: `ruby -Igem/lib gem/test/native_test.rb` passes
2 tests / 25 assertions / no skips. Three production/YJIT fork workers run
19 controls × two seeds, preserving identical response status/body/headers.
Baseline/restored controls hit; empty User/Bucket eigenclasses, singleton ID,
private singleton/ordinary association readers and undefined readers refuse
with positive fallback and no hit. Expected private/undefined reader errors
remain HTTP 500 rather than silently using the cached query.

The broader checker **exits 2**: SQL/whole-DB equality fails even off/off.
Read-only SQLite comparison identifies session `created_at`/`updated_at` and
SolidCache `created_at`/`value` differences in the completed databases; queue
and cable match. No SQL or whole-DB certificate is credited or normalized.
Premeasurement checker setup failures (optional ZJIT constant absent; an
inherited-visibility mutation incompletely restored) are retained privately
alongside the corrected controls. The initial native-test command lacked
`-Igem/lib`; its load error is retained, not counted as a passing test.

## Puma cohort admission

The screens above admit exactly the one preregistered cohort. The unchanged
shared scripts/runtime come from
[`6510cd2`](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8),
including the `b1e239f` RPS harness and `544ad8d` native-GC/passive-wire
observers. Supply the existing native holder binary to that runtime. Use an
unchanged disposable Fizzy copy under that harness's `.corpus/`, the same
seed and entropy policy, and a relocated zero-unit artifact. No app source,
Puma config or dependency changes beyond the committed corpus recipe.

`jit_guards_rps.rb` adds only untimed admission: an external Puma setup hook
asserts actual YJIT in each post-fork worker and writes PID-qualified mode
receipts. Both seed workflows plus additional coverage GETs must reach all
four workers with hits > 0 and fallback 0. Cold/warm checks also reconcile
every running worker's mode receipt in all native servers. Public hit/shadow
counters remain off during timed load. Native GC tags and tcpdump
4.99.3/libpcap 1.10.3 are present identically from the first timed window;
recorder CPU 7 shares the client set, never the server set.

As in `44a33c4`, “A/A first” means adjudicate/report its band first within
the rotated cohort, not run an extra timing cohort. The decision rule above
is unchanged. A failed preflight or cohort is retained without a retry.

## Single Puma cohort: accepted scoped throughput result

Measured
[`796fa58`](https://github.com/thomasklemm/lowrail/commit/796fa5893b4e117168340c229908f89b86fdaf41):
Ruby 4.0.7, Rails 8.1.4, **Puma 6.5.0**, startup YJIT, four workers × one
thread, c16, 20 rotated rounds, 5 s warmup / 20 s load. All 60 timed windows
are retained, including the negative treatment round. No retry/exclusion.

**A/A first:** paired mean −0.440081%, 95% [−1.632208%, +0.800804%]; maximum
absolute single-round A/A spread 6.447765%. It contains zero. Treatment
RPS is **+7.827430% [+6.130743%, +9.838538%]**: its lower bound exceeds the
A/A upper bound, so the preregistered rule passes. This is new F versus
Lowrail off, **not a head-to-head native price for the guard change** versus
old F, and not a comparison obtained by subtracting two historical cohorts.

| Median of window values | off-A | on | off-B |
|---|---:|---:|---:|
| RPS | 511.233 | 546.242 | 503.224 |
| p50, ms | 7.687 | 7.194 | 7.763 |
| p90, ms | 124.517 | 110.797 | 119.969 |
| p99, ms | 265.474 | 246.536 | 268.017 |
| Post-load sum of worker RSS, KiB | 916,908 | 905,118 | 904,300 |
| Sum of worker GC-time deltas, ms | 3,554 | 3,636.5 | 3,590.5 |
| Sum of worker collection deltas | 323 | 338.5 | 331.5 |
| Process allocation deltas / completion | 9,066.219 | 8,398.372 | 9,066.256 |
| Recorder CPU, s | 0.475 | 0.500 | 0.475 |
| Native observer CPU, ms | 51.782 | 53.091 | 50.791 |

Percent changes use the mean of paired-round ratios, not ratios of these
medians. Latency values are medians of window percentiles, not a pooled
histogram or proof of uniformly faster tails. Process deltas include the
untimed metrics calls/background work; more completions occur in on windows.
GC collections/time increase in absolute terms. These are not a fixed-heap
memory/GC price or evidence that GC caused any tail. Observer CPU excludes
Ruby wrapper overhead and kernel capture cost; no observer-off overhead
ablation is claimed.

Both seeds' natural login/GET cold and post-warmup status/body/all-Rack-header
digests match across every arm/window. All 252 workers in the 63 fresh
servers assert actual YJIT after fork; timed counters are off. Before the
first load, all four on coverage workers have positive hits and strict
shadows, zero fallback. Pre/post metrics show no worker replacement. All
3,161 pinned inputs still match. There are **zero HTTP/transport errors**.

The offline receipt audit independently reconciles every oha receipt hash,
count/RPS/latency, schedule, paired bootstrap, worker mode and stable PID set.
**623,992 / 623,992** timed completions join one-to-one with both native
records and passive wire requests in all 60 windows. No join problems,
sequence gaps/retransmissions, kernel/native drops or open GC intervals.
Every one of the 72 interpreter dump totals separately equals its parsed
native self-cost sum and its worker receipt. Raw captures and environment
files stay private because they may contain disposable session credentials.

The [durable machine-readable export](jit-guards.json) contains actual source
and binary/input pins, all census counters (including pre-window totals),
two-seed digests, every Ir window/dump hash, the rejected full-DB controls,
all 60 RPS windows, all 252 worker-mode receipts, process metrics and the
complete numeric GC/wire audit. `$REPO` and `$SCRATCH` are relocatable root
labels, not a portable app/bundle. Format 2 replaces entropy traces and bulky
workflow detail with hashes/counts, deduplicates DB inventories and summarizes
generated-file pin catalogs. Each compacted historical export names its original commit,
path and byte hash; `git show COMMIT:PATH` recovers those original details.
Measurement commits and runtime pins describe the **historical measuring
runtime**, not later branch HEAD. No credentials or raw cookie/packet data
are exported. `window_ratio_in_yjit` is computed from instruction deltas;
the arithmetic delta of a cumulative ratio is not that window ratio.

## Reproduction and next admission boundary

Reuse `script/corpus fizzy` and `script/corpus real-blog-r4`; prepare the
committed `FizzyLinkFixture` and `BlogShowGetOnly` snapshots. Match artifacts
to each actual stock/stats Ruby description, select the three blog units
after resolving manifest paths, renumber IDs and regenerate relative-path
metadata. Keep the existing entropy provider/site rules and update only
source/lock pins for a freshly generated fixture. The export records every
actual input hash. The stats Ruby recipe is:

```sh
./configure --prefix="$SCRATCH/ruby-stats" --enable-yjit=stats --disable-install-doc
make -j4 && make install
```

Official 4.0.7 tar.xz SHA256:
`47ef59413f7a4587ba6a6b78b14036eb5e36eec2ec0b90964801e88d56a3d375`.
The executed stats binary SHA256 is in the export. Pin Bundler 4.0.20 and
use the stock Ruby gem paths for the stats interpreter. Run each census in
a fresh output directory, then the finite interpreter preflight/cohort:

```sh
mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards.rb run CONFIG NEW_OUTPUT
PATH="$VALGRIND/bin:$PATH" CPATH="$VALGRIND/include" \
  mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards_ir.rb none CONFIG NEW_OUTPUT
PATH="$VALGRIND/bin:$PATH" CPATH="$VALGRIND/include" \
  mise exec ruby@4.0.7 -- ruby bench/experiments/jit_guards_ir.rb cohort CONFIG NEW_OUTPUT
```

The Puma config additionally selects only `/buckets`, supplies pinned oha,
the compiled shared `bench/rps_gc_tags.c`, `packet_capture_cpu: "7"`, and
sets `puma_setup` to this branch's `jit_guards_rps.rb`. Keep all settings and
the decision rule above; this completed attempt does **not** authorize a
retry. Its entry point and offline parser are:

```sh
BUNDLER_VERSION=4.0.20 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/jit_guards_rps.rb "$HARNESS/script/rps" CONFIG NEW_OUTPUT
python3 "$HARNESS/bench/rps_attribution.py" OUTPUT > PRIVATE_ATTRIBUTION.json
```

This result changes neither default delivery nor production admission.
The coordinator has authorized taking F toward an **opt-in** tier here,
in order: active DirectSite own-suite equivalence; declared and proved
off/off DB-noise exclusions; purity/lifecycle/fork/concurrency certificates;
a bounded transport-error review; full gates and Thermos. Those are new
prerequisites, **not already satisfied by this throughput result**. Main
integration belongs to the coordinator; README work follows integration.
No ZJIT execution or speed claim is made.

## Opt-in prerequisites, step 1: active own suite and shared rebinding

The first unchanged-suite run was **coverage-invalid**: 124 identical outcomes
and 5,324 identical ordered queries, but zero DirectSite hits / two fallback
increments. The real `BucketsControllerTest#test_index` passed the holder,
reader, scope, model and reflection checks; its connection and visitor were
different from those captured after initialization. Rails' test-schema/fixture
setup replaced the boot connection in the same process. This was correct
refusal, not coverage. No test-only rebind or fixture-ready shortcut was added.

The coordinator authorized generalizing the **same** `Site#eligible?` rebind
trigger from PID change to PID **or connection/visitor identity change**.
All original facts must still pass, and the current adapter must be exact
SQLite with prepared statements and the identical captured database config.
A mismatch still falls back. The historical `worker_bind` counter remains
fork-only; `connection_bind` records either kind. This is a post-price runtime
change: the accepted Puma cohort above still prices its earlier exact head.
It does not yet certify concurrent publication or arbitrary mutable scopes.

With startup YJIT asserted after initialization and again at exit in **both**
workers, `lowrail verify` exits 0: **124 identical identities/outcomes, 117
passes, 7 unchanged baseline errors, 458 assertions, 5,324 identical ordered
queries**. The external adapter records **one DirectSite hit, one strict
SQL/bind shadow, one same-process connection rebind and zero fallbacks**, all
attributed to the actual `BucketsControllerTest#test_index`. No synthetic
request contributes hits. App, configuration and test source trees are
byte-identical to the committed corpus recipe. Single-worker test execution
uses the app's normal `PARALLEL_WORKERS=1` option, not a source patch.

All seven errors are `NoMethodError: undefined method 'reset_all' for an
instance of Current`, with these exact identities in both arms:

- `Bubble::AssignableTest#test_assigning_a_user_makes_them_watch_the_bubble`
- `Bubble::CommentableTest#test_creating_a_comment_on_a_bubble_makes_the_creator_watch_the_bubble`
- `Bubble::ScorableTest#test_a_bubble_has_a_score_that_increases_with_activity`
- `Bubble::ScorableTest#test_commenting_on_a_bubble_boosts_its_score_more_than_boosting_it`
- `Bubble::ScorableTest#test_recent_activity_counts_more_than_older_activity_in_the_ordering`
- `CommentTest#test_first_by_author_on_bubble?`
- `CommentTest#test_follows_comment_by_another_author?`

The public zero-unit production artifact does not become a test certificate;
its public unit counters remain zero. The independent, per-test counters above
are for DirectSite itself. This is own-suite equivalence, **not a green Fizzy
suite** and not public opt-in admission.

An **untimed** real-Puma off-A/on/off-B replay uses the same production hook,
four workers × one thread, startup-YJIT receipts for all 12 workers and the
existing RPS boot/sample/cleanup functions. Both seeds' cold **and warm**
status/body/all-header workflows match. All four on workers have positive
hits/strict shadows (38/20/16/18), one connection/fork rebind each, zero
fallbacks. Sixty ordinary warm GETs and the sampled workflows have no
transport/non-200 errors; no oha or timing window runs.

The first draft of this *new admission-only probe* rejected warm headers:
on-only worker coverage logged in between the paired cold and warm samples,
inserting an extra session (final off-A/on/off-B counts 7/9/7). The corrected
probe defers worker fanout until **after** both paired samples, preserving
identical request histories. It retains literal header comparisons and the
failed probe evidence; nothing is normalized, excluded or re-priced.

[Complete own-suite identities/SQL digests, per-test counts, worker receipts,
source pins and failed-probe evidence](jit-guards-admission.json).
The own-suite reproduction on a separate unchanged corpus copy is:

```sh
BUNDLER_VERSION=4.0.20 RUBY_YJIT_ENABLE=1 RAILS_ENV=test \
  PARALLEL_WORKERS=1 SKIP_TELEMETRY=1 AR_DIRECT_SITE_RECEIPT="$PRIVATE/direct" \
  RUBYOPT="-I$PWD/gem/lib -r$PWD/bench/experiments/ar_request_sites_suite.rb" \
  mise exec ruby@4.0.7 -- target/release/lowrail verify .corpus/fizzy-suite \
  -- bin/rails test --seed 731
BUNDLER_VERSION=4.0.20 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/jit_guards_admission.rb "$HARNESS/script/rps" CONFIG NEW_OUTPUT
```

## Opt-in prerequisites, step 2: complete DB audit with a named boundary

Two new **untimed** controls seed `Kernel.srand(0)` and `Kernel.srand(1)`
identically in off-A/on/off-B. The existing source-pinned entropy harness
also fixes Ruby wall time during the natural login plus 50 warm GETs, not
only the later sampled requests. No application/configuration patch or
SolidCache method replacement is involved. Each run then executes all 19
mutation controls at both response seeds in fresh forked workers, with
actual YJIT asserted in each worker. All **38 responses and ordered SQL
traces per run** match. Baseline/warm/restored controls each complete two
hits and two strict shadows per request; invalidated controls refuse.

The typed snapshots cover schema and every row in **68 tables**: primary
46, cache 4, queue 14, cable 4, including SQLite sequences and internal
metadata. **Primary, queue and cable match completely, with no exclusions.**
Primary session `created_at` and `updated_at` remain compared: the extended
warmup clock control removes their earlier variation at its source.

Exactly **one column is excluded** in the separate declared-exclusion
comparison: `cache.solid_cache_entries.created_at`. Its column hashes differ
off/off in every compared case, and every on difference is also an off/off
difference. SQL inserts use SQLite's
`STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')`, not Ruby `Time.now`; neither the
Ruby clock control nor `Kernel.srand` fixes SQLite's clock. Every other
cache column, including every raw value byte, remains compared. No payload,
expiry, session column or sequence is normalized away. The original
**raw whole-DB checker still exits 2** for this timestamp difference;
`passed_with_declared_exclusions` is a distinct, explicitly labeled result.

The alternate **split certificate** also passes: complete primary/queue/
cable, exact cache schema/metadata and every app-written cache key/value.
The single named internal key
`__solid_cache_entry_size_moving_average_estimates` is decoded and retained
separately, together with its row hash, presence and SQLite sequence hash.
This is a **store-internal boundary, not noise** and not unrestricted
full-cache determinism: the split gate does not require equality of that
internal row, its estimate or cache `sqlite_sequence`; it retains those as
separate observations. The stricter declared-exclusion gate still compares
them. With RNG seed 0 it is absent in all arms; with seed
1 its raw ASCII payload decodes to **[189] in all arms**. Its own accounted
row size is **192**, making current total size **381**, not 189: 49 key
bytes + 3 payload bytes + SolidCache's 140-byte row overhead. The estimate
is calculated before writing the bookkeeping row.

SolidCache 1.0.10's [write-triggered expiry sampling](https://github.com/rails/solid_cache/blob/v1.0.10/lib/solid_cache/store/expiry.rb)
uses `rand`; its [moving-average store](https://github.com/rails/solid_cache/blob/v1.0.10/app/models/solid_cache/entry/size/moving_average_estimate.rb)
writes pipe-delimited decimal estimates directly. The earlier unseeded
off-B-only row is preserved privately as mechanism evidence, not relabeled
an on effect or an allowed arbitrary cache-value difference. The two
controlled runs exercise both absent and present branches. The DB-audit
regression rejects changed application cache values and primary rows; only
the explicitly separate split certificate allows the named internal row.

[Durable DB export](jit-guards-db.json) retains every response/SQL digest,
complete table inventories, full and comparison hashes, the excluded-column
hashes, decoded internal estimates, coverage and original receipt hashes.
Raw DB values, cookies, SQL binds and entropy traces remain private. Earlier
cold/unseeded/draft-audit failures are retained, not retroactively passed.

```sh
JIT_GUARDS_HARNESS="$HARNESS/script/native-bench" BUNDLER_VERSION=4.0.20 \
  AR_GUARD_FORK=1 AR_GUARD_NATIVE_WARM=1 AR_GUARD_RANDOM_SEED=0 \
  mise exec ruby@4.0.7 -- ruby bench/experiments/ar_request_sites_check.rb CONFIG NEW_SEED_0
# Repeat once with RNG seed 1 and a different output directory.
mise exec ruby@4.0.7 -- ruby bench/experiments/ar_request_sites_db.rb \
  NEW_SEED_0/result.json NEW_SEED_1/result.json "$PRIVATE/new-db-export.json"
mise exec ruby@4.0.7 -- ruby bench/ar_request_sites_test.rb
```

The DB exporter emits format 1. The published format-2 file is a compacted
immutable historical export; a new run must not overwrite it or borrow its
measuring pins. Archive a new sanitized format-1 export before compacting it.

## Opt-in prerequisite 3: refused transitive certificate

The own suite and 19 mutation controls are necessary but **not sufficient**.
A new negative control changes `ActiveRecord::Relation#_exec_scope` in memory
after authentication, on entry to the real bucket partial, to append
`where(id: -404)` to the ordinary scope result. It does not edit any app or
configuration file. Startup and child-worker YJIT are asserted; every arm
gets an independent seed copy and the same mutation. Strict SQL shadowing
is **off**, matching the normal runtime rather than turning a diagnostic
exception into a production guard.

At both response seeds, all arms return **HTTP 200**, and off-A/off-B have
identical bodies, all headers and ordered SQL. On has a **different body,
headers and SQL**, while recording **two DirectSite hits, zero fallbacks**.
The forked on worker also successfully rebinds once. The original collector
exited 2; the unified follow-up now distinguishes stale-plan exit **3** from
raw-DB-only exit **2**. Neither is a passed admission gate.
The overridden transitive scope method is absent from `Site`'s handwritten
dependency inventory; the top-level named scope bodies remain unchanged.
This is a demonstrated missing assumption, not cache-clock noise or a
hypothetical concurrency concern. [Complete negative receipt](jit-guards-certificates.json).

The final unified replay runs `baseline`, `transitive_scope`, then `restored`
at both seeds **in the same forked worker**. Baseline/restored have exact
responses and SQL plus two hits/zero fallback each. Only the mutated case
diverges; it still records two stale hits/zero fallback. All three workers
show actual YJIT, disabled ZJIT and disabled SQL shadow. The public receipt
preserves the collector's case/seed/flat-response/`counts_delta`/DB schema,
with only private SQL/binds removed, entropy traces summarized and inventories
deduplicated. Its raw private receipt hash and source pins are retained.

Adding only `_exec_scope` to the manual list would repair this one input,
not establish the requested **compiler-owned** transitive/purity certificate.
There is also no generated proof of argument evaluation order or prohibition
on boot execution of arbitrary scopes. Concurrent first-bind publication,
roles/shards/pools, reload and lazy-loading remain unclosed obligations;
single-thread Puma and one same-process suite rebind do not certify them.

Production integration also cannot reuse today's template seam unchanged.
`Manifest#compatible?` deliberately refuses every nonempty template table
before installation because `Templates.install` changes framework ancestry.
F's external overlay similarly prepends a handler and a relation hook,
symmetrically in its experimental arms; that does not prove equivalence to
an uninstrumented app or authorize undoing main's refusal. No production
pass/registry/manifest change is made. **Opt-in integration is not ready.**

Reproduce the negative admission check, without a timing cohort:

```sh
JIT_GUARDS_HARNESS="$HARNESS/script/native-bench" BUNDLER_VERSION=4.0.20 \
  AR_GUARD_FORK=1 AR_GUARD_TRANSITIVE=1 mise exec ruby@4.0.7 -- ruby \
  bench/experiments/ar_request_sites_check.rb CONFIG NEW_OUTPUT
# Expected: exit 3, response_sql_certificate_passed false; baseline/restored hit.
# Mutated response_equal/sql_equal/stale_plan_refused false; off/off remains exact.
# Raw DB equality is reported separately: exit 2 only when the certificate passes.
# The collector also writes NEW_OUTPUT/public.json, safe for publication.
```

The committed negative receipt is the collector's `public.json` byte-for-byte,
not a translation into the deleted checker's schema. Its raw receipt hash is
an integrity reference, **not** a claim that private SQL/binds can be recovered
from git. Regenerate the same public projection with
`jit_guards_export.rb control PRIVATE_RECEIPT PUBLIC_EXPORT`. The earlier
summary remains recoverable in
[`6d3b30a`](https://github.com/thomasklemm/lowrail/commit/6d3b30aee03c14484c3a052cc450fb0ec284f591).

## Closure invalidation feasibility: no new timing

**Verdict: no clean incremental closure certificate in the present compiler;
keep Y/F branch-only.** Reuse G's planned post-admission tripwire on
`thomasklemm/sealed-tripwire` and the existing epoch, not a second invalidator
or per-method hot polling. Per the coordinator, G owns the tripwire's mutation
coverage/lifecycle contract. Its implementation was not yet published when
this design was written; no G code is imported or certified here. The open
question below is **which holders/methods the compiler can completely derive**.

**Proposed handoff:** emit one cold certificate per DirectSite program with
effective receiver/selector/body/visibility facts and all lookup ancestries.
Register its actual loaded classes, modules and existing model singleton
holders through G's mechanism before publishing the plan. A relevant mutation
bumps the shared epoch and refuses the plan; do not execute app scopes to
renew it in a request. Reuse the epoch predicate at the consumer's guarded
entry/use boundaries. Closure subscriptions add no hot traversal; DirectSite
does not currently have that epoch predicate, so zero *total* guard cost is
not claimed. Keep the existing live receiver/schema/scope/connection checks.

**Why derivation blocks this specimen:**
[ARPlanSites](../gem/lib/lowrail/ar_plan_sites.rb) is explicitly syntactic;
[ARPlanFacts](../gem/lib/lowrail/ar_plan_facts.rb) recognizes a small fixed
query chain; [ARPlanBuild](../gem/lib/lowrail/ar_plan_build.rb) gathers named
holders/methods and source pins, not a transitive effect graph. DirectSite's
manual list omits `_exec_scope`. A complete worklist must follow generated
delegates, scope blocks, `super`, association construction, predicate/type
building and visitor/adapter calls whose work the plan removes. Boot traces
miss branches. Dynamic selectors/receivers, eval, autoload and opaque C calls
need modeled contracts or refusal. Stable source locations are not purity;
executing arbitrary scopes at boot is not a safe discovery substitute. No
closed receiver/effect model for this Rails path exists here. Watching only
today's list through a better tripwire still misses an unlisted dependency.

**Cost estimate, no timing:** after dispatch resolution, a worklist over
\(M\) method facts and \(E\) call edges takes \(O(M+E)\) cold work/storage,
plus parsing/effect analysis. Deduplicating \(H\) holders/ancestors gives
\(O(H)\) tripwire registrations; G owns their mutation-time cost. Additional
closure work per request is **zero** with that cold registration; the required
epoch check is \(O(1)\), not \(O(M)\) reflection. The unresolved cost is the
new closed-subset compiler/modeling effort, not an extra guard loop. No
credible numeric boot/memory or instruction price follows from this design.
Adding `_exec_scope` manually would fix one input, not derive that closure.

**Acceptance test retained:** run the unified negative check above, with
shadows off, both seeds and an actual-YJIT post-fork worker in every arm.
Require off/off and off/on status/body/all-header/ordered-SQL equality,
zero DirectSite hits and positive fallback after the `_exec_scope` mutation;
an unmutated positive control must still hit. Keep raw DB-clock rejection
separate from those response/SQL checks and the declared DB boundary.
A future certificate must also handle suppressed callbacks, visibility,
include/prepend/remove/undef/singleton changes and mutation inside argument
evaluation without replay. The current replay still returns two stale-plan
hits and zero fallback at both seeds. **This acceptance test remains red.**

## Bounded transport-error review

F's first rejected serving run reports four `connection closed before
message completed` errors in its round-4 on window, with every worker
terminated for missing a 60-second heartbeat. The reason for those missed
heartbeats was not established; connection-identity fallback was separately
proved and must not be relabeled their cause. F's later worker-local cohort
already had zero errors, so nonrecurrence is not unique to the new guards.

Under Y's new guards, all **60 timed load windows**, all warmups, and the
later 12-worker untimed production-rebind replay have zero HTTP/transport
errors. All 623,992 timed completions reconcile against native and wire
records. This meets the requested bounded nonrecurrence observation, **not
a root-cause explanation or a general serving certificate**. No new load
cohort or error exclusions were introduced for this review.

## Thermos follow-up and gate attribution

The original correctness/security and maintainability reviews requested
changes; neither admitted production delivery. The follow-up removes the
unused second DirectSite implementation and its dead query hook, folds the
negative certificate into the existing worker/fork harness, and asserts both
actual YJIT and disabled ZJIT in the child. Compacted exports preserve every
numeric counter/window/decision outside the explicitly summarized workflows,
and distinguish measuring pins from HEAD; original details remain recoverable
by commit/path/hash. The follow-up export regression covers small and bulky
workflows, both accepted/rejected windows, historical measuring commits and
the retained/generated pin distinction.

An actual SQLite column addition changes the captured schema and was already
rejected. The follow-up nevertheless found that the separate split comparator
could accept a header-only change with an unchanged schema string. It now
requires an explicit header hash; the regression holds the schema string
fixed and fails on the previous comparator. Current capture receipts require
that field; the older DB export remains historical, not silently upgraded.
Changed primary rows and app cache values remain rejected. The
split store-internal-key boundary is coordinator-approved and explicitly
separate from complete cache equivalence, not silently widened noise.

The all-bench stale-artifact failure reproduced on the old branch base:
the test demanded `stale build`, but the deliberate ancestry refusal ran
first. Current main
[`e05238f`](https://github.com/thomasklemm/lowrail/commit/e05238f2cdb45ea6b419966427e4dd20b6cd5a7d)
passes the exact targeted test (1 run / 24 assertions); it already contains
[`b8c8832`](https://github.com/thomasklemm/lowrail/commit/b8c8832dbc8c117c69a0b5b173843817a5f119e8),
which keeps both refusal-order-independent rejection and an independent
eligible-source staleness control. This is an **old-base test expectation**,
not a newly fixed runtime defect in Y. Refresh by merging main, preserving
published branch history; no rebase/force push or main write is needed.

### Merged-tree verification (Ruby 4.0.7, Bundler 4.0.20)

Main was merged at
[`8b9cb6e`](https://github.com/thomasklemm/lowrail/commit/8b9cb6eb8c871142809f471e1d4a2dda12b07d1b),
preserving published branch commits. The reviewed follow-up is
[`2786f7f`](https://github.com/thomasklemm/lowrail/commit/2786f7fb49aa62fac337f91552fdc1c29299fe70).

- `cargo test --locked`: **51 passed** (41 unit, 2 types/MCP, 8 verifier),
  zero failures/ignored. Rust, gem and fixture inputs are unchanged by the
  final bench/export follow-up.
- Every `bench/*_test.rb` separately, with strict mode, Valgrind/headers and
  seed 1729: **47 runs / 731 assertions**, zero failures/errors/skips across
  eight suites. The stale-artifact test is included.
- From `gem/`, `LOWRAIL_STRICT_GATES=1 BUNDLER_VERSION=4.0.20 mise exec
  ruby@4.0.7 -- rake test TESTOPTS='--verbose --seed=1729'`: **193 runs /
  6,932 assertions**, zero failures/errors, **three named optional skips**.
  This began on `400fa41`; gem/runtime/test/fixture files stayed unchanged
  through `2786f7f`. An earlier merged attempt was terminated by the executor
  restart; it has no credited outcome. The supervised complete run exited 0
  with no automatic restart. Its temporary services were stopped.

The three skips are `MaterializeCorpusTest#test_campfire` (missing corpus),
`RailsSuiteReportTest#test_separate_build_does_not_change_view_primary_key_results`
(missing Rails checkout), and
`RailsSuiteReportTest#test_profiling_preserves_backtrace_cleaner_results`
(missing Rails bundle). They are **not coverage** of those integrations.

Fresh header-aware RNG-0 and RNG-1 controls each preserve all 38 response/SQL
checks and both declared/split DB comparisons; each still exits 2 for raw
SQLite timestamps. The same-worker negative replay exits 3, with exact
baseline/restored responses and hits, and two stale-plan hits/zero fallback
only in the mutated case. Its committed public output regenerates byte-for-byte.
The header-only regression fails against the previous comparator and passes
now. No timing, new RPS cohort, app/configuration patch or production admission
is part of these gates.
