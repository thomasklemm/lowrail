# Whole-request hotspot map — interpreter, Lowrail off

2026-10-20. **Measurement only: no pass or runtime implementation.**
Rails 8.1.4 is primary; Campfire's Rails 8.2 alpha is supplementary. Results
describe the production fixtures and selected GET routes, **not a traffic mix**
or a production latency profile. Existing allocation evidence is in
[allocations.md](allocations.md); no allocation census is repeated here.

**First priority table:** blog `/articles/1`, Starter dashboard HTML/JSON and
PingCRM organizations HTML. Blog show and Starter JSON pass all controls;
Starter HTML and PingCRM are diagnostic/rejected, for the reasons below.
The remaining declared routes, Redprints and secondary Campfire are still
being collected. The current three-app ranking is therefore **provisional
and descriptive**, not a completed four-app result.

The first map's large non-view owners are ActiveSupport utilities, Rack/request
work and AR query/adapter work. Keep the sealed pilot focused on fixed caller
structure; do not turn these inclusive wrappers into removable budgets or
strip security/events/middleware. SSR needs a separate Node/latency view.

## Read the percentages correctly

The denominator is the entire warmed, in-process `Rack::MockRequest` envelope,
with the shared N=0 overhead subtracted. **Self** assigns each instruction
sample to its nearest Ruby source frame; it partitions the envelope. Native
primitives belong to their nearest Ruby caller; GC has its own bucket.
**Inclusive** is the union of samples whose stack contains a subsystem, once
per stack even with recursion. It is not additive: middleware, callbacks,
notifications and sessions wrap unchanged application work. A 90% inclusive
wrapper is **not** a 90% optimization opportunity. Rank investigation by self
cost, then inspect the inclusive boundary and its live responsibilities.
Signed N=0 subtraction can put a near-zero share slightly below zero or an
inclusive wrapper fractionally above 100%; these sampling seam residues are
retained, not clamped or credited as work/savings.

This is instruction-weighted **stack sampling**, not a claim that stock
Callgrind understands Ruby source files. MRI's C interpreter frames alone
cannot provide that attribution. Nor are these the layer study's ordered
ablation deltas: source ownership, a wrapper's descendants and removable
interpretation are three different quantities. Do not add this map's shares
to the old 33–41% handwritten endpoint ceiling.

PostgreSQL server CPU, Node SSR CPU, kernel work, network/database wait and
other threads/processes are outside this client instruction metric. The SSR
HTTP bucket prices Ruby-side setup/protocol/serialization, **not the cost of
React SSR itself**. Embedded SQLite native work is inside the client process.
The benchmark client and Ruby/other-gem residue are retained, not silently
redistributed into Rails. Zero samples is not proof that an operation never
runs. GETs do not price write-heavy parsing or CSRF verification failures.
Near-zero GC here reflects the fixed large pools, not a zero production GC
budget. Logging follows the shared benchmark worker: `Rails.logger` at warn
and the Active Record logger disabled. Events/notifications remain live;
this does not price a deployment's info/debug SQL or request-log volume.

## Protocol and attribution

The shared [`RequestPairs.heap_instructions`](../../bench/request_pairs.rb)
and [`HeapWindows`](../../bench/heap_windows.rb) implement the
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
protocol: six fresh randomized rounds, seed 41231, 50 warmup requests,
N=0/50 total and GC-excluded windows, alternating order, three full GCs and
one untimed settling request before every window. Pool floors remain
1,000,000 / 250,000 / 100,000 / 20,000 / 10,000 slots, sparse anchors retained.
GC is enabled in requests. Every worker proves actual interpreter mode;
profiled workers also refuse a loaded Lowrail constant. Off workers use the
unchanged no-setup worker with `LOWRAIL=0` and no `RUBYOPT`.
Independent off-A/off-B controls must include zero and fit
inside ±0.5%; all five actual heap capacities must match within one page.
There are never more than four Callgrind workers. Two independent two-worker
cohorts may share that limit; elapsed profiling time is not the metric.

[`hotspots-valgrind.patch`](../../bench/experiments/hotspots-valgrind.patch)
adds a private sampling request to Valgrind 3.19.0. While client instruction
collection is active, after a randomized initial phase the requesting thread
draws a SIGPROF sample after a random 32,768–98,303 normal-client Ir
(mean 65,535.5). It forces the next
dispatcher poll, rather than accepting the normal long signal-delivery lag.
[`hotspots.c`](../../bench/experiments/hotspots.c) captures `rb_profile_frames`
directly, as the interpreter path in StackProf 0.2.28 does; it never walks
Ruby frames during GC. No timer, TracePoint, app method replacement or Lowrail
setup participates. Captured frame handles are rooted through later GCs.
Signal-handler and profiler root-marking work are excluded from the sampling
budget/work counter, not charged to a fictitious application subsystem.

