# Whole-request hotspot map — interpreter, Lowrail off

2026-10-20. **Measurement only: no pass or runtime implementation.**
Rails 8.1.4 is primary; Campfire's Rails 8.2 alpha is supplementary. Results
describe the production fixtures and selected GET routes, **not a traffic mix**
or a production latency profile. Existing allocation evidence is in
[allocations.md](allocations.md); no allocation census is repeated here.

**First priority table:** blog `/articles/1`, Starter dashboard HTML/JSON and
PingCRM organizations HTML. Blog show and Starter JSON pass all controls;
Starter HTML and PingCRM are diagnostic/rejected, for the reasons below.
All ten primary request-shape cohorts are now complete: seven accepted,
three rejected. All three blog routes, both Starter JSON routes and both
Redprints routes pass; Starter dashboard HTML and both PingCRM routes do not.
The four-primary-app ranking is **descriptive**, because it includes those
rejections, not a newly accepted aggregate. Secondary Campfire coverage is
limited by the sampler failures recorded below: its JSON map is diagnostic,
both HTML maps are unavailable, and **no Campfire cohort is accepted**.

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

The separate PingCRM contacts JSON cohort is also **rejected for ordinary
A/A**: total [−0.0514%, −0.0014%] and no-GC [−0.0714%, −0.0147%] exclude zero.
Sampler A/A, both-arm fidelity, all heaps, JIT state and capture/overflow gates
pass. The small control discrepancy is retained, not explained away or rerun.
Both PingCRM routes and their aggregate are therefore diagnostic.

Campfire room and sidebar HTML are **unavailable / tool-rejected**, not noisy
accepted maps. In each, trace A aborts in Callgrind `threads.c:247`,
`vgCallgrind_post_signal`, on `sigNum == vgCallgrind_current_state.sig`;
no full round was aggregated. The surviving trace B was cancelled after each
failure, with its logs kept. No brk overflow appears. The failure stack includes
MRI `fiber_setcontext` and Enumerator `zip`. The original focused Fiber/zip
probe did not reproduce it; that negative control is retained. Subsequent
authorized single-run controls reproduce the assertion with **both the exact
sampler engine and stock Callgrind 3.19.0**, establishing an upstream
signal/Fiber-switch tool boundary, not a sampler-patch-only defect (below).
The ordinary off-A room worker completed all four windows without the assertion.
This differs from the reproduced shared-worker brk exposure and does not
establish that ordinary non-sampling `lowrail bench` workers have this failure.
The assertion is not suppressed, and no partial arm or HTML result is salvaged.
The separately declared bot JSON route does not replace or retry either HTML cohort;
secondary coverage excludes the unavailable HTML requests.

Campfire bot JSON completed its six scheduled rounds and is **rejected for
capture integrity**: 12 of 858,820 captures are empty. Ordinary and sampler
A/A, all heaps, both-arm fidelity and overflow gates pass; maximum lag is
1,107 Ir. Empty stacks enter the client/seam fallback only to retain the
partition, not as evidence that their unknown work is client overhead.
Finishing the declared rounds supplies diagnostic uncertainty, not a rescue
of a cohort whose capture gate already failed. No Campfire result is retried.
Its large residual is not wholly opaque: URI alone owns **18.97 [18.89,
19.02]%** of the request, within the **26.82%** other-gem/stdlib bucket.
These prefix-only captures do not establish which URI callers dominate; do
not import Starter's cookie diagnosis into Campfire or infer an importmap
saving from a JSON route. Association/query shape and URI callers are app
investigation leads, not accepted optimization budgets or an HTML profile.

### Campfire sampler boundary: untimed diagnosis

**No replacement cohort, sample reassignment, app patch or runtime/default
change.** A native census with a thread-directed POSIX SIGPROF timer records
the current Ruby execution context without Fiber hooks: 10,000 iterations,
20,000 ns CLOCK_MONOTONIC / SIGEV_THREAD_ID one-shot, rearmed in the handler.
On the pinned Ruby 4.0.7 binary, Array zip has **0/5,409 empty samples**;
Enumerable zip has **22/18,588**, and explicit Fiber resume/yield has
**130/15,216**. Every empty is on a **child EC**, none on the root EC or a
foreign native thread. Under `--tool=none`, 1,000 iterations of the same timer
give Array **0/70**, Enumerable **0/1,044**, Fiber **1/1,136**, also child EC.
That run's `none-amd64-linux` engine SHA-256 is
`bf64a244e6e91cbe2f3730a6e03c5026bf96a2dcd2350696fbc8d8b8bc425c1d`;
the native run has no Valgrind engine. Both use Ruby binary SHA-256
`fa450b858aa41a97d0f839a4fce6a4a33e07c5da0dc7374330bbf58e39bfc895`.
These are untimed synthetic observations, not instruction budgets. The
historical JSON empties did not record EC identity: this mechanism is present,
but their individual attribution remains unknown; all 12 remain rejected.

Two separately authorized, single untimed Callgrind invocations use the same
10,000-iteration explicit-Fiber body (64 yield/resume pairs and checked
results), with instrumentation START/STOP, interpreter, no Rails/server:

| Tool / SHA-256 | Signal delivery | Result |
|---|---|---|
| Exact retained sampler engine `bab749e091c31c770a292f7261a322c6ef7e156ae4881d74ec71ffeadc7d04ac`; patch `6bed296abf1c40e0deb17c066d72d50bc118af5b5121c7741aba1aff4984fc92` | Existing instruction-triggered sampler; seed 41231, no wall timer | Exit 1, `threads.c:247`, valid rt_sigreturn at `fiber_setcontext` 0x523bba; BB#280033 |
| **Stock**, unpatched Callgrind 3.19.0 engine `6d59099f65e4ec17a39f54b406d7424a1e7feb89d8dae5b335969619b1ee770d`; verified source archive `dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02` | POSIX one-shot timer above; **not the instruction sampler** | Exit 1, same assertion/address after valid rt_sigreturn; BB#114112337 |

The schedules differ; counts or failure positions are not comparable. Stock's
positive result establishes the upstream boundary. Source inspection finds
both the core's rt_sigreturn callback and Callgrind's shadow-stack-bottom
post-signal heuristic; premature heuristic unwinding across a stack switch
is a **hypothesis**, not a traced internal-state cause. No assertion is
suppressed or speculative sampler fix shipped. A detailed upstream report
draft and reproducer are retained **locally only**; nothing is submitted.
The brk-only benchmark tool is unchanged and not implicated by these
signal-instrumentation reproductions.

This is not just an unused synthetic path. A separate native TracePoint
census of five warmed requests per route, using a private fixture database,
unchanged Campfire `af4dd9f` and its **Rails 8.2.0.alpha `e3d5c56` lock**,
returns HTTP 200 for all JSON/room/sidebar requests. It observes
`ActiveRecord::Key::Single` (includes Enumerable) calling `zip` over another
Key, with `Enumerator#next` at `active_record/key.rb:27`. The real callers are
`AssociationScope#last_chain_scope` / `#next_chain_scope`
(`association_scope.rb:66/92`), and room rendering also takes
`ForeignAssociation#set_owner_attributes` (`foreign_association.rb:30`),
through Action Text's rich-text body construction. The census sees
**3/8/5 Enumerable zip calls and 3/8/5 Enumerator next calls per
JSON/room/sidebar request**; sidebar additionally has six Array zip calls.
These are companion native observations, not counts recovered from the old
windows. The retained HTML native stacks already contain
`get_next_values → enumerator_next → call_next → zip_i → enum_zip` alongside
`fiber_setcontext`, linking the failed requests to this boundary. No Puma,
ActionCable or app timer is required to reproduce it, and none is assigned
as its cause. Future coverage needs a certified sampler/tool solution for
these Fiber transitions; dropping empties or changing app associations is
not a measurement fix. Existing Campfire cohorts remain unavailable/rejected.

Publishing the method addendum required the authorized pull/rebase. Main had
meanwhile changed `heap_windows.rb` and `request_pairs.rb` for multi-pool/JIT
support and heap-preparation seams. The paused blog-edit attempt had four
aggregated rounds and PingCRM contacts three. Both were **terminated before
resuming**, rejected for source integrity, and retained with old/new source
hashes; no worker from them is reused. Completed blog index and detail cohorts
had finished, and all their measured-source hashes were verified **before**
the pull. Their completed verdicts remain valid for those exact source pins.
The unfinished shapes get separately declared finite new-source cohorts, not
a retry after a failed A/A/fidelity gate. They retain Ruby 4.0.7, the same five
floors, windows, fixture and sampler tool. The export distinguishes the
source pins; do not read an app aggregate spanning these pins as a controlled
before/after benchmark of the shared-worker refactor. Each exported provenance
entry names its completed shapes and cohort root; interrupted attempts carry
that root too, so old/new source pins are not ambiguously pooled.

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

