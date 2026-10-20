# Roundhouse calibration: replacement is not specialization inside Rails

2026-10-20. **Measurement only. No pass, runtime, default, or tier is changed.**

## Question and limits

Roundhouse's [README](https://github.com/rubys/roundhouse/blob/98479d0a32e983af59ab50fa66a65e53056b9039/README.md#why-it-is-fast)
reports 326 Rails versus 3,292 emitted-Ruby requests/second on its July blog
benchmark, both on CRuby+YJIT. That is a native serving result, not an
instruction ratio. This study asks what work disappears on our current blog
under [Lowrail's fixed-heap protocol](../bench.md), and what could survive
restoring real Rails objects, sessions and events.

**This pair is not byte-equivalent.** Its controlled instruction ratios are
diagnostics of two implementations, not an acceleration claim for an
equivalent endpoint. In particular, restoring Rails' observables is not a
free bridge. YJIT comparisons which fail any window gate remain rejected;
no clean arms are salvaged and no cohorts are repeated until green.

## Pins and fixture audit

- Lowrail harness:
  [51686b7](https://github.com/thomasklemm/lowrail/commit/51686b7), including
  [d7d62ba](https://github.com/thomasklemm/lowrail/commit/d7d62ba)'s Valgrind
  correction. Ruby **4.0.7**, Rails **8.1.4**, Linux x86-64.
  The publication rebase also integrates later shared-helper/ZJIT work;
  none of these results is relabeled as a measurement of that newer harness
  or runtime. Reproduction must use this measured harness pin and the exported
  source digests, not publication HEAD. Lowrail is off in every Rails worker.
- Roundhouse:
  [98479d0](https://github.com/rubys/roundhouse/commit/98479d0a32e983af59ab50fa66a65e53056b9039).
  Built `cargo build --locked --bin roundhouse`, then ran
  `roundhouse --target ruby APP -o /tmp/roundhouse-blog-emit`. No
  `--allow-unsupported` or survey mode. Its sources were not edited; no
  upstream issue or PR was opened.
- `script/corpus real-blog real-blog-r4` uses Roundhouse
  [bb90df2](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9)'s
  `scripts/create-blog` with `RAILS_NEW_VERSION=8.1.4`. Comparing that file
  against the measured Roundhouse revision gives **no diff**. Thus the
  generator's models, migrations, routes, templates and seeds agree, rather
  than merely being similarly named blog fixtures. The README's historical
  July revision/environment is not reproduced by this current pin.
- Emit input was **our exact generated app**, after production
  `db:prepare assets:precompile`, not a separately regenerated sibling.
  Both database files contain the same three articles and three comments
  (2/1/0 comments on article IDs 1/2/3). SQLite's backup API copied Rails'
  production database into emit's `storage/development.sqlite3` before boot.
  This avoids emit's `db/seed.sql` difference: it synthesizes January timestamps
  in microsecond increments instead of Rails' actual seed timestamps.
- The emitted lock originally pinned older Rack/SQLite/JSON. A dependency-only
  `bundle update rack sqlite3 json` aligned them with the generated Rails app:
  Rack **3.2.7**, sqlite3 **2.10.1**, JSON **3.1.0**. No emitted application or
  runtime source was changed. Both lock digests are retained in the export.
- Emit reports four `lower_residue` warnings: two dropped inline JSON error
  render arms and ApplicationMailer's dropped `default`/`layout`. They do not
  execute in these HTML GETs, but are not hidden or converted to support claims.
  Its text-level tree shake drops 97 runtime and 40 synthesized model defs;
  removing uncalled defs is not itself a request saving.

## Output and observable-contract audit, before measurement

Both applications returned **200** for `/articles` and `/articles/1`, `/2`,
`/3`. No whitespace, token, attribute or header normalization was used to
declare equivalence. The literal bodies fail comparison on every route:

| Path | Rails bytes | Emit bytes | Literal equality |
|---|---:|---:|---|
| `/articles` | 6,970 | 6,828 | no |
| `/articles/1` | 5,683 | 5,535 | no |
| `/articles/2` | 5,096 | 4,952 | no |
| `/articles/3` | 4,527 | 4,387 | no |

Observed differences, not an exhaustive conformance audit:

1. Different attribute ordering and void-tag spelling in buttons/forms,
   labels, inputs, stylesheets and textareas. These deterministic differences
   alone disprove byte equality, independently of entropy.
2. Emit's importmap and modulepreloads use undigested JS URLs; Rails uses
   production asset digests. Both stylesheet URLs carry the source manifest's
   digests, but serialize the tags differently. Static assets were not fetched
   or browser-tested; this is a Rack request study, not a working-asset claim.
3. CSRF masks vary on both sides; Turbo stream signatures differ too. Their
   equality was not established with common entropy/derived keys. These are
   additional differences, not an explanation for the deterministic mismatches.
4. Rails sends a `link` response header which emit omits; emit adds `x-cache:
   miss`. Other dynamic header values and session-cookie envelopes differ.
   Requests carry no incoming cookie, Accept/Accept-Encoding, query string or
   conditional headers. Every request still executes SQL; no HTML response
   cache hit or gzip result is being priced.
5. **Session confidentiality and interoperability differ.** Emit's
   [`signed_cookies.rb`](https://github.com/rubys/roundhouse/blob/98479d0a32e983af59ab50fa66a65e53056b9039/runtime/spinel/signed_cookies.rb)
   explicitly implements signed, *not encrypted*, URL-encoded sessions,
   with separate flash cookies, and says its sessions are not interoperable
   with Rails. Rails uses its real encrypted CookieStore. An empty inbound
   cookie is not a benchmark of decrypting an authenticated production session.
6. A separate warmed subscriber sees **16 events on Rails index, 14 on show
   /1**, versus **two SQL events on each emitted endpoint**. Emit omits
   `start_processing`, `process_action`, request, instantiation and render
   events. The remaining SQL payloads are not Rails-equivalent either (names,
   keys, binds and cached metadata differ). The added audit subscriber was
   absent from primary instruction workers; Rails' built-in listeners remain.
7. Index executes **three SELECTs in Rails versus two in emit**: Rails'
   `@articles.any?` first issues `SELECT 1 ... LIMIT ?`; emit tests the already
   materialized Array. Both then fetch three articles and preload three
   comments. Emit uses literal IDs/explicit columns and an additional comments
   ordering, rather than Rails' bind SQL. Show uses two SELECTs in both.
   Query/event order is therefore not interchangeable even when visible data
   agree on this database.

The numeric export retains body hashes/sizes, header *names*, actual ordered
SQL/event traces and all warnings. Session cookies and response bodies remain
private. No normalization repairs these differences for a support claim.
As a deliberately weaker content check, whitespace-collapsed `<main>` text
and ordered form action/method pairs agree on all four paths (3/4/3/2 forms).
That confirms the fixture/data pairing, not byte, security or event equivalence.

## Fixed-heap request results

M Ir means millions of software-executed instructions per request. Values
are medians for `off_a` and `emit_a`; factors are medians of **paired round
ratios**, not ratios of the displayed medians. Brackets are coarse nominal
95% whole-round bootstrap intervals. All rows remain **output-non-equivalent
diagnostics**, even where the measurement controls pass.

| Runtime / route | Rails total / excluded M Ir | Emit total / excluded M Ir | Objects, Rails → emit | Paired Ir factor | Measurement controls |
|---|---:|---:|---:|---:|---|
| Interpreter index | 9.102225 / 9.101139 | 1.546293 / 1.546300 | 2,358.40 → 758.17 | **5.887× [5.885, 5.888]** | pass |
| Interpreter show /1 | 8.748892 / 8.750047 | 1.414011 / 1.414071 | 2,244.26 → 720.40 | **6.188× [6.186, 6.190]** | pass |
| YJIT index, rejected | 5.679991 / 5.679283 | 1.043692 / 1.043496 | 2,378.28 → 770.15 | not credited | **REJECTED** |
| YJIT show /1, rejected | 5.415349 / 5.414526 | 0.949350 / 0.948196 | 2,254.52 → 728.96 | not credited | **REJECTED** |

Interpreter total work changes **−83.015% [−83.018, −83.008]** on index and
**−83.839% [−83.846, −83.834]** on show. The independently booted `emit_b`
medians are 1.546178 / 1.414291 M Ir and 757.70 / 721.17 objects, respectively.
Neither implementation collects in any measured window: this fixed-capacity
slice is not a measurement of production steady-state GC cost. Slight
total/excluded reversals are ordinary independent-window variation.

| Cohort | Rails A/A CI %, total / excluded | Emit A/A CI %, total / excluded | Heap / JIT |
|---|---|---|---|
| Interpreter index | [−0.0243, +0.0109] / [−0.0280, +0.0430] | [−0.0297, +0.0458] / [−0.0450, +0.0882] | five pools pass; actual JIT off |
| Interpreter show | [−0.0688, +0.0135] / [−0.0663, +0.0167] | [−0.0171, +0.1426] / [−0.0136, +0.0566] | five pools pass; actual JIT off |
| YJIT index | [−0.0596, +0.0920] / [−0.0418, +0.1023] | **[−2.1690, +0.1089] / [−0.1652, +1.6523]** | **pools 0/2 and window gate fail** |
| YJIT show | [−0.1207, +0.0775] / [−0.1022, +0.1133] | **[−2.5161, +13.2225] / [−1.7825, +1.9332]** | **pools 0/2 and window gate fail** |

All 24 workers in each YJIT cohort observe YJIT enabled and reach three flat
warm windows (800–3,800 extra requests on index; 600–5,400 on show). Then
**11/24 workers change counters in 12 windows on index; 12/24 in 17 windows
on show**. Eleven emit workers fail on each route; show also has one Rails
worker failure. Even N=0 windows can compile. Both cohorts also exceed the
one-page cross-arm capacity tolerance in pools 0 and 2, and emit A/A fails.
These are three independent rejection reasons, not just a missing native-time
measurement. Failed raw counts/intervals remain in the export; none was rerun.

Each of four predeclared cohorts has six fresh-process rounds, independent
Rails `off_a/off_b` **and** emitted `emit_a/emit_b` controls, seed 41231,
50 ordinary warmups, N=0/50 subtraction in both total and GC-excluded modes,
the shared post-GC settling request and unchanged five heap floors:
1,000,000 / 250,000 / 100,000 / 20,000 / 10,000 slots. GC remains enabled.
At most **four Callgrind workers** run at once. Interpreter cohorts run first;
then YJIT uses the ordinary three-flat-window warmup and every-window gate.
The Rails arm loads `bench/heap_requests.rb` unchanged; the emit arm boots its
complete generated `config.ru`, then uses the same Rack::MockRequest loop,
`HeapWindows`, observer and estimator. No HTTP server/network time is counted.

The tool was built **before** measurement with
`bash script/bench-valgrind /tmp/vg`, `PATH=/tmp/vg/bin:$PATH` and
`CPATH=/tmp/vg/include`. Its source archive SHA is the protocol's
`dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`;
patch SHA `ab95c4a3c2ffae1db00116ff550b19f1f30f3ae3333349779c221d1fb55f84d1`;
this orb's built Callgrind SHA
`ba5604c65a1c44d3aef270d5dcb66daf119160a9b0597e451ec435c407d7c98c`.
The 512 MiB brk reservation, boot/allocation preflight and every worker's
stderr overflow gate apply. Tool build/compiler/libc fingerprints are exported.
An instruction factor is not a latency/req/s factor or a PMU/cycles result.

## Inclusive subsystem decomposition

These are **coarse, perturbed boundary profiles**, not accepted causal
subsystem savings. Each app/route has one separate interpreter process with
the same heap preparation, settling and N=0/50 total/excluded windows. A small
C client-request gate collects only between named Ruby method entry/exit
wrappers, deduplicating nested selected regions. This avoids pretending that
MRI's generic C interpreter frames identify Ruby methods. Source, exact method
inventory and signed counts are in the export. Every profile finishes without
brk overflow; this is not six-round A/A/fidelity-controlled attribution.

The instrumentation changes total work **+3.82%/+3.34% in Rails** and
**+10.86%/+7.76% in emit** (index/show) versus primary medians. This exceeds
the hotspot sampler's ±0.5% fidelity standard: **do not treat these profiles
as an accepted hotspot map**, or use their small leaf differences to choose
a component pass. The asymmetry is retained, not corrected by an invented
per-wrapper constant. A synthetic gate check excludes 200,000 outside-loop
iterations while retaining 10,000 inside iterations (4.635/4.631 M Ir; nested
boundary 4.634 M); it checks the gate's scope, not zero perturbation.

Below: **raw profiled M Ir/request**, Rails → emit; Δ is the descriptive
within-row difference. Rendering contains AR/security/helpers/escaping/buffers;
controller contains rendering/AR, and the outer envelope contains routing and
part of security/events. **Never sum rows or call Δ removable work.**

| Inclusive boundary / band | Index Rails → emit | Index Δ M Ir | Show Rails → emit | Show Δ M Ir |
|---|---:|---:|---:|---:|
| Rack/envelope outside controller dispatch | 1.711 → 0.863 | 0.848 | 1.633 → 0.863 | 0.771 |
| Routing outside controller | 0.111 → 0.027 | 0.083 | 0.123 → 0.052 | 0.071 |
| Controller/action/filter region, **including descendants** | 7.739 → 0.851 | 6.888 | 7.408 → 0.661 | 6.747 |
| AR relation/load/preload/model/attribute entry union | 2.182 → 0.348 | 1.834 | 1.194 → 0.214 | 0.980 |
| ↳ SQL/driver entry union | 0.449 → 0.213 | 0.236 | 0.240 → 0.134 | 0.106 |
| ↳ Instantiation entry union | 0.226 → 0.146 | 0.080 | 0.123 → 0.073 | 0.050 |
| ↳ Attribute reader entry union | 0.191 → 0.026 | 0.165 | 0.132 → 0.013 | 0.118 |
| Rendering/templates/layout/helpers, **including descendants** | 7.016 → 0.461 | 6.555 | 6.388 → 0.554 | 5.833 |
| ↳ Escaping entry union | 0.272 → 0.062 | 0.210 | 0.263 → 0.048 | 0.215 |
| ↳ Buffer APIs (different scope; see below) | 0.158 → 0.023 | not comparable | 0.139 → 0.020 | not comparable |
| Notification handles/listeners, disabled-log path | 0.186 → 0.010 | 0.176 | 0.162 → 0.010 | 0.152 |
| Session/CSRF/cookie entry union | 0.859 → 0.339 | 0.520 | 1.002 → 0.375 | 0.627 |

Boundary interpretation and uncovered residue:

- Rails' Journey `serve` includes controller dispatch. Routing here subtracts
  Metal `dispatch` from that same process's separate inclusive observation;
  emit's `Router.match` does not include controller execution. Outer envelope
  subtracts dispatch/process_action from the full profiled Rack loop. It
  includes request parsing, response work and lifetimes, not only middleware.
  The large controller row is **not** a filter-chain budget; no isolated
  filter-removal effect is measured here.
- AR includes relation execution/building, selected query-chain entrypoints,
  preloader, association loads/sizes, row construction and attribute readers.
  SQL's adapter/Db calls include their native SQLite work. The emitted index
  has no runtime Arel builder: literal SQL and grouping loops live in its
  controller; those inlined instructions cannot be recovered as model-method
  costs by this entry inventory. This is not complete per-line ownership.
- Rendering covers real Renderer/Template/CollectionRenderer roots versus
  emitted `Views::Articles.index/show` and `Views::Layouts.application`.
  It therefore includes lazy SQL, model reads, crypto and helper descendants.
  Emit's direct appends and inlined HTML remain inside this band. The buffer
  subrow counts Rails OutputBuffer append APIs versus emit allocation/capacity
  bookkeeping only: **it does not count emit's String appends separately**.
- Events count Rails instrumenter handle construction and Fanout start/finish
  (including built-in listener calls) versus emit's two SQL instruments. They
  exclude the instrumented application block. Payload assembly outside those
  roots stays with its caller, so this is not the full price of restoring
  controller/render events or a subscriber-absence certificate.
- Security includes session load/commit, cookie writes and token operations
  versus mini-session serialization/signing and token masking. Render-token
  work overlaps rendering; store commit sits in the outer envelope. It is
  not an equal-security comparison, and GET does not price hostile POSTs.

The defensible location finding is a **large rendering/composition collapse,
plus AR planning/object and envelope/security simplification**. Routing and
filter interpretation alone do not explain the factor. The exact causal split
of the 83% reduction is **unmeasured**: it would require behavior-matched
ablations and low-perturbation ownership attribution, not summing this table.

## What transfers to Lowrail?

Categories below are alternatives within a subsystem, **not additive savings**.
An opt-in [sealed contract](../sealed.md) does not authorize changing session
encryption, model identity or event/exception/assign behavior.

| Subsystem | (a) Replacement/runtime ecosystem dependency | (b) Sealed-tier opportunity | (c) Guarded-tier opportunity |
|---|---|---|---|
| Rack/middleware | Dropping Rails' executor, security/error handling, cache/request lifetimes and HTTP semantics is not transparent | Compile an eligible envelope only with explicit request-shape and ordered middleware/error/ensure proofs; keep live session/security boundaries | Small proven identity layers only, with guards and pre-effect refusal; historical L1 is about 2–3%, not a factor |
| Routing | A replacement route table need not match engines, reloads, formats, constraints or URL hooks | Boot-fixed route recognition/generation plans, with live path/format/defaults and once-only conversion | Existing mutation/receiver/input boundaries still apply; a boot class guard alone is insufficient |
| Controller/filters | Mini controllers are not the real controller/view context; observer-visible assigns and hooks cannot be invented afterwards | Flatten certified chain interpretation while retaining bodies, around/ensure, halting, exceptions, assigns and real controller objects | Per-body exact specializations only; caller-side endpoint guards have already failed the cost gate |
| AR query construction | Literal SQL and Array/grouping bypass Relation/Arel/scopes and adapter hooks; dropping a SELECT changes observable query behavior | Specialize static plans while invoking real Rails statements, scopes, preload association assignment and query instrumentation | Existing plans/statement caches can retain original operations; per-value scope/type/connection changes must stay live |
| SQL/driver | Both still pay SQLite; direct `Db` has a different result/cache/connection protocol | Keep the real connection, transactions, prepared/bind/type/query-cache/error/event behavior | Only certified adapter work; no removal of necessary IO or direct-file second connection |
| Instantiation/attributes | Emit allocates its own Article/Comment with scalar ivars, not real AR AttributeSets, callbacks, dirty tracking, type objects, associations or gem extensions | Real AR construction and live attribute/type operations remain; hoist genuinely static planning only | Same object/type boundaries plus guards; blog's existing instantiate prototype did not establish a request saving |
| Rendering | Fixed strings and direct typed `*_into` calls do not preserve arbitrary Rails helpers/partials/buffers/overrides by themselves | Largest plausible reusable band: compile certified template composition, helper expansion and nonescaping intermediates, preserving fresh storage, encoding, escaping, assigns and evaluation order | Tiny local proofs, otherwise original renderer; the quarantined helper arms are not reusable as-is |
| Events/logging | Omission changes subscribers, runtime/SQL payloads, exceptions, nesting, evented listeners and reentry | Retain real live subscribers/events and their observable contexts; specialize payload/identifier planning only | Preserve dispatch or certify every live mutation boundary; absence at boot is not absence mid-request |
| Session/CSRF/cookies | A signed mini-session is not Rails' encrypted CookieStore, flash or arbitrary gem-owned state | Let real Rails own the session/cookie/CSRF lifecycle; no confidentiality downgrade is an admissible optimization | Keep original security operations; only source/config/input-certified scaffolding can change |

### Comparison with our layer study and hotspot map

The [layer study](layer-ceiling.md) keeps real AR queries/objects and security.
Its eventful handwritten upper bounds were about **−26% index / −37% show**,
roughly **1.35× / 1.59× instruction ratios**, not 2–3×. They also omit real
controller assigns and mid-request helper mutation and retain the historical
stock-Valgrind/brk caveat. They are not certified implementations, and their
percentages must not be directly subtracted from this new pinned-tool cohort.
Their ordered ablation puts most saving in template/partial/layout and helper
composition, not routing or empty filter chains. Restoring events cost about
7.20 / 3.58 percentage points *in that particular specimen*; it is not a
universal event tax to add to this runtime.

The later [pinned-brk512 decision recheck](../bench.md#decision-critical-512-mib-remeasurement-2026-10-20)
independently reproduces show L2_events at **−37.297% [−37.323, −37.282]**
with accepted controls. That new cohort removes the old tool uncertainty for
that observation, not the specimen's semantic gaps or the limits on combining
separate studies.

Roundhouse's own
[Futamura results](https://github.com/rubys/roundhouse/blob/98479d0a32e983af59ab50fa66a65e53056b9039/docs/pipeline/specialization.md#specialization-1-static-query-chains)
provide the same caution from a different protocol/app. Static query chains
keep real Rails objects and measured a null whole-page result on Campfire
(40.97 → 41.07 ms). Planning preloads once improved the chain
(4.78 → 3.82 ms), but the full page only about 3%, with room throughput
54.6 → 58.7 req/s (about 7.5%) in its separate concurrent harness. These
published native measurements are not our Callgrind results or a transferable
percentage: they show how retaining preloading, instantiation and framework
residue differs from replacing that runtime wholesale.

The [hotspot map](hotspots.md), published while this study ran in
[426335d](https://github.com/thomasklemm/lowrail/commit/426335d), independently
puts accepted blog-show baseline work at **8.746 M Ir**, close to our 8.749 M.
It uses randomized instruction-weighted stack sampling with tested fidelity,
not these boundary wrappers. Its blog-show **self** shares include helpers/forms
11.79%, rendering/lookup 6.77%, buffers/escaping 6.94%, AR query/relation 7.01%,
SQL/adapter 4.13%, attributes/casts 2.86%, instantiation/model 0.86%,
session/cookies/crypto 5.61%, CSRF 2.94% and events/logging 2.35%.
These are source-owned work, not all avoidable interpretation. In contrast,
its **inclusive** session 92.46%, events 93.26% and AR-query 81.79% are wrappers
over descendants, not removal budgets. This explains why a giant inclusive
controller/session number cannot be read as a giant standalone optimization.
The map's other request shapes include retained rejections and its cross-app
ranking is provisional; no broad four-app conclusion is borrowed here.

### Recommendation: do not promise a third tier or a 2–3× gain yet

There is a plausible **research hypothesis** for a sealed, subset-endpoint
compiler that retains real Rails objects. There is not yet a measured bridge
or a supported factor. A raw replacement ratio leaves room for a 2× endpoint
in instruction space, but the current real-AR/eventful upper bounds are below
2× even before closing their semantic gaps. A general 3× or whole-app claim
is substantially less justified. Neither follows from the README's 10×.

Using the primary interpreter medians only, a **net-added-work budget** makes
the hypothesis falsifiable. This is arithmetic, not a bridge measurement:

| Endpoint | 2× total target M Ir | Net work allowed above emit | 3× total target M Ir | Net work allowed above emit |
|---|---:|---:|---:|---:|
| Index | 4.551 | **3.005 M** | 3.034 | **1.488 M** |
| Show /1 | 4.374 | **2.960 M** | 2.916 | **1.502 M** |

"Net" includes replacing mini-runtime operations, restoring all observables,
residual checks, transitions and isolation; it is not a budget per bridge
call. The overlapping profile bands cannot be added to estimate that cost.
Reaching 2× from the historical eventful specimens would require roughly
another 32%/20% reduction of their remaining index/show work, before repairing
their omissions; reaching 3× requires roughly 55%/47%. Those cross-study
arithmetic comparisons are motivation, not new controlled effect estimates.

Before making it a product tier, one finite disposable endpoint experiment
would need all of the following:

1. **One real model universe.** Return/retain the actual AR objects, class
   identity, attributes/custom types, dirty/default/missing state, association
   proxies, authorization/serializer/policy hooks and gem callbacks. Never
   serialize a stand-in and call it a bridge. Keep `Current`, connection,
   role/shard, transaction and query-cache state on the Rails side.
2. **One real security/envelope owner.** Rails owns encrypted cookies, complete
   session values, flash sweep, CSRF token production/validation, nonce/CSP,
   executor lifetimes, exceptions, conditional responses and body closing.
   Passing only String session values is an explicitly narrower contract.
3. **Real controller/view state and events.** Preserve ordered and nested
   notifications, payload keys/live objects, SQL/binds/cache metadata,
   subscriber exceptions/mutations and assigns at their original boundaries.
   Merely replaying event names around a finished string is insufficient.
4. **Isolated names without global tax.** Roundhouse's runtime defines
   `ActiveRecord`, `ActionController`, `ActionView` and `ActiveSupport`; it
   cannot simply be required beside Rails. Its existing
   [Futamura bridge](https://github.com/rubys/roundhouse/blob/98479d0a32e983af59ab50fa66a65e53056b9039/src/emit/futamura/bridge.rb)
   uses Ruby 4.1 Box, String-valued sessions/flash and a lent SQLite connection,
   **never a crossing model object**; caches remain separate. Its published
   2.3–4.7× lowered routes / 1.17× whole mix retain an approximately 19% global
   Box tax, not Lowrail-protocol proof. Prefer a namespaced compiled renderer
   that calls real Rails over importing a second framework. Price isolation
   and fallback-route overhead, not just successful endpoint bodies.
5. **Eligibility and fallback before effects.** A missing/incompatible build
   or ineligible input declines before app/subscriber/SQL effects. No replay
   after a partially executed GET, subscriber error or nominal 404/500.
   Keep the guarded default and record every refusal. Sealed acceptance must
   cover structural mutations without pretending primitive/coercion/receiver
   or mutable-table facts are sealed too.
6. **Proof before architecture promotion.** Identical literal body/status/all
   headers, ordered SQL and events, assigns, session/CSRF round trips, error
   and mutation probes; nonzero hits and identical own-suite outcomes. Then
   one predeclared finite cohort with this pinned tool and all controls.
   Price native YJIT separately on accepted quiescent windows/a suitable host.

Thus pursue **measurement of a real-object sealed renderer**, if desired,
not adoption of Roundhouse's mini object/session runtime as Lowrail's third
tier. Reuse its typed/static composition ideas, not its compatibility cuts.

## Evidence and reproduction

[`roundhouse-calibration-results.json`](roundhouse-calibration-results.json)
contains all four cohorts, both controls per implementation, six raw round
vectors, per-worker absolute GC/pool endpoints and JIT histories/counters,
tool preflights and raw-log/dump hashes, unadjusted profile windows, response
hashes/sizes/header names, ordered SQL/event probes, locks and source digests.
It includes the exact small worker/driver/probe/C-gate sources used in this
orb, rather than adding them to the runtime or declaring a reusable pass.
Original Callgrind graphs/logs remain private in this orb; exported hashes
identify them, not a claim that private files are durably available elsewhere.

Basic preparation (all output directories must be fresh):

```sh
mise exec -- bash script/corpus real-blog real-blog-r4
# In .corpus/real-blog-r4, with the repository Ruby on PATH:
RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bundle exec rails db:prepare assets:precompile
# In the read-only Roundhouse checkout at the pin above:
cargo build --locked --bin roundhouse
target/debug/roundhouse --target ruby "$LOWRAIL/.corpus/real-blog-r4" \
  -o /tmp/roundhouse-blog-emit
# Bundle emit, aligning the measured versions/locks described above.
# SQLite3::Backup copies Rails storage/production.sqlite3 to
# /tmp/roundhouse-blog-emit/storage/development.sqlite3 before emit boot.
```

Extract the self-contained measurement sources (inspect them before running):

```sh
mise exec -- ruby -rjson -e '
  data = JSON.parse(File.read(ARGV.fetch(0)))
  data.fetch("reproduction_sources").each do |name, entry|
    source = entry.fetch("source").gsub("/home/user/workspace/repo", Dir.pwd)
    File.write("/tmp/" + name, source)
  end
' docs/passes/roundhouse-calibration-results.json
bash script/bench-valgrind /tmp/NEW-vg
export PATH=/tmp/NEW-vg/bin:$PATH CPATH=/tmp/NEW-vg/include
ulimit -d unlimited
BENCH_JOBS=4 mise exec -- ruby /tmp/calibration_study.rb /tmp/NEW-calibration
# After the primary driver has exited, not alongside its workers:
mise exec -- ruby /tmp/calibration_profiles.rb /tmp/NEW-calibration/profiles
```

The driver always retains rejected cohorts and never reruns one. The native
HTML/event probes are separate from instruction workers. Reproduction on
another checkout must use the measured harness pin, restore the exported
locks and verify source/tool hashes; the embedded driver paths intentionally
retain the actual measured layout.
No native request-rate experiment or new Lowrail support claim is included.