Each cohort also has two independently booted profiled-off arms. Their
corrected work A/A obeys the same zero/±0.5% rule. The nominal 95% interval for
each paired profiled-versus-unprofiled client-work comparison must stay within
±0.5% (it need not contain zero); the report checks both arms, not only the
driver's first-arm fidelity check. Any empty/truncated/dropped/lost capture or maximum delivery
lag above 3,277 Ir rejects the cohort. These checks bound perturbation; they
do not prove the absence of systematic source-attribution bias.

[`hotspots.rb`](../../bench/experiments/hotspots.rb) classifies the same stacks
on three separate axes: subsystem, Rails component/gem, and gem/file prefix.
Native `<cfunc>` frames are removed before selecting the source owner.
Source-prefix classification is deliberately explicit, not inferred from an
inclusive wrapper's name. The complete signed per-window counts and group
dictionaries are exported; self totals reconcile on every axis in every
profiled window and after N=0 subtraction. `hotspots_report.rb` checks this
identity before writing a table.

Two profile arms are pooled within each round. App values first average the
measured route/format percentages with equal weights, then report the median
of the six whole-round values and the shared seeded bootstrap 95% interval.
The cross-app ranking gives each of the four primary apps equal weight;
Campfire is excluded. Individual displayed medians need not sum to exactly
100%. Six-round intervals are coarse, nominal sampling/boot uncertainty,
not traffic-mix, fixture, version or classification uncertainty.

## Rejections and tool correction