The blog fixture sends **no incoming cookie**. `Rack::MockRequest` does not
carry response cookies into later requests, so warming does not turn it into
a returning browser session. Blog token/session/cookie costs include this
new-session shape. Authenticated Inertia/Campfire routes replay their fixed
private incoming headers instead; outgoing cookie refresh/commit still runs.
These are fixture-specific request shapes, not a cross-app session-policy
experiment or an estimate of a deployment's returning-user traffic.

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
Use the [allocation study's copy/update procedure](allocations.md#reproduction)
with that new directory name; refuse any unrelated dependency/source change.
The measured lock SHA-256 is
`1d14f5e2979e4693fa770010c26f93d003e7c8dcc54d32995ce2074277bd8654`.
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
| AS utilities/I18n/time | **Guarded caller-specific pass / upstream** for Inertia config extraction; **sealed endpoint** for fixed render callers | Starter's dominant Hash extraction is mostly outside the action/render seal boundary; see the detail addendum. Preserve live locale, defaults, type conversion and mutable tables, not request-value caches. Overlaps **inertia/config_bind**, **Whole compiled ERB specialization**, **CurrentAttributes default tuple iteration**, **Literal inflection plans**. Their narrow eligible pools do not cover this whole bucket. |
| Rack/middleware/request | **Upstream Rails/Rack** | Retain the real envelope and state/security/exception pipeline, rather than infer a large middleware-removal budget from inclusive cost. Overlaps **Replacement-layer ceiling, Rails 8.1.4 blog index/show** and **Remaining controller/params/response interpretation**. **Upstream static miss candidates** is an adjacent, separately counted bucket, not an extra saving inside this row. |
| Other gems/stdlib/app | **App recommendation: inspect the named gem/prefix before changing code** | This heterogeneous residual includes URI/concurrency/stdlib machinery, not one certifiable pass. There is **no exact existing residual-wide decision row**. **Literal inflection plans** and the two **Net::HTTP** allocation follow-ups overlap only their named mechanisms, not the rest. Never claim the residual is all avoidable VM dispatch. |
| AR query/relation | **Guarded pass**, only for a proven fixed query shape | Keep current scopes, authorization, binds, quoting, ordered SQL, connection/shard facts and notifications. Overlaps **Fixed query-shape allocation plans**, **AR plans, preload plans** and **Escaping AR app-chain plans**. A large source bucket does not reopen the parked instantiate pass or price database-server work. |
| AR associations/preload | **App recommendation** to inspect the actual association/query shape; **guarded pass** only for a certified fixed plan | Overlaps **AR plans, preload plans** and **Escaping AR app-chain plans**. Keep live association state, scopes, authorization, reflection/key/connection facts and invalidation; neither result caching nor an N+1 diagnosis follows from inclusive cost alone. Campfire's 10.72% self is diagnostic, not a pass ceiling. |
| Session/cookies/crypto | **Upstream Rails**, not a boot-time session/result cache | Fresh authenticated state and cryptographic work remain necessary. There is **no existing standalone session pass row**; this overlaps the retained session/cookie boundary in **Replacement-layer ceiling, Rails 8.1.4 blog index/show** and **Remaining controller/params/response interpretation**. GET-only fixtures do not certify CSRF verification or writes. |
| View helpers/tags/forms; buffers/rendering | **Sealed endpoint** for compiled caller structure; **upstream Rails** for a general primitive | Preserve helpers, escaping, fresh buffers, form model/state and events. Overlaps **Two tiers: guarded (default) and sealed (opt-in)**, **endpoint/action**, **Compiled form/literal-tag intermediates**, **Tag/form attribute component**, **SafeBuffer/OutputBuffer interpretation**, and quarantined **Source view/link_to and route/path**. No safety refusal or quarantine is reversed. |
| Inertia props/config/render | **Guarded pass**, with net guard cost measured separately | Preserve per-request props, partial/deferred/once/rescue behavior, iterator identity and post-app-code checks. Overlaps **inertia/config_bind**, **inertia/props**, **Inertia prop path scaffolding** and **Inertia metadata try dispatch**. Existing rejected final-runtime props evidence is not upgraded by a hotspot map. |
| SSR HTTP client | **App recommendation**, including separate Node/IPC/latency profiling | The denominator excludes Node CPU and waiting, so this is Ruby protocol/setup work, not an SSR-removal budget. Overlaps **Net::HTTP SSR setter discovery** and **Net::HTTP header capitalization**. A future guarded component can target only those certified intermediates, never cache personalized SSR output. |
| AR SQL/adapter | **Upstream Rails/adapter** | Native client decoding/type work is real work; server CPU is absent. Overlaps **PostgreSQL type-map tuple dispatch** and **Fixed query-shape allocation plans**. Keep result rows, casts, adapter extensions and connection/OID generations; inspect query count/data shape separately in the app. |
| AR attributes/casts | **Upstream Rails**, or a narrow guarded component only after pricing | Retain missing/default/cached-nil/custom-type/dirty-tracking behavior and live values. Overlaps **AttributeSet reads/casting**, **AttributeSet key unions**, and only actual matching sites of **StoreModel scalar-read forwarding**. The earlier combined direct-ivar prototype lost on blog show; this source-owned pool is not removable credit or permission to bypass casts. |
| JSON/serialization | **Sealed endpoint**, only for fixed serializer caller structure; **app recommendation** for redundant payload work | Preserve live getters, authorization, custom `as_json`/`to_json`, escaping and output shape. Overlaps **Fixed-shape serialization**; its narrow PingCRM estimate is not an all-app ceiling. The existing Redprints Alba key-plan prototype lost, so a large Alba/JSON bucket does not reopen that implementation or imply equivalent removable work. See the serialization addendum below. |

<!-- BEGIN GENERATED HOTSPOT TABLES -->

## Cohort controls

Rejected means the entire request-shape cohort is diagnostic; it is not rerun or salvaged.

| Request shape | Total / no-GC M Ir | Baseline A/A CI %, total / no-GC | Heap | Sampler A/A | Fidelity | Capture | Verdict |
|---|---:|---|---|---|---|---|---|
| blog-edit-html | 6.092 / 6.093 | [-0.0106, +0.0649] / [-0.0230, +0.0322] | pass | pass | pass | pass | **accepted** |
| blog-index-html | 9.101 / 9.101 | [-0.0380, +0.0600] / [-0.0505, +0.0512] | pass | pass | pass | pass | **accepted** |
| blog-show-html | 8.746 / 8.749 | [-0.0727, +0.0248] / [-0.0619, +0.0033] | pass | pass | pass | pass | **accepted** |
| starter-dashboard-html | 8.518 / 8.518 | [-0.0280, +0.0441] / [-0.0439, +0.0280] | pass | pass | FAIL | pass | **REJECTED** |
| starter-dashboard-json | 5.140 / 5.142 | [-0.0254, +0.0812] / [-0.0374, +0.0224] | pass | pass | pass | pass | **accepted** |
| starter-profile-json | 5.264 / 5.264 | [-0.1282, +0.0844] / [-0.0662, +0.0198] | pass | pass | pass | pass | **accepted** |
| pingcrm-contacts-json | 13.243 / 13.246 | [-0.0514, -0.0014] / [-0.0714, -0.0147] | pass | pass | pass | pass | **REJECTED** |
| pingcrm-organizations-html | 11.960 / 11.959 | [-0.0080, +0.0263] / [+0.0128, +0.0421] | pass | pass | pass | pass | **REJECTED** |
| redprints-proposal-json | 8.668 / 8.670 | [-0.0255, +0.0509] / [-0.0229, +0.0462] | pass | pass | pass | pass | **accepted** |
| redprints-proposals-html | 15.152 / 15.152 | [-0.0081, +0.0266] / [-0.0141, +0.0221] | pass | pass | pass | pass | **accepted** |
| campfire-json-uncached | 47.222 / 46.552 | [-0.0072, +0.0330] / [-0.0024, +0.0335] | pass | pass | pass | FAIL | **REJECTED** |

### Interrupted cohorts — rejected, no partial salvage

| Attempt / shape | Aggregated rounds | Rejection |
|---|---:|---|
| lowrail-hotspots-rest-a / blog-edit-html | 4 | Source-integrity rejection: paused after four aggregated rounds; pull --rebase changed bench/heap_windows.rb and bench/request_pairs.rb before remaining workers. Terminated without resuming; no mixed-source or partial-arm salvage. |
| lowrail-hotspots-rest-b / pingcrm-contacts-json | 3 | Source-integrity rejection: paused after three aggregated rounds; pull --rebase changed bench/heap_windows.rb and bench/request_pairs.rb before remaining workers. Terminated without resuming; no mixed-source or partial-arm salvage. |
| lowrail-hotspots-finite / blog-index-html | 5 | brk segment overflow; interrupted, no partial-arm salvage |
| lowrail-hotspots-campfire-room / campfire-room-uncached | 0 | Tool failure: trace-A aborted on Callgrind threads.c:247 vgCallgrind_post_signal assertion (sigNum == vgCallgrind_current_state.sig). Zero complete rounds; no partial-arm salvage. Surviving trace-B cancelled after the failure. |
| lowrail-hotspots-campfire-other / campfire-sidebar-uncached | 0 | Tool failure: trace-A aborted on the same Callgrind threads.c:247 vgCallgrind_post_signal assertion as the room shape. Zero complete rounds; surviving trace-B cancelled, no partial-arm salvage. |

## Route/format detail

Five largest self costs per request shape; intervals include all six rounds.

| Request shape | Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---|---:|---:|
| blog-edit-html | AS utilities/I18n/time | 94.62 [94.52, 94.68] | 24.04 [23.75, 24.18] |
| blog-edit-html | Rack/middleware/request | 98.18 [98.12, 98.21] | 13.69 [13.37, 13.94] |
| blog-edit-html | View helpers/tags/forms | 41.66 [41.50, 42.01] | 12.43 [12.04, 12.62] |
| blog-edit-html | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 9.56 [9.44, 9.62] |
| blog-edit-html | Rendering/lookup/helpers | 75.13 [74.89, 75.21] | 6.65 [6.44, 6.92] |
| blog-index-html | Rack/middleware/request | 98.79 [98.77, 98.85] | 12.20 [12.03, 12.29] |
| blog-index-html | AS utilities/I18n/time | 96.56 [96.49, 96.63] | 11.62 [11.48, 11.78] |
| blog-index-html | AR query/relation | 81.68 [81.57, 81.73] | 10.30 [10.15, 10.81] |
| blog-index-html | View helpers/tags/forms | 14.37 [14.25, 14.79] | 8.17 [8.10, 8.35] |
| blog-index-html | Rendering/lookup/helpers | 80.92 [80.80, 80.98] | 7.64 [7.43, 7.76] |
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
| starter-profile-json | AS utilities/I18n/time | 92.96 [92.89, 93.02] | 24.65 [24.47, 25.10] |
| starter-profile-json | Rack/middleware/request | 97.05 [96.97, 97.08] | 13.25 [12.96, 13.63] |
| starter-profile-json | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 10.01 [9.90, 10.13] |
| starter-profile-json | AR SQL/adapter | 16.08 [15.89, 16.22] | 8.16 [7.91, 8.46] |
| starter-profile-json | AR query/relation | 65.74 [65.58, 65.83] | 8.09 [7.89, 8.54] |
| pingcrm-contacts-json (REJECTED) | AR query/relation | 86.49 [86.42, 86.53] | 18.60 [18.28, 18.79] |
| pingcrm-contacts-json (REJECTED) | AS utilities/I18n/time | 37.68 [37.59, 37.99] | 12.65 [12.52, 12.96] |
| pingcrm-contacts-json (REJECTED) | AR attributes/casts | 13.62 [13.56, 13.92] | 10.47 [10.32, 10.64] |
| pingcrm-contacts-json (REJECTED) | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 9.22 [9.06, 9.48] |
| pingcrm-contacts-json (REJECTED) | AR SQL/adapter | 20.84 [20.73, 21.00] | 8.96 [8.75, 9.16] |
| pingcrm-organizations-html (REJECTED) | AS utilities/I18n/time | 48.38 [48.17, 48.54] | 15.74 [15.54, 15.96] |
| pingcrm-organizations-html (REJECTED) | AR query/relation | 85.20 [85.09, 85.30] | 14.86 [14.61, 15.13] |
| pingcrm-organizations-html (REJECTED) | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 9.94 [9.77, 10.24] |
| pingcrm-organizations-html (REJECTED) | Rack/middleware/request | 98.71 [98.67, 98.74] | 9.38 [9.36, 9.42] |
| pingcrm-organizations-html (REJECTED) | AR SQL/adapter | 15.71 [15.59, 15.73] | 6.78 [6.58, 6.82] |
| redprints-proposal-json | AR query/relation | 78.60 [78.55, 78.75] | 22.23 [21.78, 22.60] |
| redprints-proposal-json | AS utilities/I18n/time | 95.29 [95.26, 95.41] | 16.22 [16.01, 16.44] |
| redprints-proposal-json | AR SQL/adapter | 24.69 [24.61, 24.74] | 11.30 [11.12, 11.50] |
| redprints-proposal-json | Rack/middleware/request | 98.20 [98.17, 98.25] | 9.16 [9.10, 9.48] |
| redprints-proposal-json | Other gems/stdlib/app | 100.00 [100.00, 100.00] | 6.85 [6.67, 6.98] |
| redprints-proposals-html | AS utilities/I18n/time | 97.40 [97.35, 97.45] | 16.52 [16.26, 16.69] |
| redprints-proposals-html | AR attributes/casts | 22.59 [22.32, 22.74] | 14.21 [14.10, 14.36] |
| redprints-proposals-html | Rack/middleware/request | 99.02 [98.99, 99.05] | 10.01 [9.85, 10.17] |
| redprints-proposals-html | JSON/serialization | 55.37 [55.33, 55.40] | 9.68 [9.43, 9.80] |
| redprints-proposals-html | AR query/relation | 86.33 [86.29, 86.38] | 7.78 [7.70, 7.82] |
| campfire-json-uncached (REJECTED) | Other gems/stdlib/app | 98.56 [98.56, 98.57] | 26.82 [26.64, 26.93] |
| campfire-json-uncached (REJECTED) | AR query/relation | 93.92 [93.89, 93.94] | 17.70 [17.57, 17.80] |
| campfire-json-uncached (REJECTED) | AR associations/preload | 42.11 [42.04, 42.12] | 10.72 [10.63, 10.78] |
| campfire-json-uncached (REJECTED) | AR SQL/adapter | 19.73 [19.68, 19.78] | 9.40 [9.36, 9.44] |
| campfire-json-uncached (REJECTED) | AS utilities/I18n/time | 97.79 [97.76, 97.82] | 7.59 [7.45, 7.68] |

## blog

Equal shape weights: blog-edit-html, blog-index-html, blog-show-html.

All constituent cohorts accepted.

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AS utilities/I18n/time` | 95.85 [95.78, 95.87] | 17.56 [17.40, 17.69] |
| `Rack/middleware/request` | 98.59 [98.55, 98.60] | 12.48 [12.35, 12.58] |
| `View helpers/tags/forms` | 28.66 [28.60, 28.90] | 10.80 [10.66, 10.90] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 8.14 [8.00, 8.23] |
| `Rendering/lookup/helpers` | 79.00 [78.92, 79.03] | 6.99 [6.91, 7.06] |
| `Buffers/escaping` | 19.70 [19.66, 19.74] | 6.68 [6.65, 6.72] |
| `AR query/relation` | 79.91 [79.86, 80.03] | 6.41 [6.33, 6.61] |
| `Session/cookies/crypto` | 91.48 [91.44, 91.52] | 5.02 [4.93, 5.08] |
| `AR SQL/adapter` | 9.55 [9.46, 9.64] | 4.57 [4.49, 4.63] |
| `Routing/URL generation` | 81.09 [80.98, 81.12] | 4.10 [4.00, 4.28] |
| `AR attributes/casts` | 3.36 [3.29, 3.50] | 2.77 [2.67, 2.85] |
| `Events/logging` | 92.36 [92.33, 92.39] | 2.65 [2.58, 2.66] |
| `CSRF` | 8.13 [8.06, 8.17] | 2.37 [2.30, 2.43] |
| `AR associations/preload` | 9.00 [8.97, 9.02] | 2.27 [2.25, 2.36] |
| `Controller dispatch/response` | 80.02 [79.95, 80.07] | 1.58 [1.57, 1.65] |
| `Static-file miss` | 95.93 [95.91, 95.96] | 1.29 [1.23, 1.30] |
| `Callback machinery` | 94.39 [94.35, 94.45] | 1.26 [1.21, 1.35] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 0.84 [0.82, 0.86] |
| `AR instantiation/model` | 5.15 [5.05, 5.18] | 0.81 [0.76, 0.83] |
| `Assets/importmap/CSP` | 4.77 [4.71, 4.79] | 0.65 [0.63, 0.66] |
| `App templates` | 63.07 [63.01, 63.22] | 0.43 [0.41, 0.46] |
| `JSON/serialization` | 0.24 [0.23, 0.26] | 0.24 [0.23, 0.26] |
| `App helpers` | 1.02 [1.00, 1.03] | 0.05 [0.04, 0.06] |
| `App controllers` | 74.58 [74.50, 74.63] | 0.05 [0.04, 0.05] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveSupport` | 95.88 [95.83, 95.91] | 21.30 [21.16, 21.47] |
| `ActionView` | 79.00 [78.92, 79.03] | 19.54 [19.29, 19.62] |
| `ActiveRecord` | 80.34 [80.23, 80.42] | 14.00 [13.89, 14.13] |
| `rack` | 99.99 [99.99, 99.99] | 10.03 [9.93, 10.17] |
| `ActionDispatch` | 97.42 [97.39, 97.45] | 9.12 [9.02, 9.17] |
| `i18n` | 6.17 [6.12, 6.20] | 5.98 [5.89, 6.03] |
| `ActionController` | 80.42 [80.35, 80.47] | 4.39 [4.28, 4.46] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 3.92 [3.90, 4.02] |
| `ActiveModel` | 6.02 [5.90, 6.15] | 2.60 [2.53, 2.67] |
| `uri` | 2.49 [2.44, 2.56] | 2.49 [2.44, 2.56] |
| `concurrent-ruby` | 2.99 [2.96, 3.10] | 2.39 [2.33, 2.50] |
| `sqlite3` | 0.99 [0.95, 1.05] | 0.97 [0.93, 1.02] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activesupport-8.1.4/lib/active_support` | 95.88 [95.83, 95.91] | 21.30 [21.16, 21.47] |
| `GEM/actionview-8.1.4/lib/action_view` | 79.00 [78.92, 79.03] | 19.54 [19.29, 19.62] |
| `GEM/activerecord-8.1.4/lib/active_record` | 80.34 [80.23, 80.42] | 13.21 [13.09, 13.31] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.99, 99.99] | 10.03 [9.93, 10.17] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 97.42 [97.39, 97.45] | 9.12 [9.02, 9.17] |
| `GEM/i18n-1.15.2/lib/i18n` | 5.43 [5.42, 5.48] | 4.39 [4.32, 4.45] |
| `GEM/actionpack-8.1.4/lib/action_controller` | 80.35 [80.29, 80.41] | 3.82 [3.71, 3.87] |
| `GEM/activemodel-8.1.4/lib/active_model` | 6.02 [5.90, 6.15] | 2.60 [2.53, 2.67] |
| `GEM/uri-1.1.2/lib/uri` | 2.49 [2.44, 2.56] | 2.49 [2.44, 2.56] |
| `GEM/concurrent-ruby-1.3.8/lib/concurrent-ruby` | 2.99 [2.96, 3.10] | 2.39 [2.33, 2.50] |

## starter

Equal shape weights: starter-dashboard-html, starter-dashboard-json, starter-profile-json.

**Descriptive: at least one constituent cohort is rejected.**

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AS utilities/I18n/time` | 93.96 [93.93, 94.00] | 19.90 [19.74, 20.09] |
| `Rack/middleware/request` | 97.50 [97.47, 97.54] | 17.54 [17.36, 17.58] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 9.58 [9.46, 9.67] |
| `AR query/relation` | 66.32 [66.28, 66.37] | 7.20 [7.11, 7.27] |
| `Session/cookies/crypto` | 87.92 [87.90, 88.00] | 7.17 [7.07, 7.29] |
| `AR SQL/adapter` | 14.23 [14.13, 14.28] | 7.12 [6.93, 7.24] |
| `Inertia props/config/render` | 74.07 [73.94, 74.13] | 6.68 [6.57, 6.76] |
| `SSR HTTP client` | 4.20 [4.17, 4.22] | 4.03 [4.01, 4.04] |
| `AR attributes/casts` | 4.95 [4.82, 4.99] | 3.52 [3.45, 3.59] |
| `Events/logging` | 89.07 [88.99, 89.13] | 2.04 [2.00, 2.07] |
| `Callback machinery` | 92.08 [92.04, 92.14] | 2.00 [1.94, 2.07] |
| `Controller dispatch/response` | 66.49 [66.37, 66.51] | 1.78 [1.76, 1.85] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 1.72 [1.66, 1.76] |
| `Static-file miss` | 93.68 [93.66, 93.74] | 1.66 [1.61, 1.71] |
| `JSON/serialization` | 1.45 [1.39, 1.49] | 1.45 [1.39, 1.49] |
| `Rendering/lookup/helpers` | 65.10 [65.01, 65.15] | 1.17 [1.12, 1.20] |
| `CSRF` | 3.28 [3.20, 3.32] | 1.08 [1.06, 1.13] |
| `AR associations/preload` | 12.48 [12.44, 12.51] | 1.04 [0.93, 1.10] |
| `AR instantiation/model` | 7.19 [7.15, 7.26] | 0.89 [0.84, 0.97] |
| `Routing/URL generation` | 67.91 [67.83, 67.95] | 0.66 [0.64, 0.70] |
| `Buffers/escaping` | 0.74 [0.73, 0.76] | 0.65 [0.63, 0.68] |
| `View helpers/tags/forms` | 0.90 [0.87, 0.92] | 0.55 [0.51, 0.55] |
| `Assets/importmap/CSP` | 1.34 [1.33, 1.37] | 0.54 [0.51, 0.55] |
| `App controllers` | 28.54 [28.50, 28.62] | 0.07 [0.06, 0.09] |
| `App templates` | 2.50 [2.46, 2.51] | 0.04 [0.03, 0.05] |
| `App models` | 12.38 [12.31, 12.43] | 0.01 [0.00, 0.02] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveSupport` | 94.01 [93.97, 94.04] | 26.79 [26.53, 27.00] |
| `ActiveRecord` | 66.86 [66.76, 66.90] | 15.29 [15.18, 15.41] |
| `rack` | 99.99 [99.98, 100.00] | 14.51 [14.48, 14.66] |
| `ActionDispatch` | 95.96 [95.94, 96.02] | 8.52 [8.42, 8.77] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 7.29 [7.17, 7.39] |
| `inertia_rails` | 74.07 [73.94, 74.13] | 6.68 [6.57, 6.76] |
| `uri` | 4.55 [4.51, 4.59] | 4.55 [4.51, 4.59] |
| `ActiveModel` | 5.63 [5.61, 5.72] | 3.70 [3.63, 3.72] |
| `ActionController` | 66.69 [66.58, 66.77] | 3.13 [3.05, 3.22] |
| `ActionView` | 65.10 [65.01, 65.15] | 2.05 [2.01, 2.08] |
| `concurrent-ruby` | 2.42 [2.34, 2.48] | 1.62 [1.56, 1.66] |
| `sqlite3` | 1.44 [1.42, 1.47] | 1.41 [1.40, 1.44] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activesupport-8.1.4/lib/active_support` | 94.01 [93.97, 94.04] | 26.79 [26.53, 27.00] |
| `GEM/activerecord-8.1.4/lib/active_record` | 66.86 [66.76, 66.90] | 15.15 [15.04, 15.30] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.98, 100.00] | 14.51 [14.48, 14.66] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 95.96 [95.94, 96.02] | 8.52 [8.42, 8.77] |
| `GEM/inertia_rails-3.22.0/lib/inertia_rails` | 74.07 [73.94, 74.13] | 6.65 [6.55, 6.73] |
| `GEM/uri-1.1.1/lib/uri` | 4.55 [4.51, 4.59] | 4.55 [4.51, 4.59] |
| `GEM/activemodel-8.1.4/lib/active_model` | 5.63 [5.61, 5.72] | 3.70 [3.63, 3.72] |
| `GEM/actionpack-8.1.4/lib/action_controller` | 66.60 [66.49, 66.66] | 2.43 [2.35, 2.52] |
| `RUBY/net/http.rb` | 4.20 [4.17, 4.21] | 2.37 [2.36, 2.39] |
| `GEM/actionview-8.1.4/lib/action_view` | 65.10 [65.01, 65.15] | 2.05 [2.01, 2.08] |

