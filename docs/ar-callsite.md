# Bet F: Active Record query programs, not an AR replacement

2026-10-21. **Branch prototype, bench-only, one priced route, not on main,
not admission.** Ruby 4.0.7, Rails 8.1.4. Native screens use startup YJIT;
the single instruction cohort uses the interpreter. No application source/config
patches beyond the existing corpus dependency overlays. The
machine-readable evidence is [ar-callsite.json](ar-callsite.json).

The implementation checkpoint is
[`b370c47`](https://github.com/thomasklemm/lowrail/commit/b370c47df7b6c5617935feabcb12e66075f2edcb),
based on
[`2f749c1`](https://github.com/thomasklemm/lowrail/commit/2f749c13256ef8876f6065a1173d62969328e76c).
The subsequent request-level pivot is described below. Nothing requires
these files from `lowrail/setup`, changes production admission, or removes
a production guard. The single authorized interpreter cohort and its
pre-count rule are recorded below; no native latency claim follows.

## The seams are different

`bench/experiments/ar_callsite.rb` contains three deliberately separate things:

1. **Final-relation compiler.** Intercept the final synchronous
   `Relation#exec_main_query`. Scopes, default scopes, relation spawning,
   predicate construction and STI discrimination already ran normally.
   Extract typed binds and a bounded shape key; reuse the native visitor's
   exact SQL string and preparable/retryable flags. Execute through real
   `_query_by_sql`, not raw SQLite: prepared-statement and query caches,
   notifications, result construction, readonly/strict-loading and preload
   continuation stay with Rails. Cache fills are lazy; `prime` permits an
   explicitly supplied final relation at boot. This is **not automatic
   boot-time compilation of application call sites**.
2. **Explicit `DirectSite`.** The experiment author supplies a pure lambda
   whose dynamic inputs are StatementCache substitutes. Compile the relation
   at boot, bind real values and spawn one template on each invocation. This
   can skip the chain-building seam as well as Arel visiting. The original
   implementation is used by synthetic checks and real-model micros; the
   later `ar_request_sites.rb` pivot uses the same seam in real requests.
   There is still no automatic source/purity certificate.
3. **Per-model materializer.** Generate a row constructor with the real
   attributes builder's actual type/default objects. Keep the actual
   `ActiveModel::LazyAttributeSet` and `allocate.init_with_attributes`.
   `after_find` precedes `after_initialize`; missing attributes, extra SQL
   projection types, defaults and lazy casting stay on Rails' recipe. An
   eager per-column Attribute array would not preserve those semantics.
   Looking up the builder method owner on every row has a cost.

There is no cache of query results, records, permissions or application
scope results. Neither scope lambdas nor callbacks are replayed for the
planning shadow. It compiles a fresh spawn of the final relation, without
executing a second query or constructing a second record.

### Bounded eligibility, not a certificate

The final-relation path accepts selected native equality/comparison/OR/IN,
fixed projection/order, limit/offset and non-joined includes/preload shapes.
Its key includes the actual connection/visitor and schema identities. Bind
layout, names, before-cast values, database values and types are checked
against the real visitor on each fill; strict untimed runs repeat the
comparison at every optimized execution. Enum casting is native. Default
scopes, STI predicates and query constraints are inputs to the live final
relation, not frozen assumptions about the application.

It refuses non-SQLite adapters, unprepared connections, async execution,
joined eager loads, unknown relation values/nodes, custom types, unboundable
values, query transformers and a full 256-entry cache. Known executed
refusals include joins, `Between`, bound SQL literals and generic `In` nodes.
The original Rails implementation remains the fallback.

These checks are **not a general method seal**. Visitor/type/model method
mutation, a modified constructor, arbitrary concurrent role/shard switching,
Ractors, adapter extensions and mid-request mutation are not certified.
`DirectSite` additionally relies on the caller's purity assertion; its
scope/type/role/shard/connection checks do not establish that assertion.
Suppressed-hook mutations are still a reason not to ship this tier.

## Where to spend the effort

Bet C's source-backed
[profile study](https://github.com/thomasklemm/lowrail/blob/07558fd64c64904ba97cd61a622ff9feddd56c63/docs/hotspots-large-apps.md)
finds pure query-building CPU shares of **25.69% Fizzy / 11.96% Campfire /
8.17% Lobsters**, and allocation shares **35.26% / 15.14% / 9.57%**.
These replace the preliminary broad Fizzy AR figure, not add to it.
Path-family diagnostics (CPU / objects) are:

| App | Arel family | Type/attribute family | Relation/spawn family |
|---|---:|---:|---:|
| Fizzy | 3.89% / 6.25% | 3.04% / 1.37% | 10.49% / 16.87% |
| Campfire-r81 | 2.14% / 3.40% | 3.10% / 2.26% | 4.84% / 6.03% |
| Lobsters | 1.08% / 1.83% | 7.39% / 7.39% | 4.06% / 5.38% |

These diagnostic families overlap; **do not sum them** or treat them as
removable budgets. The profiles have no A/A/fixed-heap/JIT-flat certificate.
They suggest why a final-relation cache leaves most of the interesting
construction work intact, and why Lobsters deserves separate attribute work.

## Real-model micros: chain construction is the larger seam

`bench/experiments/ar_callsite_micro.rb` uses two asymmetric real bind values,
actual models, order/limit/includes, 100 warmups and 500 operations per arm
in three rotated rounds within one production YJIT process. Records and all
warm ordered SQL/name/bind/cache events agree with stock for both inputs.
Native A/A is too noisy for speed inference. Objects per operation:

| Actual model | Stock | Final SQL only | Lean only | Explicit DirectSite + lean |
|---|---:|---:|---:|---:|
| Campfire Message | 660 | 631 | 669.5 | 546.5 |
| Lobsters Story | 940 | 916 | 951 | 833 |
| Fizzy Bubble | 482.5 | 458.5 | 485.5 | 367.5 |

The **113.5 / 107 / 115** savings in the last column include bypassing chain
construction. The **29 / 24 / 24** savings in the second column do not.
Their difference is **not lean synergy or evidence that passes stack**.
No DirectSite-without-lean arm was measured. Lean alone adds objects on all
three models, consistent with Rails 8.1 already caching its builder; park
that standalone idea. These are small fixed query programs, not app-wide
coverage or request savings.

## Kill the final-relation request tier; pivot before spawning

Three short off-A/on/off-B rounds, CPU 2, startup YJIT, identical restored
seeds. The first final-relation + lean screens used 100 warmups and 100
samples per route and fresh worker. Allocation medians per request:

| App/GET | Off-A | On | Decision |
|---|---:|---:|---|
| Fizzy buckets | 9,072 | 9,081 | Kill |
| Fizzy filtered bubbles | 22,543 | 22,538 | Kill |
| Fizzy users | 5,594 | 5,591 | Kill |
| Fizzy workflows | 3,826 | 3,821 | Kill |
| Fizzy notifications | 3,807 | 3,822 | Kill |
| Fizzy detail | 18,358 | 18,271 | Kill |
| Lobsters front `/` | 14,188 | 14,188 | Kill; warm controller cache, **zero SQL** |
| Lobsters story `/s/enr7ye` | 3,552 | 3,544 | Kill; 5 SQL/request |
| Campfire room | 15,515 | 15,399 | Kill; −116 is not the hoped-for tier |

Campfire pagination adds 30 objects; sidebar/search save 30/41. Fizzy's
wall A/A spread is 12–50%; Lobsters front/story 5.43/13.57%; Campfire room
14.70%. These effects are unresolved in wall time, **not latency wins or
latency kills**. Lobsters both response companions pass; three Fizzy routes
and the Campfire companion reject even controls. The Campfire rejection is
an undeclared OpenSSL cookie-IV caller; its loaded file belongs to the
`openssl` gem rather than the policy's Ruby-stdlib root. The corrected
external policy is retained, not used to rerun a failed price until green.

### One request-level DirectSite pivot

`bench/experiments/ar_request_sites.rb` retains the actual
`AssociationRelation` continuation: inverse assignment, strict loading,
callbacks and preloading still run inside Rails. An external ERB handler
rewrites only the pinned bucket partial's exact fixed relation chain; no
app file/config is changed. Campfire's private `find_messages` overlay
preserves both its null-ID lookup **and** reversed last-40 query.

The first pivot screen used 50 warmups and 50 samples × 3 rounds:

| Program | Stock → pivot objects/request | Exact responses | SQL/request |
|---|---:|---|---:|
| Fizzy buckets | 9,085 → 8,323 (−762, −8.39%) | Both seeds pass | 20 → 20 |
| Fizzy detail, EventSummary program | 18,365 → 18,098 (−267) | Off/off variance; no claim | 56 → 56 |
| Campfire room | 15,512 → 15,268 (−244) | Cookie-IV control rejects | 18 → 18 |

The initial pivot had incomplete method/visibility guards. Its allocation
table is exploration evidence, not admission or a price. After adding the
guards, the **identical Fizzy screen** gives:

| GET | Off-A / off-B / on objects/request | Ranges, off vs on | Wall delta / max A/A spread |
|---|---:|---|---:|
| Buckets | 9,084 / 9,083 / 8,498 | 9,068–9,105 vs 8,485–8,517 | −0.026% / 24.453% |
| Detail | 18,365.5 / 18,365 / 18,451 | 18,354–18,381 vs 18,440–18,464 | +3.174% / 51.799% |

Buckets keeps **−586 objects (−6.45%)**, exact status/body/all headers for
both seeds and 2 strict SQL/bind shadows/request. All 20 actual SQL events
remain. There is no wall-time finding. Detail's only active program was
EventSummary (3 hits and 3 guard fallbacks/request; no bucket hits), now
**+85.5 objects/request**. That entire program and its installation have
been removed, rather than made a default-on switch. No lean program runs
in the request pivot.

The final source checkpoint (creator-key encoding fixed, EventSummary
removed), same two-route screen and settings:

| GET | Off-A / off-B / on objects/request | Ranges, off vs on | Wall delta / max A/A spread |
|---|---:|---|---:|
| **Buckets** | **9,084 / 9,083.5 / 8,499** | **9,071–9,110 vs 8,489–8,516** | +8.193% / 14.188% |
| Detail, program removed | 18,365 / 18,367 / 18,358 | 18,353–18,382 vs 18,344–18,377 | −13.974% / 7.592% |

The retained candidate saves **585 objects/request (−6.44%)**, with exact
bucket responses for both seeds in every round,
20 SQL events and 2 strict site hits/request. Detail has **zero** site hits
and is flat within its ranges; its response controls still reject, so the
two-route command correctly exits 2. No detail or latency claim follows.
Bucket GC time is 0.518/0.577/0.537 ms per request, RSS 216,076/215,480/
217,313 KiB (off-A/off-B/on), diagnostics only. Raw samples and the earlier
regressing screen are retained, not replaced by a green-only export.

### Directed fallback controls, not a general seal

On entry to the real bucket partial, **after authentication and mid-request**,
the external `ar_request_sites_check.rb` probe exercises changed scope,
added default scope, current/global scopes, replacement reflection, loaded
association, unexpected receiver, model-method private visibility,
redefined relation method, and a generated-source pin mismatch. Two entropy
seeds × 13 states (including cold/warm/restored positives) × 3 fresh arms:

- **26 paired status/body/all-header and ordered SQL/bind comparisons pass.**
  Positive/restored calls hit twice/request. Every mutation has zero hits
  and falls back to stock; source mismatch does not install the rewrite.
  Making the scope private preserves the stock **HTTP 500**, not a swallowed
  error or a successful cached result.
- Guards resolve effective `UnboundMethod` **and visibility**, rather than
  trusting hook notifications, on named scopes, model-specific relation
  delegates and the skipped builder methods. They check live default/current/
  global scopes, actual receiver/readers, schema/type/role/shard/connection,
  prepared/visitor identity, reflection identity/options/keys, unloaded
  association and the canonical template source pin.
- Primary, queue and cable snapshots match. **Full-state probe exits 2**:
  SolidCache `created_at` differs, including off-A vs off-B. This remains
  a named coordinator-accepted rejection, never normalized/excluded into a
  whole-DB certificate. Complete comparison booleans remain in JSON.

The stronger byte/encoding capture found a real compiler metadata gap:
`creator_id` bind-name bytes were `Y3JlYXRvcl9pZA==` in every arm, but stock
was **UTF-8** and the handwritten `creator_id:` key was **US-ASCII**. The
compiler now uses the actual creator reflection's `foreign_key` string and
guards that reflection. Raw captured bytes **and encodings now match**;
full SQL metadata digests for the warm seed-0 request are identical across
all three arms (`588c51df…`). The digest was **not relaxed**. Earlier Marshal
digests additionally encode object-sharing identity; the typed capture uses
the existing byte/encoding-preserving value format, explicitly retaining
Symbols. Ruby `==` alone had missed the compatible-ASCII encoding difference.

A second raw-capture probe reproduces the native screen's natural login and
50 warmups of both routes **before** the companions. All **20 GET SQL events,
including raw bytes, encodings and typed bind metadata, match** for both
seeds after the companion session exists; all mutation/restored comparisons
also match. The initial companion's **login-inclusive 30-event digest still
rejects off/off**: its rate-limit `solid_cache_entries` INSERT carries a
different serialized cache-expiry payload from the unpinned warmup. The
single differing event is outside the bucket GET and outside the proposed
Ir windows, and the typed digest remains red rather than being normalized.
This is an additional named **login cache-payload rejection**, distinct from
`created_at`; it is not a certificate for login or all native-screen SQL.
The JSON retains those false checks as well as the successful GET checks.

These are directed probes for the requested cases, not a proof covering
arbitrary callbacks in guard predicates, every transitive framework method,
concurrent mutation or complete Ruby reflection/backtraces. No use of bet D's
experimental active flag or guard removal is involved.

### Single authorized interpreter cohort: rule before counting

`ar_request_ir.rb` reuses `RequestPairs.heap_instructions` and `HeapWindows`,
only `/buckets`, clean detached harness; 6 rounds, seed 41231, jobs 1,
off-A/off-B/on, N=0/10, both total and GC-excluded windows. Guards and
completed-hit counters stay inside the price; SQL shadowing is untimed.
The existing Fizzy workflow's five init-slot floors are
`3350000,300000,460000,30000,20000`; an untimed tool=none off/on check in
both phase orders must first retain exact pages and add none.

**Reject the entire finite cohort** on any source/tool/mode/brk/hit/heap
failure. Before any counter window, the coordinator changed the project-wide
A/A gate: **both total and no-GC A/A 95% intervals must lie wholly within
±0.1%; neither must contain zero**. This replaces this experiment's earlier
contains-zero/±0.5% rule before counting. The shared helper's legacy
contains-zero summary remains unchanged and is retained as a diagnostic;
the adapter's `decision.json` applies the project rule and additionally
checks zero new pages in every measured window, not just equal capacity.
Call a win only if **both** on/off upper 95% bounds are below
−max(0.5%, 3 × largest absolute A/A bound). No filtering or retry-to-green.
An initial tool=none launch failed before app boot because a relative worker
path was resolved from the app directory. The absolute-path fix and this
rule change precede every counted window; the failed launch is retained.

### Slot 3 result: accepted scoped interpreter price, no retry

Measured clean detached
[`87c3c19`](https://github.com/thomasklemm/lowrail/commit/87c3c1974c424eabef5178f518641d013dd601b3),
with the guarded query runtime unchanged from
[`addf55e`](https://github.com/thomasklemm/lowrail/commit/addf55e00b080d2627503b7f10a74bbe68e17ed1).
Only Fizzy **GET `/buckets`**, one closed fixture, interpreter; no other
request or app is priced. A/A first:

| Metric | A/A paired median | A/A 95% interval | Project gate |
|---|---:|---:|---|
| Total Ir | −0.003299% | [−0.056066%, +0.030632%] | Pass, wholly within ±0.1% |
| GC-excluded Ir | −0.008940% | [−0.048641%, +0.019714%] | Pass, wholly within ±0.1% |

| Metric | off-A / request | on / request | Paired change [95% interval] |
|---|---:|---:|---:|
| Total Ir | 40,169,918.95 | 37,963,881.65 | **−5.486472% [−5.578917%, −5.415108%]** |
| GC-excluded Ir | 40,170,145.70 | 37,961,128.65 | **−5.499293% [−5.545698%, −5.448101%]** |
| Objects, diagnostic | 8,984.45 | 8,420.60 | −6.260055% [−6.313500%, −6.245269%] |

Displayed arm values are medians; paired percentages are not ratios of those
medians. Both Ir upper bounds beat the predeclared −0.5% threshold. All
18 workers / 72 windows pass mode, source/tool/brk, exact-page and zero-new-page
gates. Page targets are 2047/367/1128/148/199. Each full on window completes
20 guarded hits, zero fallbacks: 240 hits total. SQL shadowing stays outside
the counters. The tool=none preflight passes all four workers / 16 windows.
An independent audit reconciles **72 raw dumps and 36 N=0 subtractions**,
every page/hit ledger and both disabled JITs. No workers were excluded.

The original `decision.json` is retained verbatim. A report-only local-variable
reuse made its `project_aa` field contain just the last interval; both
per-metric intervals remain in the unchanged summary, and both were checked
before that reuse. The source fix changes only that post-count serialization,
not any window, gate, effect or measured runtime. The JSON appendix supplies
the labelled intervals separately and does not replace the original receipt.

Named **login-cache `expires_at`** and **SolidCache `created_at`** off/off
rejections remain. Exact post-login response/SQL controls do not become a
whole-DB certificate. This is the coordinator-accepted **branch prototype,
bench-only, one route, not on main, not admission** price; not production
support, generally certified compilation, or a native YJIT speed claim.

### One real-Puma follow-up: declared before HTTP load

Use the unchanged shared `script/rps` at
[`b1e239f`](https://github.com/thomasklemm/lowrail/commit/b1e239f5bfcd2354166aeabddf1e6cc7a605fcaf),
an isolated identical corpus copy, the same four-DB seed, and the independent
zero-unit YJIT artifact. Only `/buckets`; natural CSRF/password login;
`exploration_only: true` skips only BlockLinkSpecimen. No app/Puma config edits.
Ten fresh-server rounds, off-A/on/off-B rotation, four workers × one thread,
c16, 5-second warmup / 20-second load; server CPUs 0–3, client 4–7;
oha 1.14.0, fixed upstream binary digest. Post-warmup/load GC/RSS snapshots,
both seeds' exact status/body/all-header workflows and all errors are retained.
Do not overlap with Ir or pool with native Rack screens. No forced GC or
JIT-flat claim. Report A/A and p99 first; require zero errors, passing cold/warm
exactness and the entire on/off RPS interval above **3 × the largest absolute
A/A bound** for a clear throughput win. Otherwise unresolved, never retry.
The RPS check has not run at this export checkpoint.

## Exactness evidence and its boundary

- `mise exec -- ruby bench/experiments/ar_callsite_check.rb`: **143 paired
  cases, 138 strict SQL/bind checks, 43 materialized rows, 27 plans**, no
  differences. Asymmetric owners, enum/STI/default scopes, projections,
  callbacks, query constraints with reload, cache hits/bypass, an unprepared
  window, schema reset, custom-type refusal and a second database containing
  a distinct `SECOND-DATABASE` row are exercised. Synthetic SQL comparison
  excludes `SCHEMA` events; real-model micro warm comparisons do not.
- An external `RUBYOPT` probe (`ar_callsite_suite.rb`) installs the prototype
  after normal test boot, with strict planning shadow. `lowrail verify`
  reports **234 Campfire tests passed, 671 assertions, 5,643 identical ordered
  queries**; the prototype completes 1,540 planning checks and 2,292 rows.
- Fizzy: **124 identical outcomes, 117 passed and 7 baseline errors**, 458
  assertions and 5,322 identical ordered queries. Prototype: 922 planning
  checks and 2,014 rows. The errors include upstream `Current#reset_all` and
  related model tests; this is **not a green own suite**.
- The ruby-bench Lobsters snapshot has no own test directory. No suite claim
  is substituted for it.

The suite's public zero-unit production/YJIT artifact correctly refuses in
test/interpreter mode. Public fast-path hits are zero; the above counters
belong to the external experiment, **not sealed test admission**. Identical
test outcomes and SQL traces do not prove complete response/assigns/events,
external services, async completion or arbitrary database-state equivalence.

### Preload plans: reuse the existing mechanism

Non-joined `includes`/`preload` stay with Rails after the query program.
Separately, an isolated Campfire-r81 production artifact with the existing
sealed preload pass completes **one plan per warm room request**, with **8
strict frontier comparisons across 4 requests, zero mismatches**. The off
probe has zero hits. This is diagnostic reachability, not a new preload
implementation, a combined benchmark or proof of generally safe admission.
Dynamic/polymorphic/scoped/through loader scheduling must preserve actual
frontiers, ordering, identity sharing and callbacks; the existing
[preload-plan shadow](ar-equivalence.md) is a better starting point than a
handwritten includes tree.

## What a generally applicable compiler still needs

The promising boundary is **before relation spawning**, not after it:

1. Discover a source call site and lower its full pure chain into a plan with
   live typed bind slots. Prove exactly-once input evaluation, in order.
   Do not execute arbitrary scopes at boot to learn their shape.
2. Certify default/named scopes, STI, enum/type/schema/query-constraint and
   effective method facts. Reject time/current-user/tenant-dependent scope
   effects unless they become explicit live inputs with equivalent ordering.
3. Dispatch plans by actual adapter, role, shard, connection and prepared
   mode; retain native query-cache/instrumentation/retry/error behavior and
   connection-local statement-cache ownership. Keying one old connection is
   not a general switching design.
4. Keep Rails' lazy attribute container unless a new container can preserve
   its missing/default/projection/type/error/dirty-tracking semantics. Keep
   callback bodies and ordering live; certifying an empty chain at boot is
   insufficient for a mutable process.
5. Compose with certified preload frontiers and test on unchanged app suites,
   with exact responses, SQL/binds, persisted effects and real fast-path hits.
   Full gates and Thermos are still prerequisites for any main integration.

The experiment supplies a narrow executable query-program seam and evidence
for investing in source-level bind programs. It does not supply that general
certificate, and the native screens below must not be promoted into prices.