The initial stock-8-MiB-reservation blog-index attempt is **rejected**, with
five aggregated rounds and the final round's raw logs retained. All 24
worker logs warned `brk segment overflow`, including all twelve ordinary
off-A/off-B workers. It was interrupted to correct the tool, not to obtain a
more favorable A/A result. No arm or partial round is accepted or salvaged.
The new protocol uses the 512 MiB **virtual brk reservation**, preserving
Ruby pool floors, windows and requests. See the separate
[shared benchmark correction](../bench.md#valgrind-brk-reservation-correction-2026-10-20)
for why growth failure can change allocator layout without relocating the
heap, and for historical-results caveats. Every new app/worker log must be
overflow-free. The completed first blog-show cohort predates the shared
preflight addition but uses that same corrected reservation and checks every
worker log; its recorded source fingerprints were verified before the shared
driver changed. It is not relabeled as having run the later preflight.

Method development also discarded a TracePoint attribution prototype
(approximately 85% residual work overhead) and an initial signal sampler
with roughly 1.5 M-Ir delivery lag. Neither supplies a performance result.
The accepted sampler contract check independently prices asymmetric 1:3
nested work, checks recursive-inclusive deduplication and the self partition,
native primitive ownership, frame survival across GC and a dedicated full GC.
No app allocation census, pass-support gate, or native speed claim follows.

For any later failed A/A/heap/fidelity/capture gate, the **entire** route/format
cohort remains rejected. Its map can be shown only as diagnostic, and any
aggregate containing it is marked descriptive. There is no retry-until-green,
borrowed control, tolerance widening, or clean-arm salvage.

The finite Starter dashboard HTML cohort is **rejected for sampler fidelity**,
not overflow: ordinary A/A, sampler A/A, all five heaps and capture integrity
pass, but corrected trace-A versus off-A is −0.484% [−0.532, −0.429] total
and −0.474% [−0.573, −0.421] no-GC. Trace B independently crosses −0.5% too.
The map remains diagnostic; the cause of the perturbation is unassigned.
It is not rerun, and the limit is not widened. Its inclusion makes the
Starter average and any cross-app average containing it descriptive, even
though the independent JSON cohort passes.

PingCRM organizations HTML is **rejected for ordinary no-GC A/A**: its interval
is [+0.0128%, +0.0421%], excluding zero even though it lies well inside ±0.5%.
Total A/A [−0.0080%, +0.0263%], sampler A/A, both-arm fidelity, heaps and
capture checks pass. It remains diagnostic without a replacement cohort.

## Workload and reproduction

Build all five pins with `script/corpus`, using the repository's Ruby 4.0.7.
Prepare production databases, assets and authentication as in
[the Inertia workload](../m0/inertia.md#authenticated-production-workload) and
[Campfire M0](../m0/campfire.md). The blog has three articles and three
comments; PingCRM has the isolated M0 user's 30 organizations and 30 contacts
(ten rows/page); Redprints has twenty proposals. Starter HTML requires the
real Node SSR server; it is not a cached/stubbed HTML fixture. Its profiled
worker checks rendered child elements below `#app` before warming.
Private authenticated headers and dynamic paths stay in `tmp/m0/`, never in
the export. Keep the same database/assets/auth fixture for every arm.

The finite request-shape set is blog index/show/edit HTML; Starter dashboard
HTML and JSON plus profile JSON; PingCRM organizations HTML and contacts JSON;
Redprints proposals HTML and proposal JSON; Campfire room/sidebar HTML and bot
JSON. The latter three use `CAMPFIRE_RESPONSE_CACHE_MB=0` as a deliberate
response-cache-disabled boundary, **not** a claim about the app's default warm
response-cache performance. Existing fragment behavior otherwise remains live;
the **Campfire fragment caches** decision stays unchanged. Each primary app
therefore has two or three distinct routes; formats are explicit shape weights,
not an isolated route-versus-format experiment.

Redprints' untouched corpus pin is **8.1.3**. This study uses a disposable
`redprints-hotspots-r4` copy with only the framework gems updated to **8.1.4**;
Inertia/StoreModel/FrozenRecord/Freezolite and app code remain unchanged.
Campfire retains its **8.2.0.alpha** lock and is never pooled into the primary
ranking. Locks, loaded gem versions, actual heaps, all signed attribution
counts, controls, source/tool fingerprints and worker-log digests are in
[`hotspots-results.json`](hotspots-results.json). Neither cookies nor response
bodies are exported. The allocation pools and their eligibility limits remain
those in [allocations.md](allocations.md), not new counts inferred from Ir.

Build the sampler **before**, not alongside, the measurement. It uses the
same verified Valgrind 3.19.0 archive as `script/bench-valgrind`, but applies
the combined sampling/512-MiB patch instead of the brk-only patch:

```sh
repo=$PWD
build=$(mktemp -d)
prefix=/tmp/NEW-hotspots-valgrind
curl -fL https://sourceware.org/pub/valgrind/valgrind-3.19.0.tar.bz2 \
  -o "$build/valgrind.tar.bz2"
echo "dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02  $build/valgrind.tar.bz2" | sha256sum -c -
tar -xjf "$build/valgrind.tar.bz2" -C "$build"
cd "$build/valgrind-3.19.0"
patch -p1 < "$repo/bench/experiments/hotspots-valgrind.patch"
./configure --enable-only64bit --prefix="$prefix"
make -j4 && make install
cd "$repo"
export PATH="$prefix/bin:$PATH" CPATH="$prefix/include${CPATH:+:$CPATH}"
export HOTSPOT_VALGRIND_TOOL="$prefix/libexec/valgrind/callgrind-amd64-linux"
ulimit -d unlimited
# Configure the corpus's PostgreSQL socket/user and SSR/Redis services first.
BENCH_JOBS=2 HOTSPOT_ONLY=blog-show-html \
  mise exec -- ruby bench/experiments/hotspots_study.rb /tmp/NEW-blog-show
# At most two such two-worker studies at once, including their preflights.
mise exec -- ruby bench/experiments/hotspots_report.rb /tmp/hotspots.json \
  /tmp/NEW-blog-show
```

Use the labels in the cohort table to select the other declared shapes.
`HOTSPOT_ONLY` accepts a comma-separated list; each output root must be new.
Never replay a rejected label to replace its verdict. Sampler seeds are
recorded per worker (the fixed 41231 seed controls arm order/bootstrap, not
an invented claim that process-dependent sample phases are identical).
The measurement engine in this orb has SHA-256
`bab749e091c31c770a292f7261a322c6ef7e156ae4881d74ec71ffeadc7d04ac`;
it is distinct from the shared brk-only engine. Binary hashes are
build-specific, not universal source pins.

The corrected-tool sampler contract check passes: independently priced B is
74.9976% of asymmetric A+B work; sampled B inclusive is 75.1369% of **6,210**
samples, recursive A inclusive is 99.9839%, maximum lag is **30 Ir**, and the
dedicated full GC produces **247** GC samples. All self samples partition;
no empty/truncated/dropped/lost capture or overflow occurs. A report negative
probe also refuses a synthetic +2% second-arm work perturbation and a broken
self-count partition, while accepting the unchanged blog export.

## Which lever fits the expensive work?

These are **investigation recommendations, not removable percentages or pass
promotions**. The same source-owned bucket can contain necessary data/crypto
work, dispatch and descendants. The existing safety refusals and parked
decisions still apply. The named overlaps below refer to rows in
[DECISIONS.md](../DECISIONS.md), including its allocation follow-ups; their
conditional pools must not be added to this map or to each other.

| Hotspot family | Best-fit lever | Boundary and existing decision rows |
|---|---|---|
| AS utilities/I18n/time | **Sealed endpoint**, for fixed caller structure only | Preserve live locale, defaults, type conversion and mutable tables; a seal is not permission to freeze request values. Overlaps **Whole compiled ERB specialization**, **CurrentAttributes default tuple iteration**, **Literal inflection plans**. Their narrow eligible pools do not cover this whole bucket. |
| Rack/middleware/request | **Upstream Rails/Rack** | Retain the real envelope and state/security/exception pipeline, rather than infer a large middleware-removal budget from inclusive cost. Overlaps **Replacement-layer ceiling, Rails 8.1.4 blog index/show** and **Remaining controller/params/response interpretation**. **Upstream static miss candidates** is an adjacent, separately counted bucket, not an extra saving inside this row. |
| Other gems/stdlib/app | **App recommendation: inspect the named gem/prefix before changing code** | This heterogeneous residual includes URI/concurrency/stdlib machinery, not one certifiable pass. There is **no exact existing residual-wide decision row**. **Literal inflection plans** and the two **Net::HTTP** allocation follow-ups overlap only their named mechanisms, not the rest. Never claim the residual is all avoidable VM dispatch. |
| AR query/relation | **Guarded pass**, only for a proven fixed query shape | Keep current scopes, authorization, binds, quoting, ordered SQL, connection/shard facts and notifications. Overlaps **Fixed query-shape allocation plans**, **AR plans, preload plans** and **Escaping AR app-chain plans**. A large source bucket does not reopen the parked instantiate pass or price database-server work. |
| Session/cookies/crypto | **Upstream Rails**, not a boot-time session/result cache | Fresh authenticated state and cryptographic work remain necessary. There is **no existing standalone session pass row**; this overlaps the retained session/cookie boundary in **Replacement-layer ceiling, Rails 8.1.4 blog index/show** and **Remaining controller/params/response interpretation**. GET-only fixtures do not certify CSRF verification or writes. |
| View helpers/tags/forms; buffers/rendering | **Sealed endpoint** for compiled caller structure; **upstream Rails** for a general primitive | Preserve helpers, escaping, fresh buffers, form model/state and events. Overlaps **Two tiers: guarded (default) and sealed (opt-in)**, **endpoint/action**, **Compiled form/literal-tag intermediates**, **Tag/form attribute component**, **SafeBuffer/OutputBuffer interpretation**, and quarantined **Source view/link_to and route/path**. No safety refusal or quarantine is reversed. |
| Inertia props/config/render | **Guarded pass**, with net guard cost measured separately | Preserve per-request props, partial/deferred/once/rescue behavior, iterator identity and post-app-code checks. Overlaps **inertia/config_bind**, **inertia/props**, **Inertia prop path scaffolding** and **Inertia metadata try dispatch**. Existing rejected final-runtime props evidence is not upgraded by a hotspot map. |
| SSR HTTP client | **App recommendation**, including separate Node/IPC/latency profiling | The denominator excludes Node CPU and waiting, so this is Ruby protocol/setup work, not an SSR-removal budget. Overlaps **Net::HTTP SSR setter discovery** and **Net::HTTP header capitalization**. A future guarded component can target only those certified intermediates, never cache personalized SSR output. |
| AR SQL/adapter | **Upstream Rails/adapter** | Native client decoding/type work is real work; server CPU is absent. Overlaps **PostgreSQL type-map tuple dispatch** and **Fixed query-shape allocation plans**. Keep result rows, casts, adapter extensions and connection/OID generations; inspect query count/data shape separately in the app. |

<!-- BEGIN GENERATED HOTSPOT TABLES -->

## Cohort controls

Rejected means the entire request-shape cohort is diagnostic; it is not rerun or salvaged.

| Request shape | Total / no-GC M Ir | Baseline A/A CI %, total / no-GC | Heap | Sampler A/A | Fidelity | Capture | Verdict |
|---|---:|---|---|---|---|---|---|
| blog-show-html | 8.746 / 8.749 | [-0.0727, +0.0248] / [-0.0619, +0.0033] | pass | pass | pass | pass | **accepted** |
| starter-dashboard-html | 8.518 / 8.518 | [-0.0280, +0.0441] / [-0.0439, +0.0280] | pass | pass | FAIL | pass | **REJECTED** |
| starter-dashboard-json | 5.140 / 5.142 | [-0.0254, +0.0812] / [-0.0374, +0.0224] | pass | pass | pass | pass | **accepted** |
| pingcrm-organizations-html | 11.960 / 11.959 | [-0.0080, +0.0263] / [+0.0128, +0.0421] | pass | pass | pass | pass | **REJECTED** |

## Route/format detail

Five largest self costs per request shape; intervals include all six rounds.

| Request shape | Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---|---:|---:|
| blog-show-html | AS utilities/I18n/time | 96.34 [96.24, 96.42] | 17.02 [16.80, 17.28] |
| blog-show-html | View helpers/tags/forms | 30.02 [29.81, 30.07] | 11.79 [11.59, 12.01] |
| blog-show-html | Rack/middleware/request | 98.75 [98.75, 98.79] | 11.56 [11.42, 11.71] |
| blog-show-html | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 7.83 [7.65, 8.10] |
| blog-show-html | AR query/relation | 81.79 [81.69, 81.93] | 7.01 [6.71, 7.21] |
| starter-dashboard-html (REJECTED) | Rack/middleware/request | 98.30 [98.25, 98.33] | 25.74 [25.67, 25.92] |
| starter-dashboard-html (REJECTED) | SSR HTTP client | 12.61 [12.51, 12.65] | 12.09 [12.02, 12.13] |
| starter-dashboard-html (REJECTED) | AS utilities/I18n/time | 95.81 [95.77, 95.88] | 11.49 [11.12, 11.63] |
| starter-dashboard-html (REJECTED) | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 8.53 [8.31, 8.68] |
| starter-dashboard-html (REJECTED) | Session/cookies/crypto | 91.55 [91.41, 91.62] | 5.59 [5.52, 5.61] |
| starter-dashboard-json | AS utilities/I18n/time | 93.10 [93.07, 93.14] | 23.58 [23.22, 23.94] |
| starter-dashboard-json | Rack/middleware/request | 97.17 [97.15, 97.23] | 13.44 [13.19, 13.64] |
| starter-dashboard-json | Other gems/stdlib/app | 100.00 [99.99, 100.01] | 10.15 [9.94, 10.50] |
| starter-dashboard-json | AR query/relation | 66.11 [65.95, 66.21] | 8.29 [8.17, 8.55] |
| starter-dashboard-json | Inertia props/config/render | 76.81 [76.66, 77.01] | 8.23 [8.13, 8.32] |
| pingcrm-organizations-html (REJECTED) | AS utilities/I18n/time | 48.38 [48.17, 48.54] | 15.74 [15.54, 15.96] |
| pingcrm-organizations-html (REJECTED) | AR query/relation | 85.20 [85.09, 85.30] | 14.86 [14.61, 15.13] |
| pingcrm-organizations-html (REJECTED) | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 9.94 [9.77, 10.24] |
| pingcrm-organizations-html (REJECTED) | Rack/middleware/request | 98.71 [98.67, 98.74] | 9.38 [9.36, 9.42] |
| pingcrm-organizations-html (REJECTED) | AR SQL/adapter | 15.71 [15.59, 15.73] | 6.78 [6.58, 6.82] |

## blog

Equal shape weights: blog-show-html.

All constituent cohorts accepted.

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AS utilities/I18n/time` | 96.34 [96.24, 96.42] | 17.02 [16.80, 17.28] |
| `View helpers/tags/forms` | 30.02 [29.81, 30.07] | 11.79 [11.59, 12.01] |
| `Rack/middleware/request` | 98.75 [98.75, 98.79] | 11.56 [11.42, 11.71] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 7.83 [7.65, 8.10] |
| `AR query/relation` | 81.79 [81.69, 81.93] | 7.01 [6.71, 7.21] |
| `Buffers/escaping` | 21.02 [20.94, 21.20] | 6.94 [6.84, 7.02] |
| `Rendering/lookup/helpers` | 81.00 [80.84, 81.07] | 6.77 [6.41, 6.86] |
| `Session/cookies/crypto` | 92.46 [92.42, 92.56] | 5.61 [5.51, 5.67] |
| `Routing/URL generation` | 82.92 [82.83, 82.98] | 5.08 [4.93, 5.34] |
| `AR SQL/adapter` | 9.64 [9.53, 9.68] | 4.13 [4.08, 4.21] |
| `CSRF` | 9.54 [9.42, 9.61] | 2.94 [2.91, 3.21] |
| `AR attributes/casts` | 3.49 [3.21, 3.59] | 2.86 [2.63, 2.91] |
| `Events/logging` | 93.26 [93.21, 93.34] | 2.35 [2.30, 2.37] |
| `Controller dispatch/response` | 81.97 [81.88, 82.04] | 1.59 [1.49, 1.65] |
| `AR associations/preload` | 10.61 [10.47, 10.66] | 1.38 [1.28, 1.49] |
| `Callback machinery` | 95.03 [95.01, 95.17] | 1.17 [1.07, 1.20] |
| `Static-file miss` | 96.40 [96.38, 96.46] | 1.09 [1.07, 1.13] |
| `AR instantiation/model` | 6.13 [6.03, 6.22] | 0.86 [0.84, 0.89] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 0.75 [0.72, 0.76] |
| `Assets/importmap/CSP` | 4.17 [4.13, 4.25] | 0.55 [0.49, 0.61] |
| `App templates` | 65.97 [65.88, 66.09] | 0.43 [0.37, 0.49] |
| `JSON/serialization` | 0.24 [0.21, 0.25] | 0.24 [0.21, 0.25] |
| `App helpers` | 1.56 [1.52, 1.60] | 0.10 [0.06, 0.11] |
| `App controllers` | 77.11 [76.91, 77.15] | 0.03 [0.02, 0.05] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveSupport` | 96.37 [96.28, 96.45] | 20.87 [20.69, 20.96] |
| `ActionView` | 81.00 [80.84, 81.07] | 20.11 [19.84, 20.24] |
| `ActiveRecord` | 82.14 [82.07, 82.26] | 13.72 [13.50, 13.97] |
| `ActionDispatch` | 97.73 [97.72, 97.75] | 9.70 [9.39, 9.83] |
| `rack` | 99.99 [99.99, 99.99] | 9.27 [9.17, 9.51] |
| `i18n` | 5.99 [5.89, 6.09] | 5.85 [5.76, 5.90] |
| `ActionController` | 82.31 [82.26, 82.37] | 4.93 [4.76, 5.09] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 4.47 [4.37, 4.64] |
| `uri` | 2.71 [2.64, 2.76] | 2.71 [2.64, 2.76] |
| `ActiveModel` | 6.29 [6.11, 6.44] | 2.59 [2.54, 2.71] |
| `concurrent-ruby` | 2.64 [2.48, 2.98] | 2.09 [1.97, 2.37] |
| `base64` | 0.69 [0.65, 0.79] | 0.65 [0.60, 0.71] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activesupport-8.1.4/lib/active_support` | 96.37 [96.28, 96.45] | 20.87 [20.69, 20.96] |
| `GEM/actionview-8.1.4/lib/action_view` | 81.00 [80.84, 81.07] | 20.11 [19.84, 20.24] |
| `GEM/activerecord-8.1.4/lib/active_record` | 82.14 [82.07, 82.26] | 13.65 [13.42, 13.88] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 97.73 [97.72, 97.75] | 9.70 [9.39, 9.83] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.99, 99.99] | 9.27 [9.17, 9.51] |
| `GEM/actionpack-8.1.4/lib/action_controller` | 82.25 [82.20, 82.32] | 4.42 [4.28, 4.53] |
| `GEM/i18n-1.15.2/lib/i18n` | 5.36 [5.23, 5.45] | 4.33 [4.09, 4.41] |
| `RUBY/openssl/hmac.rb` | 2.76 [2.62, 2.85] | 2.76 [2.62, 2.85] |
| `GEM/uri-1.1.2/lib/uri` | 2.71 [2.64, 2.76] | 2.71 [2.64, 2.76] |
| `GEM/activemodel-8.1.4/lib/active_model` | 6.29 [6.11, 6.44] | 2.59 [2.54, 2.71] |

## starter

Equal shape weights: starter-dashboard-html, starter-dashboard-json.

**Descriptive: at least one constituent cohort is rejected.**

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `Rack/middleware/request` | 97.73 [97.72, 97.77] | 19.57 [19.53, 19.70] |
| `AS utilities/I18n/time` | 94.47 [94.42, 94.50] | 17.47 [17.33, 17.69] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 9.34 [9.19, 9.53] |
| `Session/cookies/crypto` | 88.82 [88.77, 88.87] | 6.90 [6.80, 6.93] |
| `AR query/relation` | 66.64 [66.56, 66.67] | 6.70 [6.57, 6.83] |
| `AR SQL/adapter` | 13.28 [13.18, 13.40] | 6.58 [6.42, 6.68] |
| `Inertia props/config/render` | 72.58 [72.42, 72.64] | 6.07 [5.97, 6.09] |
| `SSR HTTP client` | 6.30 [6.26, 6.33] | 6.05 [6.01, 6.07] |
| `AR attributes/casts` | 4.66 [4.58, 4.75] | 3.33 [3.26, 3.42] |
| `Events/logging` | 89.90 [89.86, 89.95] | 2.16 [2.10, 2.20] |
| `Callback machinery` | 92.69 [92.62, 92.74] | 1.84 [1.76, 1.92] |
| `Controller dispatch/response` | 66.73 [66.71, 66.86] | 1.73 [1.67, 1.84] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 1.56 [1.52, 1.60] |
| `Static-file miss` | 94.19 [94.12, 94.22] | 1.54 [1.50, 1.58] |
| `JSON/serialization` | 1.53 [1.49, 1.57] | 1.53 [1.49, 1.57] |
| `Rendering/lookup/helpers` | 65.44 [65.41, 65.56] | 1.50 [1.41, 1.56] |
| `CSRF` | 3.34 [3.21, 3.38] | 1.11 [1.06, 1.16] |
| `Buffers/escaping` | 1.11 [1.09, 1.14] | 0.97 [0.94, 1.02] |
| `AR associations/preload` | 11.58 [11.54, 11.66] | 0.93 [0.85, 1.02] |
| `AR instantiation/model` | 6.70 [6.66, 6.75] | 0.84 [0.80, 0.86] |
| `View helpers/tags/forms` | 1.35 [1.31, 1.38] | 0.82 [0.77, 0.82] |
| `Assets/importmap/CSP` | 2.01 [1.99, 2.05] | 0.81 [0.76, 0.83] |
| `Routing/URL generation` | 67.83 [67.77, 67.86] | 0.53 [0.50, 0.61] |
| `App controllers` | 26.53 [26.46, 26.57] | 0.05 [0.04, 0.07] |
| `App templates` | 3.74 [3.70, 3.77] | 0.05 [0.04, 0.08] |
| `App models` | 11.47 [11.44, 11.55] | 0.01 [0.00, 0.01] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveSupport` | 94.51 [94.48, 94.54] | 24.32 [24.05, 24.57] |
| `rack` | 99.99 [99.98, 100.00] | 16.83 [16.79, 17.01] |
| `ActiveRecord` | 67.13 [67.05, 67.17] | 14.16 [14.08, 14.23] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 9.00 [8.96, 9.19] |
| `ActionDispatch` | 96.27 [96.25, 96.35] | 7.90 [7.61, 8.06] |
| `inertia_rails` | 72.58 [72.42, 72.64] | 6.07 [5.97, 6.09] |
| `uri` | 4.34 [4.24, 4.43] | 4.34 [4.24, 4.43] |
| `ActiveModel` | 5.29 [5.27, 5.41] | 3.53 [3.41, 3.56] |
| `ActionController` | 66.92 [66.89, 67.09] | 3.11 [2.95, 3.22] |
| `ActionView` | 65.44 [65.41, 65.56] | 2.84 [2.76, 2.86] |
| `concurrent-ruby` | 2.44 [2.37, 2.47] | 1.68 [1.63, 1.73] |
| `sqlite3` | 1.35 [1.30, 1.42] | 1.34 [1.27, 1.38] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activesupport-8.1.4/lib/active_support` | 94.51 [94.48, 94.54] | 24.32 [24.05, 24.57] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.98, 100.00] | 16.83 [16.79, 17.01] |
| `GEM/activerecord-8.1.4/lib/active_record` | 67.13 [67.05, 67.17] | 14.02 [13.96, 14.11] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 96.27 [96.25, 96.35] | 7.90 [7.61, 8.06] |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails` | 72.58 [72.42, 72.64] | 6.03 [5.94, 6.07] |
| `GEM/uri-1.1.1/lib/uri` | 4.34 [4.24, 4.43] | 4.34 [4.24, 4.43] |
| `RUBY/net/http.rb` | 6.29 [6.25, 6.32] | 3.55 [3.54, 3.59] |
| `GEM/activemodel-8.1.4/lib/active_model` | 5.29 [5.27, 5.41] | 3.53 [3.41, 3.56] |
| `GEM/actionview-8.1.4/lib/action_view` | 65.44 [65.41, 65.56] | 2.84 [2.76, 2.86] |
| `GEM/actionpack-8.1.4/lib/action_controller` | 66.85 [66.81, 67.00] | 2.38 [2.24, 2.48] |

## pingcrm

Equal shape weights: pingcrm-organizations-html.

**Descriptive: at least one constituent cohort is rejected.**

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AS utilities/I18n/time` | 48.38 [48.17, 48.54] | 15.74 [15.54, 15.96] |
| `AR query/relation` | 85.20 [85.09, 85.30] | 14.86 [14.61, 15.13] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 9.94 [9.77, 10.24] |
| `Rack/middleware/request` | 98.71 [98.67, 98.74] | 9.38 [9.36, 9.42] |
| `AR SQL/adapter` | 15.71 [15.59, 15.73] | 6.78 [6.58, 6.82] |
| `AR attributes/casts` | 8.36 [8.26, 8.69] | 6.22 [6.01, 6.39] |
| `Authorization` | 18.83 [18.64, 18.92] | 6.03 [5.89, 6.16] |
| `Inertia props/config/render` | 94.82 [94.77, 94.86] | 5.52 [5.34, 5.58] |
| `Rendering/lookup/helpers` | 85.06 [84.99, 85.12] | 3.83 [3.78, 3.92] |
| `JSON/serialization` | 14.32 [14.22, 14.35] | 3.69 [3.57, 3.84] |
| `Session/cookies/crypto` | 93.54 [93.51, 93.57] | 3.54 [3.43, 3.60] |
| `Events/logging` | 94.50 [94.47, 94.53] | 2.17 [2.14, 2.24] |
| `Controller dispatch/response` | 85.78 [85.67, 85.84] | 1.77 [1.72, 1.81] |
| `View helpers/tags/forms` | 2.95 [2.85, 3.05] | 1.70 [1.61, 1.75] |
| `Buffers/escaping` | 1.95 [1.88, 1.97] | 1.63 [1.60, 1.66] |
| `AR instantiation/model` | 2.73 [2.65, 2.80] | 1.31 [1.27, 1.39] |
| `CSRF` | 3.46 [3.39, 3.50] | 1.22 [1.20, 1.27] |
| `Callback machinery` | 95.02 [94.95, 95.05] | 0.91 [0.84, 1.00] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 0.90 [0.84, 0.92] |
| `Assets/importmap/CSP` | 5.68 [5.58, 5.74] | 0.85 [0.78, 0.89] |
| `Static-file miss` | 96.84 [96.80, 96.87] | 0.83 [0.77, 0.86] |
| `AR associations/preload` | 5.90 [5.86, 5.96] | 0.54 [0.51, 0.60] |
| `Routing/URL generation` | 86.38 [86.33, 86.42] | 0.33 [0.31, 0.35] |
| `App controllers` | 49.21 [49.15, 49.31] | 0.12 [0.09, 0.13] |
| `App models` | 2.30 [2.26, 2.34] | 0.12 [0.09, 0.15] |
| `App templates` | 10.28 [10.22, 10.34] | 0.11 [0.10, 0.14] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveRecord` | 85.43 [85.33, 85.55] | 24.47 [24.21, 24.71] |
| `ActiveSupport` | 95.26 [95.21, 95.35] | 20.95 [20.59, 21.20] |
| `rack` | 99.99 [99.98, 100.00] | 6.34 [6.26, 6.42] |
| `ActionView` | 85.06 [84.99, 85.12] | 6.04 [5.89, 6.10] |
| `cancancan` | 18.83 [18.64, 18.92] | 6.03 [5.89, 6.16] |
| `ActionDispatch` | 98.13 [98.09, 98.19] | 5.76 [5.61, 5.94] |
| `inertia_rails` | 94.82 [94.77, 94.86] | 5.52 [5.35, 5.60] |
| `ActiveModel` | 12.01 [11.91, 12.32] | 5.51 [5.43, 5.75] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 3.64 [3.56, 3.79] |
| `ActionController` | 85.88 [85.78, 85.93] | 3.03 [2.98, 3.11] |
| `jbuilder` | 13.46 [13.42, 13.54] | 2.91 [2.77, 2.99] |
| `concurrent-ruby` | 2.88 [2.78, 2.96] | 2.59 [2.55, 2.71] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activerecord-8.1.4/lib/active_record` | 85.43 [85.33, 85.55] | 21.07 [20.77, 21.32] |
| `GEM/activesupport-8.1.4/lib/active_support` | 95.26 [95.21, 95.35] | 20.95 [20.59, 21.20] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.98, 100.00] | 6.34 [6.26, 6.42] |
| `GEM/actionview-8.1.4/lib/action_view` | 85.06 [84.99, 85.12] | 6.04 [5.89, 6.10] |
| `GEM/cancancan-3.7.0/lib/cancan` | 18.83 [18.64, 18.92] | 6.03 [5.89, 6.16] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 98.13 [98.09, 98.19] | 5.76 [5.61, 5.94] |
| `GEM/activemodel-8.1.4/lib/active_model` | 12.01 [11.91, 12.32] | 5.51 [5.43, 5.75] |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails` | 94.82 [94.77, 94.86] | 5.50 [5.33, 5.58] |
| `GEM/activerecord-8.1.4/lib/arel` | 4.43 [4.22, 4.48] | 3.44 [3.31, 3.49] |
| `GEM/concurrent-ruby-1.3.8/lib/concurrent-ruby` | 2.88 [2.78, 2.96] | 2.59 [2.55, 2.71] |

## Cross-app self-cost ranking

Equal weight per available primary app (blog, starter, pingcrm), then per measured route/format. Campfire is excluded.

**Descriptive: includes a rejected cohort; not an accepted aggregate.**

| Rank | Subsystem | Mean self % [95% CI] |
|---:|---|---:|
| 1 | AS utilities/I18n/time | 16.76 [16.68, 16.83] |
| 2 | Rack/middleware/request | 13.52 [13.46, 13.57] |
| 3 | AR query/relation | 9.48 [9.34, 9.73] |
| 4 | Other gems/stdlib/app | 9.03 [9.02, 9.14] |
| 5 | AR SQL/adapter | 5.81 [5.77, 5.85] |
| 6 | Session/cookies/crypto | 5.33 [5.32, 5.35] |
| 7 | View helpers/tags/forms | 4.76 [4.71, 4.82] |
| 8 | AR attributes/casts | 4.15 [4.01, 4.19] |
| 9 | Rendering/lookup/helpers | 4.01 [3.94, 4.06] |
| 10 | Inertia props/config/render | 3.85 [3.79, 3.88] |
| 11 | Buffers/escaping | 3.18 [3.14, 3.23] |
| 12 | Events/logging | 2.23 [2.21, 2.24] |

<!-- END GENERATED HOTSPOT TABLES -->