## pingcrm

Equal shape weights: pingcrm-contacts-json, pingcrm-organizations-html.

**Descriptive: at least one constituent cohort is rejected.**

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AR query/relation` | 85.85 [85.76, 85.92] | 16.70 [16.59, 16.84] |
| `AS utilities/I18n/time` | 43.10 [42.88, 43.19] | 14.19 [14.09, 14.42] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 9.61 [9.51, 9.74] |
| `Rack/middleware/request` | 98.79 [98.76, 98.81] | 8.53 [8.46, 8.57] |
| `AR attributes/casts` | 11.07 [10.96, 11.17] | 8.36 [8.18, 8.48] |
| `AR SQL/adapter` | 18.24 [18.22, 18.34] | 7.85 [7.68, 7.99] |
| `Authorization` | 17.75 [17.68, 17.81] | 5.74 [5.68, 5.78] |
| `Inertia props/config/render` | 95.07 [95.06, 95.10] | 5.44 [5.32, 5.55] |
| `JSON/serialization` | 23.89 [23.84, 23.92] | 4.37 [4.31, 4.44] |
| `Session/cookies/crypto` | 93.84 [93.83, 93.90] | 3.14 [3.07, 3.19] |
| `AR associations/preload` | 13.63 [13.55, 13.70] | 2.74 [2.70, 2.76] |
| `Rendering/lookup/helpers` | 85.67 [85.62, 85.77] | 2.13 [2.10, 2.14] |
| `Events/logging` | 94.76 [94.73, 94.80] | 1.86 [1.82, 1.90] |
| `Controller dispatch/response` | 86.34 [86.28, 86.44] | 1.51 [1.46, 1.54] |
| `AR instantiation/model` | 3.71 [3.68, 3.81] | 1.50 [1.46, 1.53] |
| `CSRF` | 2.83 [2.75, 2.86] | 1.00 [0.98, 1.03] |
| `Callback machinery` | 95.25 [95.23, 95.31] | 0.95 [0.86, 0.97] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 0.85 [0.82, 0.86] |
| `View helpers/tags/forms` | 1.48 [1.43, 1.53] | 0.85 [0.81, 0.87] |
| `Buffers/escaping` | 0.98 [0.95, 0.99] | 0.82 [0.80, 0.84] |
| `Static-file miss` | 97.00 [96.97, 97.02] | 0.77 [0.74, 0.80] |
| `Assets/importmap/CSP` | 2.84 [2.79, 2.87] | 0.43 [0.39, 0.45] |
| `Routing/URL generation` | 86.92 [86.88, 86.98] | 0.32 [0.29, 0.33] |
| `App controllers` | 51.71 [51.69, 51.80] | 0.19 [0.18, 0.20] |
| `App models` | 3.11 [3.09, 3.18] | 0.16 [0.14, 0.17] |
| `App templates` | 5.14 [5.11, 5.17] | 0.05 [0.05, 0.07] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveRecord` | 86.06 [85.97, 86.14] | 30.20 [30.03, 30.56] |
| `ActiveSupport` | 95.51 [95.47, 95.60] | 18.47 [18.30, 18.73] |
| `ActiveModel` | 13.89 [13.79, 14.04] | 7.21 [7.09, 7.33] |
| `cancancan` | 17.75 [17.68, 17.81] | 5.74 [5.68, 5.78] |
| `rack` | 99.99 [99.99, 100.00] | 5.62 [5.60, 5.75] |
| `ActionDispatch` | 98.24 [98.22, 98.29] | 5.46 [5.31, 5.61] |
| `inertia_rails` | 95.07 [95.06, 95.10] | 5.45 [5.32, 5.56] |
| `jbuilder` | 23.05 [22.99, 23.08] | 3.52 [3.50, 3.59] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 3.34 [3.25, 3.40] |
| `ActionView` | 85.67 [85.62, 85.77] | 3.22 [3.16, 3.25] |
| `concurrent-ruby` | 2.80 [2.76, 2.84] | 2.55 [2.52, 2.60] |
| `ActionController` | 86.44 [86.39, 86.52] | 2.53 [2.53, 2.57] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activerecord-8.1.4/lib/active_record` | 86.06 [85.97, 86.14] | 26.45 [26.31, 26.83] |
| `GEM/activesupport-8.1.4/lib/active_support` | 95.51 [95.47, 95.60] | 18.47 [18.30, 18.73] |
| `GEM/activemodel-8.1.4/lib/active_model` | 13.89 [13.79, 14.04] | 7.21 [7.09, 7.33] |
| `GEM/cancancan-3.7.0/lib/cancan` | 17.75 [17.68, 17.81] | 5.74 [5.68, 5.78] |
| `GEM/rack-3.2.7/lib/rack` | 99.99 [99.99, 100.00] | 5.62 [5.60, 5.75] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 98.24 [98.22, 98.29] | 5.46 [5.31, 5.61] |
| `GEM/inertia_rails-3.23.0/lib/inertia_rails` | 95.07 [95.06, 95.10] | 5.42 [5.31, 5.54] |
| `GEM/activerecord-8.1.4/lib/arel` | 4.90 [4.85, 4.96] | 3.74 [3.67, 3.79] |
| `GEM/actionview-8.1.4/lib/action_view` | 85.67 [85.62, 85.77] | 3.22 [3.16, 3.25] |
| `GEM/jbuilder-2.15.1/lib/jbuilder.rb` | 23.03 [22.97, 23.07] | 2.70 [2.68, 2.71] |

## redprints

Equal shape weights: redprints-proposal-json, redprints-proposals-html.

All constituent cohorts accepted.

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `AS utilities/I18n/time` | 96.34 [96.31, 96.43] | 16.38 [16.23, 16.45] |
| `AR query/relation` | 82.47 [82.42, 82.56] | 15.02 [14.76, 15.18] |
| `AR attributes/casts` | 15.29 [15.14, 15.39] | 10.04 [9.93, 10.11] |
| `Rack/middleware/request` | 98.61 [98.60, 98.63] | 9.63 [9.47, 9.78] |
| `AR SQL/adapter` | 16.41 [16.35, 16.45] | 8.02 [7.91, 8.11] |
| `JSON/serialization` | 39.13 [38.99, 39.21] | 6.97 [6.93, 7.07] |
| `Other gems/stdlib/app` | 100.00 [100.00, 100.00] | 5.98 [5.91, 6.04] |
| `Session/cookies/crypto` | 93.29 [93.26, 93.33] | 3.96 [3.87, 4.02] |
| `AR associations/preload` | 22.38 [22.26, 22.50] | 3.65 [3.53, 3.71] |
| `Inertia props/config/render` | 86.21 [86.09, 86.26] | 3.34 [3.26, 3.50] |
| `FrozenRecord` | 2.87 [2.80, 2.88] | 2.64 [2.58, 2.66] |
| `Rendering/lookup/helpers` | 81.97 [81.93, 82.06] | 2.01 [1.98, 2.08] |
| `StoreModel` | 8.83 [8.70, 8.90] | 1.78 [1.75, 1.86] |
| `Events/logging` | 93.93 [93.89, 94.02] | 1.60 [1.58, 1.70] |
| `Callback machinery` | 95.31 [95.29, 95.34] | 1.31 [1.22, 1.41] |
| `AR instantiation/model` | 10.16 [10.11, 10.20] | 1.13 [1.06, 1.19] |
| `Controller dispatch/response` | 82.73 [82.65, 82.77] | 1.10 [1.05, 1.12] |
| `Buffers/escaping` | 2.29 [2.24, 2.33] | 1.05 [1.00, 1.10] |
| `Benchmark client/seam` | 100.00 [100.00, 100.00] | 0.96 [0.92, 0.99] |
| `Static-file miss` | 96.37 [96.36, 96.39] | 0.89 [0.85, 0.93] |
| `View helpers/tags/forms` | 1.35 [1.28, 1.37] | 0.63 [0.61, 0.67] |
| `CSRF` | 1.88 [1.83, 1.90] | 0.62 [0.60, 0.65] |
| `Routing/URL generation` | 83.51 [83.40, 83.55] | 0.44 [0.42, 0.48] |
| `Assets/importmap/CSP` | 2.72 [2.70, 2.74] | 0.41 [0.39, 0.43] |
| `App controllers` | 77.81 [77.77, 77.85] | 0.28 [0.25, 0.29] |
| `App models` | 8.47 [8.46, 8.54] | 0.16 [0.14, 0.18] |
| `App templates` | 32.61 [32.56, 32.64] | 0.04 [0.03, 0.06] |
| `GC` | 0.00 [0.00, 0.00] | 0.00 [0.00, 0.00] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveRecord` | 82.69 [82.61, 82.77] | 27.73 [27.66, 27.90] |
| `ActiveSupport` | 96.36 [96.33, 96.46] | 19.28 [19.03, 19.67] |
| `ActiveModel` | 14.07 [13.95, 14.21] | 8.59 [8.52, 8.72] |
| `rack` | 99.99 [99.99, 100.00] | 7.69 [7.57, 7.79] |
| `alba` | 37.40 [37.28, 37.46] | 5.48 [5.42, 5.55] |
| `ActionDispatch` | 97.82 [97.78, 97.83] | 5.13 [5.01, 5.29] |
| `inertia_rails` | 86.21 [86.09, 86.26] | 3.34 [3.26, 3.51] |
| `sqlite3` | 3.33 [3.27, 3.36] | 3.29 [3.25, 3.33] |
| `ActionView` | 81.97 [81.93, 82.06] | 3.06 [3.02, 3.11] |
| `frozen_record` | 2.87 [2.80, 2.88] | 2.64 [2.58, 2.66] |
| `Ruby stdlib/internal` | 100.00 [100.00, 100.00] | 2.60 [2.53, 2.64] |
| `tzinfo` | 2.95 [2.86, 3.06] | 2.55 [2.44, 2.66] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/activerecord-8.1.4/lib/active_record` | 82.69 [82.61, 82.77] | 23.90 [23.81, 24.03] |
| `GEM/activesupport-8.1.4/lib/active_support` | 96.36 [96.33, 96.46] | 19.28 [19.03, 19.67] |
| `GEM/activemodel-8.1.4/lib/active_model` | 14.07 [13.95, 14.21] | 8.59 [8.52, 8.72] |
| `GEM/rack-3.2.6/lib/rack` | 99.99 [99.99, 100.00] | 7.69 [7.57, 7.79] |
| `GEM/actionpack-8.1.4/lib/action_dispatch` | 97.82 [97.78, 97.83] | 5.13 [5.01, 5.29] |
| `GEM/alba-3.10.0/lib/alba` | 37.40 [37.28, 37.46] | 4.68 [4.62, 4.76] |
| `GEM/inertia_rails-3.21.2/lib/inertia_rails` | 86.21 [86.09, 86.26] | 3.33 [3.25, 3.50] |
| `GEM/sqlite3-2.9.5-x86_64-linux-gnu/lib/sqlite3` | 3.33 [3.27, 3.36] | 3.29 [3.25, 3.33] |
| `GEM/actionview-8.1.4/lib/action_view` | 81.97 [81.93, 82.06] | 3.06 [3.02, 3.11] |
| `GEM/frozen_record-0.27.4/lib/frozen_record` | 2.87 [2.80, 2.88] | 2.64 [2.58, 2.66] |

## campfire

Equal shape weights: campfire-json-uncached.

**Descriptive: at least one constituent cohort is rejected.**

| Subsystem | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `Other gems/stdlib/app` | 98.56 [98.56, 98.57] | 26.82 [26.64, 26.93] |
| `AR query/relation` | 93.92 [93.89, 93.94] | 17.70 [17.57, 17.80] |
| `AR associations/preload` | 42.11 [42.04, 42.12] | 10.72 [10.63, 10.78] |
| `AR SQL/adapter` | 19.73 [19.68, 19.78] | 9.40 [9.36, 9.44] |
| `AS utilities/I18n/time` | 97.79 [97.76, 97.82] | 7.59 [7.45, 7.68] |
| `AR attributes/casts` | 9.63 [9.55, 9.70] | 7.04 [7.00, 7.10] |
| `Rack/middleware/request` | 98.38 [98.36, 98.39] | 6.22 [6.16, 6.28] |
| `Events/logging` | 97.37 [97.35, 97.39] | 4.40 [4.34, 4.50] |
| `AR instantiation/model` | 9.38 [9.31, 9.45] | 2.46 [2.43, 2.50] |
| `GC` | 1.42 [1.41, 1.43] | 1.42 [1.41, 1.43] |
| `JSON/serialization` | 52.16 [52.11, 52.19] | 1.29 [1.28, 1.31] |
| `Assets/importmap/CSP` | 25.92 [25.90, 25.97] | 1.21 [1.19, 1.26] |
| `Rendering/lookup/helpers` | 93.88 [93.85, 93.90] | 0.82 [0.80, 0.86] |
| `Controller dispatch/response` | 94.03 [94.00, 94.06] | 0.72 [0.71, 0.76] |
| `Session/cookies/crypto` | 96.23 [96.19, 96.24] | 0.66 [0.63, 0.70] |
| `Callback machinery` | 96.59 [96.56, 96.62] | 0.48 [0.46, 0.49] |
| `Routing/URL generation` | 94.40 [94.36, 94.43] | 0.36 [0.35, 0.38] |
| `Static-file miss` | 97.92 [97.90, 97.93] | 0.22 [0.21, 0.23] |
| `App controllers` | 92.58 [92.52, 92.60] | 0.19 [0.19, 0.20] |
| `App models` | 45.51 [45.42, 45.54] | 0.10 [0.09, 0.11] |
| `Benchmark client/seam` | 98.56 [98.56, 98.57] | 0.07 [0.06, 0.07] |
| `Buffers/escaping` | 0.07 [0.06, 0.07] | 0.07 [0.06, 0.07] |
| `App templates` | 51.88 [51.84, 51.93] | 0.05 [0.04, 0.05] |
| `CSRF` | 0.01 [0.01, 0.01] | 0.00 [0.00, 0.01] |

### Rails components and gems

| Component | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `ActiveRecord` | 93.95 [93.92, 93.96] | 38.73 [38.67, 38.85] |
| `uri` | 18.97 [18.89, 19.02] | 18.97 [18.89, 19.02] |
| `ActiveSupport` | 97.83 [97.81, 97.85] | 12.73 [12.64, 12.80] |
| `ActiveModel` | 7.38 [7.26, 7.41] | 6.17 [6.09, 6.22] |
| `Ruby stdlib/internal` | 98.56 [98.56, 98.57] | 4.17 [4.11, 4.20] |
| `ActionDispatch` | 98.15 [98.13, 98.16] | 3.92 [3.83, 3.96] |
| `sqlite3` | 3.40 [3.36, 3.43] | 3.38 [3.33, 3.41] |
| `rack` | 98.56 [98.55, 98.57] | 3.01 [2.96, 3.09] |
| `App` | 94.41 [94.37, 94.45] | 1.59 [1.56, 1.64] |
| `GC` | 1.42 [1.41, 1.43] | 1.42 [1.41, 1.43] |
| `sentry-ruby` | 97.21 [97.19, 97.23] | 0.98 [0.93, 1.02] |
| `ActionController` | 94.04 [94.00, 94.07] | 0.97 [0.95, 1.00] |

### Gem/file prefixes (top self costs)

| Prefix | Inclusive % [95% CI] | Self % [95% CI] |
|---|---:|---:|
| `GEM/rails-e3d5c569d217/activerecord/lib` | 93.95 [93.92, 93.96] | 38.97 [38.91, 39.08] |
| `GEM/uri-1.1.1/lib/uri` | 18.97 [18.89, 19.02] | 18.97 [18.89, 19.02] |
| `GEM/rails-e3d5c569d217/activesupport/lib` | 97.83 [97.81, 97.85] | 12.73 [12.64, 12.80] |
| `GEM/rails-e3d5c569d217/activemodel/lib` | 7.38 [7.26, 7.41] | 6.17 [6.09, 6.22] |
| `GEM/rails-e3d5c569d217/actionpack/lib` | 98.15 [98.13, 98.16] | 4.89 [4.82, 4.91] |
| `GEM/sqlite3-2.9.6-x86_64-linux-gnu/lib/sqlite3` | 3.40 [3.36, 3.43] | 3.38 [3.33, 3.41] |
| `GEM/rack-3.2.7/lib/rack` | 98.56 [98.55, 98.57] | 3.01 [2.96, 3.09] |
| `RUBY/<internal:marshal>` | 1.48 [1.43, 1.50] | 1.48 [1.43, 1.50] |
| `GC` | 1.42 [1.41, 1.43] | 1.42 [1.41, 1.43] |
| `APP/app/controllers` | 92.30 [92.25, 92.31] | 1.41 [1.38, 1.43] |

## Cross-app self-cost ranking

Equal weight per available primary app (blog, starter, pingcrm, redprints), then per measured route/format. Campfire is excluded.

**Descriptive: includes a rejected cohort; not an accepted aggregate.**

| Rank | Subsystem | Mean self % [95% CI] |
|---:|---|---:|
| 1 | AS utilities/I18n/time | 17.02 [16.94, 17.07] |
| 2 | Rack/middleware/request | 12.05 [11.97, 12.06] |
| 3 | AR query/relation | 11.33 [11.22, 11.46] |
| 4 | Other gems/stdlib/app | 8.32 [8.29, 8.35] |
| 5 | AR SQL/adapter | 6.89 [6.83, 6.91] |
| 6 | AR attributes/casts | 6.16 [6.10, 6.22] |
| 7 | Session/cookies/crypto | 4.82 [4.79, 4.85] |
| 8 | Inertia props/config/render | 3.88 [3.83, 3.90] |
| 9 | JSON/serialization | 3.26 [3.23, 3.29] |
| 10 | View helpers/tags/forms | 3.20 [3.17, 3.24] |
| 11 | Rendering/lookup/helpers | 3.07 [3.05, 3.09] |
| 12 | AR associations/preload | 2.43 [2.38, 2.45] |

<!-- END GENERATED HOTSPOT TABLES -->

## ActiveSupport / Rack method addendum

The original accepted show/Starter JSON exports retain source-prefix groups,
not Ruby method identities or their original source stacks. The Callgrind
files contain MRI's native interpreter symbols, which cannot reconstruct
those discarded identities. **No existing accepted cohort was relabeled or
rerun as a replacement.** Two separately declared six-round detail cohorts
export the same sampler's retained frame dictionary **after all windows**;
sampling, requests, heap floors, Valgrind and controls are unchanged. Their
independent verdicts and per-method round values are in
[`hotspots-detail-results.json`](hotspots-detail-results.json). Raw frame/stack
captures and logs remain with the private cohort outputs; the sanitized export
contains frame locations, round denominators, method/family statistics and
raw-capture/log digests, not cookies or bodies. This is the unavoidable new
collection needed for the requested attribution, not a retry of a failed map.

The source-family tables below include the **whole ActiveSupport gem**. The
original “AS utilities/I18n/time” subsystem excludes separately classified
buffers, callbacks, events, crypto and most JSON, and includes I18n/time gems;
its 17–24% is therefore **not the total to which these rows should sum**.
Likewise HTTP families separate Rails HTTP, Rack proper, mock client,
session/cookies, static misses and routing; they are not a repartition of
only the original 11–13% Rack subsystem. All shares still use the entire
request envelope as denominator. Native primitives are charged to their
nearest Ruby frame: a large digest or escape frame is not evidence that the
same amount of Ruby interpretation can be removed.

Both detail cohorts are **accepted**: ordinary and sampler A/A, all five
heaps, both-arm fidelity, capture integrity and overflow checks pass. Ordinary
total/no-GC A/A intervals are blog [−0.0162, +0.0651] / [−0.0374, +0.0382]%
and Starter [−0.0908, +0.0498] / [−0.1015, +0.0600]%. The widest fidelity
endpoints stay within ±0.095%, inside the separately defined ±0.5% limit. This does not
change any original accepted/rejected verdict.

### ActiveSupport self by file family

Whole-request %, median [nominal 95% CI]; files are under `active_support/`.
Related files are grouped explicitly, never inclusive-cost sums.

| Source family / principal file or method | Blog show | Starter dashboard JSON |
|---|---:|---:|
| SafeBuffer / ERB::Util (`core_ext/string/output_safety.rb`, `core_ext/erb/util.rb`) | 5.76 [5.69, 5.97] | 0.00 [0.00, 0.00] |
| `core_ext/object/blank.rb` (`blank?`, presence) | 3.16 [3.13, 3.21] | 0.51 [0.42, 0.64] |
| `ordered_options.rb` (`InheritableOptions#initialize`, `OrderedOptions#method_missing`) | 2.02 [1.93, 2.06] | 1.45 [1.29, 1.59] |
| Notifications / Instrumenter / subscribers | 1.57 [1.51, 1.65] | 1.23 [1.10, 1.35] |
| Hash core_ext (`core_ext/hash/slice.rb#extract!`, `core_ext/hash/keys.rb` transforms) | 1.47 [1.39, 1.65] | 12.86 [12.64, 13.10] |
| `callbacks.rb` (`run_callbacks`, filters) | 1.11 [1.10, 1.14] | 2.23 [1.93, 2.41] |
| Message encryptor/verifier, messages/codec/metadata/rotator, key generator | 1.03 [0.98, 1.08] | 3.91 [3.63, 4.13] |
| `isolated_execution_state.rb` | 0.96 [0.87, 1.09] | 1.53 [1.41, 1.73] |
| `parameter_filter.rb` (`compile_filters!`, `value_for_key`) | 0.94 [0.90, 0.96] | 1.44 [1.37, 1.49] |
| Inflector methods / string inflections | 0.83 [0.80, 0.86] | 0.59 [0.56, 0.70] |
| `hash_with_indifferent_access.rb` | 0.65 [0.59, 0.72] | 0.52 [0.49, 0.59] |
| JSON encoding + `core_ext/object/json.rb` (`as_json` / `to_json`) | 0.16 [0.13, 0.17] | 0.78 [0.77, 0.89] |
| `current_attributes.rb` | 0.01 [0.00, 0.02] | 0.77 [0.74, 0.86] |
| `core_ext/object/try.rb` / module delegation | 0.01 [0.00, 0.02] | 0.57 [0.54, 0.60] |
| Other AS (including execution wrappers, logger/enumerable/cache residue) | 1.19 [1.16, 1.27] | 2.30 [2.21, 2.44] |

The blog buffer family splits into ERB util **3.71 [3.62, 3.88]%** and
SafeBuffer/output_safety **2.08 [1.96, 2.15]%** self. Those are source ownership,
not the old index ≤1.51% removable/inclusive survey boundary. Its largest ERB
methods are `xml_name_escape` **2.08 [2.06, 2.20]%** and `html_escape`
**1.62 [1.55, 1.71]%**; retain live escaping and encoding behavior.
Notifications' `fanout.rb` alone is **1.12 [1.01, 1.20]%** blog /
**0.83 [0.76, 0.91]%** Starter; the rest of the family is not “empty Fanout”.
Starter `Hash#symbolize_keys!` is **0.90 [0.85, 0.95]%**, and
`CurrentAttributes#resolve_defaults` **0.34%**; see the existing default-tuple
allocation row, not a new per-request cache. Its `message_encryptor.rb`
**1.57 [1.39, 1.67]%** is crypto plumbing, not response JSON encoding.
Every file/method, its definition location, inclusive/self and boundary
subsets are in the numeric export; zero sampled work is not non-execution.

### Rack and Rails HTTP self

| Disjoint source family (broader than the original Rack subsystem) | Blog show | Starter dashboard JSON |
|---|---:|---:|
| Rack ETag / ConditionalGet | 4.90 [4.88, 4.97] | 0.93 [0.90, 1.01] |
| Rack Request / query parser / Utils | 1.68 [1.60, 1.85] | 3.58 [3.44, 3.84] |
| Rack Headers | 1.05 [0.95, 1.07] | 1.92 [1.79, 2.04] |
| Rack Response | 0.43 [0.40, 0.47] | 0.86 [0.76, 0.88] |
| Rack MethodOverride | 0.02 [0.01, 0.03] | 0.02 [0.01, 0.06] |
| Other Rack middleware | 0.43 [0.38, 0.48] | 0.74 [0.67, 0.92] |
| MockRequest / MockResponse **client** | 0.74 [0.69, 0.78] | 1.93 [1.91, 2.02] |
| Rails Request / Response / HTTP headers | 2.13 [2.06, 2.20] | 4.04 [3.93, 4.13] |
| Other ActionDispatch envelope | 0.68 [0.63, 0.73] | 1.21 [1.08, 1.33] |
| Rails/Rack-session session and cookies (originally separate) | 0.90 [0.80, 1.01] | 2.23 [2.13, 2.41] |
| Rails Static-file miss (originally separate) | 1.08 [1.07, 1.12] | 1.86 [1.84, 2.00] |
| Journey / routing (originally separate) | 4.83 [4.73, 4.97] | 0.60 [0.57, 0.64] |

Notable Rack method self costs:

| Method | Blog show | Starter dashboard JSON |
|---|---:|---:|
| `Headers#[]=` | 0.63 [0.55, 0.70] | 1.18 [1.06, 1.32] |
| `Headers#downcase_key` | 0.19 [0.17, 0.23] | 0.33 [0.29, 0.35] |
| `Request::Env#get_header` | 0.46 [0.39, 0.58] | 0.72 [0.70, 0.78] |
| `Request::Env#fetch_header` | 0.25 [0.24, 0.28] | 0.41 [0.36, 0.46] |
| `Response#initialize` | 0.29 [0.25, 0.30] | 0.55 [0.44, 0.60] |
| `Utils.set_cookie_header` | 0.16 [0.15, 0.20] | 0.47 [0.43, 0.61] |

Starter `Utils.parse_cookies_header` is **0.50 [0.48, 0.54]%**, but its native
URI decode descendants are charged to URI, not Rack (see the top-five table).
Likewise `set_cookie_header` does not include its **2.56%** URI-escape self
descendant. Both hot URI encode/decode methods have **zero sampled mock-phase
self** in every round: these are app-stack cookie costs outside the action,
not the mock client's cookie parsing. MockResponse's `identify_cookie_attributes`
alone is **0.85 [0.77, 0.94]%** Starter, explicitly client work. `FileHandler#file_readable?`
is **1.12 [1.03, 1.23]%** there, below Static's inclusive wrapper. Neither fixture
has a sampled Rack::Static/Files source frame; Rails Static is the measured
miss path, not evidence that static serving itself is free.

### What “inside a sealed endpoint” means here

For an explicit and reproducible boundary, “inside” means that the captured
stack contains `ActionController::BasicImplicitRender#send_action`: action plus
explicit/implicit rendering, below the controller filters and Rack stack.
This is a **location**, not an assertion that an operation is certified or
lowerable. The current sealed link/route slice is narrower still. Live SQL,
escaping, tokens, events and crypto remain necessary inside that boundary.
Method rows report the subset of whole-request self cost inside it; the rest
is outside, not an additional saving. Middleware version/session checks,
cookie response commit, ETag digesting, static misses and executor lifetimes
cannot be credited to an action/render-only endpoint. A wider middleware
endpoint would need its own design, evidence and contract.

The export also marks stacks under `Rack::MockRequest`/`MockResponse` **without
`Rails::Engine#call`**. That separates mock-client/body-consumption phase work
from the app-stack phase; not every body-consumption operation is disposable
test overhead. In particular mock cookie parsing and its descendants must
not be sold as production-server savings.

### Top five methods and levers

Self and inside columns are whole-request %, not percentages of a method.
The inside subset's interval is exported; a single median is shown here to
keep the boundary and lever readable. These are **investigation levers**, not
credited savings. “App” never permits a behavior change in Lowrail itself.

| Blog show method (file) | Self % [95% CI] | Inside action/render self % | Lever / existing DECISIONS overlap |
|---|---:|---:|---|
| `Rack::ETag#digest_body` (`rack/etag.rb`) | 4.83 [4.79, 4.86] | 0.00 — outside | **App recommendation**: review validator/body policy; keep SHA/ETag by default. Outside existing endpoint/action and remaining controller/params/response interpretation budgets |
| `TagBuilder#tag_options` (`action_view/helpers/tag_helper.rb`) | 3.77 [3.59, 4.04] | 3.77 — inside | **Upstream Rails**, then sealed component only if priced: Tag/form attribute component; Compiled form/literal-tag intermediates. The upstream append fusion does not remove all 3.77% |
| `TagBuilder#tag_option` (same file) | 3.29 [3.16, 3.44] | 3.29 — inside | **Upstream Rails / sealed endpoint**: same tag/compiled-form rows, SafeBuffer/OutputBuffer interpretation; retain escaping and fresh output. Inclusive costs overlap the preceding row |
| `String#blank?` (`active_support/core_ext/object/blank.rb`) | 2.88 [2.86, 2.94] | 2.83 — mostly inside | **Sealed endpoint / upstream**, not a generic blank-result cache. Overlaps **Upstream String#blank? / sealed backport** (candidate #3 prerequisites and guardless-backport refusal apply), compiled form/tag and endpoint/action. This source-owned pool is not that backport's removable budget |
| `OpenSSL::HMAC.digest` (`openssl/hmac.rb`) | 2.26 [2.21, 2.38] | 2.26 — inside | **App recommendation / retain primitive**: token/security work is not a guarded-pass saving. Overlaps endpoint/action's explicit live token/CSRF residue, not its removable rendering structure |

| Starter dashboard JSON method (file) | Self % [95% CI] | Inside action/render self % | Lever / existing DECISIONS overlap |
|---|---:|---:|---|
| `Hash#extract!` (`active_support/core_ext/hash/slice.rb`) | 11.60 [11.37, 11.82] | 4.10 — mixed, mostly outside | **Guarded pass / upstream Inertia** at the specific bind caller: inertia/config_bind and Inertia config extraction Hashes. All 5,458 signed net samples have bind_controller on stack; no generic Hash rewrite |
| `Configuration#bind_controller` (`inertia_rails/configuration.rb`) | 3.19 [3.09, 3.42] | 1.17 — mixed, mostly outside | **Guarded pass / upstream Inertia**: same two rows. Inclusive **15.05 [14.94, 15.36]%** contains the extract! work; action-only sealing does not cover middleware invocations |
| `URI._encode_uri_component` (`uri/common.rb`) | 2.56 [2.49, 2.65] | 0.00 — outside | **App recommendation / upstream library**: live cookie encoding from Rack Utils → CookieJar commit. Not the literal route-fresh-buffer or Journey row; no cookie-byte memo under boot facts |
| `URI._decode_uri_component` (same file) | 2.01 [1.92, 2.05] | 0.00 — outside | **App recommendation / upstream library**: Rack cookie-header parsing → request CookieJar; preserve validation/encoding. Outside existing endpoint and fixed-shape serialization rows |
| `PropsResolver#deep_transform_props` (`inertia_rails/props_resolver.rb`) | 1.40 [1.36, 1.49] | 1.40 — inside | **Guarded pass / sealed endpoint** only at certified prop traversal. Inertia prop tuple iteration, prop path scaffolding and metadata try-dispatch rows overlap; inclusive **22.24 [21.96, 22.40]%** includes live descendants, not 22% removable work. Existing props draft has no credited gain |

### Serialization decision: do not promote the wrong pool

Starter dashboard JSON's ActiveSupport share is **not mostly JSON encoding**. Its dominant
method is `Hash#extract!`, reached from
`InertiaRails::Configuration#initialize` → `bind_controller`; the recorded
callers include Inertia middleware version/session checks and XSRF policy as
well as rendering. The `Hash#extract!` self cost and `bind_controller` inclusive
cost overlap; never add them. Prioritize the existing **`inertia/config_bind`**
row and upstream [Inertia PR 437](https://github.com/inertiajs/inertia-rails/pull/437)
(open, not merged when checked), preserving fresh configuration/options and
live callable values. A self/inclusive map is not a measurement of that pass's
gain, and interpreter Ir shares cannot replace the old native-time estimates.

The parked **Fixed-shape serialization** row's **0–0.18% PingCRM** came from
ten specific Jbuilder five-getter row extractions: an optimistic native-time
estimate, not the whole JSON encoder or every app's serialization ceiling.
The [candidate survey](../candidates.md#3-isolated-savings-and-request-arithmetic) records
no matching Starter serializer and a losing Redprints Alba key-plan prototype.
This addendum does not remeasure that PingCRM micro, so its old narrow estimate
is neither invalidated nor newly certified. It must **not** be generalized to
all Starter JSON, nor can the configuration-extraction pool justify un-parking
serialization. Session serialization is separate from response-prop encoding;
`as_json`, escaping and JSON gem work are not automatically fixed-shape work.

### Rack 3.x/main: checked source, not assumed upgrade savings

Both detailed fixtures already run **Rack 3.2.7**. Compare its tag commit
[`70d2e10`](https://github.com/rack/rack/commit/70d2e1046789a70e240e01b9ac0b3ffc9b26d33f)
with canonical main
[`412b7e5`](https://github.com/rack/rack/commit/412b7e5250612e8b23095eee65ee3268addb4776):

- `Headers#[]=`, `downcase_key` and the known-header cache hot path are
  unchanged. The [common lowercase-header cache](https://github.com/rack/rack/commit/95d2f64a84a6010d5b1a5179a647b42cb53356d1)
  is **already shipped** in the measured 3.2.7, not a new available saving.
- `ETag#digest_body` is unchanged; main only removes a boot-time require in
  that file. Body hashing is real, input-size-dependent SHA work after the
  action/render boundary, not eliminated by a sealed template. Review the
  app's validator policy if appropriate; do not silently omit ETags.
- MockResponse cookie parsing is unchanged; main's forwarding-syntax cleanup
  does not solve the measured parsing path, which is client-side anyway.
- Main's [shape-friendly Request initialization](https://github.com/rack/rack/commit/2c1eb195eb0161b065a620b97c228c95336fad6b)
  is a real upstream change, but no gain is measured here, and it does not
  remove the cookie URI encoding/decoding or hot `Rack::Headers#[]=` path.
  The `select_best_encoding` quadratic-algorithm fix is already in 3.2.7;
  neither it nor a generic “Rack 3” upgrade is new credit for these GETs.
- The sampled static miss belongs to **Rails** `ActionDispatch::FileHandler`,
  not Rack::Static. Follow the existing **Upstream static miss candidates
  (c/static)** decision and its Rails-main commits, not a Rack backport.
  MethodOverride's GET path is tiny; this does not price POST parsing.

**No newly upstream-solved Rack-main replacement for these dominant measured
methods was established.** Favor existing Inertia/Rails upstream work and a
measured sealed rendering slice; leave cookie/security/validator semantics
live. The allocation pools remain those in [allocations.md](allocations.md),
not new allocation measurements inferred from this profile.

### Detail reproduction and checks

Use the sampler/tool/environment already documented above, with new roots:

```sh
BENCH_JOBS=2 mise exec -- ruby bench/experiments/hotspots_detail.rb /tmp/NEW-detail-blog blog
BENCH_JOBS=2 mise exec -- ruby bench/experiments/hotspots_detail.rb /tmp/NEW-detail-starter starter
mise exec -- ruby bench/experiments/hotspots_report.rb --detail /tmp/detail-results.json \
  /tmp/NEW-detail-blog /tmp/NEW-detail-starter
```

The two workers/study limit still means at most four simultaneous Callgrind
workers. The post-window frame exporter passes the existing asymmetric
instruction-weighting/recursive-stack/GC contract plus exact path/count and
qualified-method/location recovery: **6,210 samples**, expected B inclusive
**74.883%**, observed **75.137%**, maximum lag **30 Ir**, **236 GC samples**.
The numeric reporter checks the full method-self partition in every round;
inclusive recursion is deduplicated by method, not by frame ID. At the detail
source pin, shared-driver tests passed **11 / 82**. After integrating the newer
shared worker, they pass **12 / 130**; pass tests remain **16 / 157**, all green.
No pass/runtime or allocation-census change accompanies the addendum.

The complete map's final audit checks **396** round/mode/axis self partitions
across eleven complete cohorts, retains all five interrupted attempts, and
finds no overflow in a completed worker. The four previously published shape
exports and the separate method-detail export are unchanged. Every completed
shape links to exactly one measured-source provenance entry. All five new
cohort roots' measured-source hashes and the sampler engine were rechecked
before the publication pull/rebase; the numbers belong to those pins, not to
an assertion that later main revisions were remeasured. No private request
headers or bodies are exported.

After the publication rebase, shared-driver tests pass **13 / 151**, pass
tests **16 / 157**, profile-summary tests **1 / 9** and callback-survey tests
**1 / 10**, with no failures, errors or skips. The rebase leaves all report
data unchanged; the updated `String#blank?` overlap above points to main's
separate sealed-candidate decision, not a new measurement or promotion here.
