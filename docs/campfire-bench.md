# Campfire: benchmark routes, certified reachability, and a pricing request

2026-10-21. **Untimed discovery, not a speed or sealed-support claim.** No
Callgrind run, counter window, timing cohort or measurement slot was used.
The authorized follow-up changes only Ruby parser compatibility in Lowrail;
no default, quarantine, admission inventory or upstream app code was changed.
The machine-readable [appendix](campfire-bench.json) retains the counts,
pins, refusals and failed gates. Raw responses, cookies, database snapshots
and complete verifier receipts remain private under `.lowrail/private/`.

**Conclusion:** the separately pinned Rails-8.1 app now has an instantiation-only
sealed artifact completing **52 of 54 reachable rows per warm room request**.
N=10 fixed-heap preflight passes off/on in both phase orders. The non-system
suite is green off/on with the production artifact refusing in test. Browser
outcomes pass; the fixed browser diagnostic classifies the query-count
rejection as test/other-thread nondeterminism. Raw cold HTTP identity rejects
entropy. The first complete companions also reject Redis expiry, internal
features and unavailable cached binds. **Pricing is conditionally pre-approved
but remains blocked and unrun.** Sections 1–9 retain the initial discovery/failed prerequisites;
[§10](#10-authorized-prerequisite-follow-up) supersedes their zero-hit/build/heap
status without discarding the original failures; §11 records the bounded
diagnostic and first negative companion results.

## 1. Which requests do public benchmarks exercise?

The route list is sourced, not invented:

1. Basecamp's [October 8 performance review](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/docs/performance-review.md)
   and its [executable contracts](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/bench/contracts.rb)
   at verification SHA `ec02debb3e44f40b8778a6a42db3c4515b2f9eaf` use:
   - `GET /rooms/{watercooler}`;
   - `GET /rooms/{watercooler}/messages?before={busy_060}`;
   - `GET /users/me/sidebar`;
   - `GET /searches?q=coffee`;
   - `POST /rooms/{hq}/messages`, accepting Turbo Stream HTML.

   The measured Rails app is [0aa339d81e0501841e3f23f0dd6e9b2e06e6b60d](https://github.com/basecamp/once-campfire/commit/0aa339d81e0501841e3f23f0dd6e9b2e06e6b60d).
   The report uses 16 clients, four server cores, gzip, three eight-second
   rounds after two-second warmups, and a mixed writer at ten messages/second
   into HQ, separate from Watercooler reads. Avatar, CSS, health and Cable are
   auxiliary scenarios. This investigation does **not** reproduce that load.
2. Roundhouse's [published Campfire coverage](https://rubys.github.io/roundhouse/bench/campfire/)
   was read live on October 21. Its pinned
   [harness](https://github.com/rubys/roundhouse/blob/1c84d346361237ef9a99b6c01cead7c340532330/scripts/bench-campfire)
   is `1c84d346361237ef9a99b6c01cead7c340532330`; the reported app pin resolves to
   [11d3fb9ce01faad3384807563053ba86126f747e](https://github.com/basecamp/once-campfire/commit/11d3fb9ce01faad3384807563053ba86126f747e).
   Its eight HTTP routes are `/rooms/1`, `/rooms/1/messages?before=50`,
   `/users/me/sidebar`, `/searches?q=coffee`, `/users/{avatar}/avatar`, a
   stylesheet under `/assets/`, `/up`, and `POST /rooms/2/messages`.
   The optional WebSocket tier opens `/cable`, subscribes and checks fanout.
   Its Ruby 4.0.5 / Rails 8.2-alpha app, 50 users / five rooms / 100 messages
   per room, server/process topology and cache policy are not this fixture.
3. [Campfire: Three Rubies, September 22](https://intertwingly.net/blog/2026/09/22/Campfire-Three-Rubies.html)
   also exercises room and messages pages, at app pin `ed0f9a5`, with the
   50-user/five-room seed and explicit cache/thread caveats.
4. The inspected [ruby-bench source](https://github.com/ruby/ruby-bench/tree/d2a74a9a45b118b9026c857cc18d44614a023751)
   did not supply an authoritative Campfire profile: its Rails posts workload
   is not Campfire. No authoritative Campfire-specific ZJIT route profile was
   found. Neither absence is a claim that no such benchmark exists anywhere.

## 2. Why a separate `campfire-r81` fixture?

The existing `script/corpus campfire` entry remains **unchanged** at
[af4dd9fd599c65e0e0fc1f614ee469f70156ddf5](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5).
It declares `load_defaults 8.2` and schema version 8.2. Downgrading those
declarations would alter framework behavior, not just dependencies.

`script/corpus campfire-r81` instead selects
[02023b0f0cafc4d66e06e43be072cf4d6ca328fa](https://github.com/basecamp/once-campfire/commit/02023b0f0cafc4d66e06e43be072cf4d6ca328fa)
(December 1, 2025), the newest main ancestor immediately before
[6197f20a3184cf034f6e1f8217c0d62a2194e881](https://github.com/basecamp/once-campfire/commit/6197f20a3184cf034f6e1f8217c0d62a2194e881)
upgrades the defaults to 8.2. It boots unchanged with Ruby 4.0.7 / Rails 8.1.4.
The [overlay](../fixtures/corpus/campfire-r81.patch) changes only
`.ruby-version`, `Gemfile`, `Gemfile.lock`, per [compatibility rules](compat.md).
It adds `ostruct` (not a Ruby-4 default gem) and pins `net-http` 0.6.0.
With default net-http 0.9.1, the plain suite had two DNS-mock failures because
the TCPSocket call acquired an `open_timeout: 60` keyword. The dependency pin
restores the app's test contract; no implementation/test shim was added.
The failed plain run is retained, not counted as a green baseline.

**Not equal to the October 8 performance fixture.** All five route verbs,
controller actions and principal response types survive, and the executed
contracts below pass, but the intervening implementation changes are material:

| Area | `campfire-r81` versus both `af4dd9f` and profile pin `0aa339d` |
|---|---|
| Routes | Five primary shapes unchanged. Later bot routes add JSON index/update/delete and boosts; the older pin has only the bot POST. |
| Room GET | No `cache_read_response`/RecordCache; older membership lookup and presentation preloads; unconditional message-id lookup. |
| Pagination | `with_creator`, not `with_presentation`; `fresh_when @messages`, not rendered-body SHA ETags plus response caching. |
| Sidebar | Ruby partition/sort of visible memberships, not newer direct-room SQL scopes; no response cache. |
| Search | `reachable_messages.search(...).last(100)`, not `search_reachable`; no response cache; implicit collection render rather than explicit cached presentation-key collection. |
| POST | Broadcast renders the message, then the response renders it again (the inner fragment can hit); later code passes one `@message_html` to both. |
| Views | Older `cache message` / `cached: true`; later presentation keys (v7 at the profile pin, v8 at `af4dd9f`) cover more dependencies. Room stream uses stock Turbo channel, not `RoomMessagesChannel`. Composer is Trix/rich-autocomplete, not the newer Lexxy/unfurl/mention prompt. Later sidebar room-creation permission gate is absent. |

The four controllers for these five actions and `config/routes.rb` have no
further differences between `0aa339d` and `af4dd9f`. Across their primary
view directories, the additional difference is the message partial's
`presentation-v7` → `presentation-v8` cache key. This does not assert equality
of their entire applications. The focused before/after diffs were retained.
Do not transfer a cost, cache-hit ratio or optimization recommendation across
these pins. In particular the newer importmap/CSP hotspot in the
[earlier draft](upstream-drafts/campfire.md) is absent at `campfire-r81`.
The [earlier fragment study](passes/campfire-fragments.md) remains historical;
its rejected controls are not rehabilitated here.

## 3. Own-suite gate, before the census

One Minitest worker, seed 41231, frozen bundle. The plain non-system suite
passes 234 tests / 671 assertions. `lowrail verify` with the public default
artifact then reports identical outcomes for all 234 tests, 5,643 identical
own-thread SQL queries, zero load differences/unstable entries, zero hits.
The separate real Selenium/Chrome suite passes **8 tests / 60 assertions in
each arm**, with 2,610 identical own-thread queries. Four browser tests have
other-thread SQL-interleaving advisories; these are not erased or called exact
cross-thread identity. No browser suite was omitted from the gate.

These are **no-op compatibility gates**, not proof that a sealed optimization
works. A future hit-bearing artifact must rerun both suites with its own
supported test certificate and preserve the same per-test identities.

## 4. Production scenario and honest identity results

[`campfire_scenario.rb`](../bench/experiments/campfire_scenario.rb) boots the
real production app and makes HTTPS Rack requests through natural login,
cookies and CSRF. [`campfire_survey.rb`](../bench/experiments/campfire_survey.rb)
restores an independent SQLite copy and flushes a **dedicated disposable**
localhost:6379 Redis between serial off-A/off-B/on processes. Old Cable and
Resque hard-code that address; no app config is patched to relocate them.
Sealed observation seams load symmetrically; only the public zero-unit
`all-opt-in` artifact is enabled. The public `--sealed` build is separately
retained as a failure (next section), not silently repaired or hand-pruned.

Preparation loads upstream SQL fixtures at a fixed March 2 timestamp, then
inserts 120 literal messages/rich texts without callbacks/jobs and rebuilds
FTS. There are 133 messages total, 130 in Watercooler. The input-derived
expected windows are 40 room messages, 40 before anchor 2000060, and 12 coffee
matches, including exact ordered DOM message IDs. No expectation is taken
from the app's pagination/search implementation. POST validates persisted
body, room, FTS and Turbo append response. State uses a private random secret,
copied unchanged into all arms; real clock and entropy remain unmodified.

| Route | Concrete path | Status | Cold response bytes |
|---|---|---:|---:|
| Room | `/rooms/486777696` | 200 | 452,461 |
| Pagination | `/rooms/486777696/messages?before=2000060` | 200 | 416,817 |
| Sidebar | `/users/me/sidebar` | 200 | 28,684 |
| Search | `/searches?q=coffee` | 200 | 150,106 |
| POST | `/rooms/201306877/messages` | 200 | 9,368 |
| Auxiliary index | `/rooms` | 302 | 0 |
| Auxiliary refresh | `/rooms/486777696/refresh.turbo_stream?since=0` | 200 | 839,244 |

All three arms pass these response contracts, but **raw HTTP identity rejects**
in off/off as well as off/on. Every nonempty body differs. A DOM audit in
both comparisons localizes observed differences to CSRF meta/hidden tokens
and the new POST's timestamp/sort/datetime attributes. Differing headers are
`set-cookie`, `x-runtime` and, where body-dependent, `etag`. Bodies/headers
were not normalized to manufacture equality. Full exit database row hashes
also differ for sessions, clock-stamped messages and their dependent records.

Each cold arm leaves **one `Room::PushMessageJob` queued**; each census arm
leaves three. No Resque worker or WebSocket client was running. Publishing
two Redis Cable broadcasts on POST is not proof of subscriber delivery or
completed pushes. This is a named **pending-background-work boundary**, as
with Fizzy's [SolidCache precedent](block-link-specimen.md), not an accepted
end-to-end completion gate. A read-only room preflight leaves zero queued jobs.

## 5. Reachability and hotspots

TracePoint entry counts and notification census are untimed. They do not read
bindings, replace app methods, replay fallbacks or install pricing adapters.
Three restored arms agree on the call counts below. Each route runs three
times in a fixed sequence: “cold” means its **first occurrence**, not an
independent empty-cache boot; earlier routes can have populated fragments.
Warm and repeat counts agree. SQL includes cache/schema/transaction events.
Lowrail observer entries are kept in the appendix but not double-counted as
Rails helper calls in this table. Persistence/FTS validation runs after
observation ends. The initial census accidentally counted its three SQL
queries and two instantiated rows on POST; that diagnostic is retained,
not used as an application opportunity count below.

| Route | SQL first / warm | link first / warm | form first / warm | token first / warm | warm instantiate / preload entries | actual Lowrail hits |
|---|---:|---:|---:|---:|---:|---:|
| Room | 117 / 18 | 244 / 3 | 321 / 1 | 322 / 1 | 54 / 16 | 0 |
| Pagination | 130 / 8 | 240 / 0 | 320 / 0 | 320 / 0 | 47 / 5 | 0 |
| Sidebar | 14 / 12 | 10 / 8 | 0 / 0 | 2 / 2 | 28 / 8 | 0 |
| Search | 39 / 10 | 34 / 4 | 41 / 1 | 43 / 3 | 20 / 8 | 0 |
| POST | 17 / 17 | 6 / 6 | 8 / 8 | 8 / 8 | 5 / 4 | 0 |
| Index | 3 / 3 | 0 / 0 | 0 / 0 | 0 / 0 | 3 / 1 | 0 |
| Refresh | 61 / 10 | 102 / 0 | 136 / 0 | 136 / 0 | 89 / 7 | 0 |

Warm room and pagination each get **40/40 collection-cache hits**, so stock
`collection_with_template` executes **zero** times. Sidebar has two cached
direct-membership fragments and one uncached placeholder collection call.
Search still enters stock collection rendering once for 12 messages, but
inner message blocks hit. POST enters no eligible nonempty collection;
its eight forms/tokens come from the new message's actions. It invokes
`Turbo::Broadcastable#broadcast_append_to` once and the Cable server broadcast
twice. There is no Inertia/props path and no admitted endpoint unit.

Separate StackProf CPU sampling (0.2.28, 1 ms, five warmups then exactly forty
requests per route, no throughput/latency output) supplies **rough attribution**:

| Route, off-A | Samples | Action View self | helpers self | AR self | Cable / Turbo self |
|---|---:|---:|---:|---:|---:|
| Room | 214 | 21 | 11 | 57 | 0 / 0 |
| Pagination | 98 | 2 | 1 | 32 | 0 / 0 |
| Sidebar | 105 | 13 | 7 | 26 | 0 / 0 |
| Search | 106 | 12 | 8 | 20 | 0 / 0 |
| POST | 136 | 7 | 8 | 39 | 0 / 1 |
| Refresh | 262 | 23 | 8 | 65 | 0 / 2 |

Helpers overlap the view band; native frames and other threads are included
in the denominator, not forcibly assigned to a Ruby library. Zlib inflation,
digest updates and SQLite steps are prominent native leaves on cached reads.
The appendix also preserves inclusive bands: AR middleware and Turbo request
wrappers contain most rendering samples, so their large inclusive shares
**must not be called AR planning or Cable cost**. Small sample counts do not
price a pass; zero Cable self samples do not mean free network delivery.
The index's three queries/no rendering and a 302 are sufficient census, not a
useful sampling target. An initial sampler export lacked self attribution;
the second fixed-count diagnostic added it, without a performance comparison.

## 6. What existing passes do, and what they refuse

- **Guarded link/route and AR/memo units:** quarantines remain untouched.
  `all-opt-in` produces zero units: props reports `gem_absent`, endpoint
  `unsupported_application`; the others remain quarantined/sealed-only.
- **Sealed link:** direct build-only inspection returns
  `eager-loaded ArticlesController required; keep lazy applications original`.
  Campfire has no such target; this is not a request to force-load one.
- **Form/token/collection:** direct build-only checks each return
  `eager-loaded targets required; keep lazy applications original`. Their
  production certificates require Article/Comment/ArticlesController and
  the literal blog form, not merely the right Rails version. Campfire's
  rich-text composer and Boost forms are outside that domain.
- **Full public sealed build:** stops with `ArgumentError: invalid version:
  current` in `Lowrail::ARPlanSites.inventory` on the app's locked Prism 1.4.0.
  Before abort, builders report 19 candidate instantiation variants and 34
  eligible preload associations / 26 declined. **Those are build inventory,
  not a published artifact, runtime activation or fast-path completions.**
  Do not bypass that failure or the known broader sealed ancestry issues.
- **CSP/importmap memo:** absent in this older app; no transfer of the newer
  draft's hotspot or rejected prices. Cache native fragments; do not disable
  them to make helper reachability look better.

Expected hits for the artifact tested here are **exactly zero on every route**.
For future certification, the helper columns are reachable-call ceilings,
not promised hits: warm token opportunities are 1/0/2/3/8 for the five primary
routes, link 3/0/8/4/6, form 1/0/0/1/8, stock collection 0/0/1/1/0.
AR row-dispatch ceilings are 54/47/28/20/5; STI, custom methods, callbacks,
notifications, epoch changes and actual admission can reduce them. Preload
entries include empty/non-eligible work and cannot be called saved queries.

## 7. Fixed-heap precondition: failed before any slot

The first Fizzy cohort was invalid because every arm grew heap pages. This
run checks that prerequisite **untimed first**, using the pinned 512 MiB-brk
Valgrind 3.19 build from `script/bench-valgrind`, **`--tool=none`**, the shared
`HeapWindows.prepare_heap`, and the reference five slot floors
`[1000000,250000,100000,20000,10000]`. Fifty room warmups precede preparation;
N0/N50 checks run with GC enabled and with GC explicitly disabled.

All arms start at page vector **[611,306,246,99,100]**. In **each** arm:

- both N0 windows retain it;
- GC-enabled N50 grows pool 2 (160-byte slots) **246 → 247**;
- GC-disabled N50 grows that pool **246 → 458**;
- other pools do not grow; no `brk segment overflow` is observed;
- zero jobs remain queued.

Verdict: **`rejected_heap_growth`**, not “stable because all arms grew alike.”
No floors were tuned and retried until green. A future fixed-floor proposal
must cover the no-GC live allocation demand and rerun an explicitly declared
untimed preflight; it must not reuse this failed check as a pass. This is
only room feasibility, not a heap certificate for POST/search/other routes.

## 8. Ranked plan and ONE proposed interpreter-Ir cohort

1. **Price sealed homogeneous AR instantiation on warm room reads first.**
   The 54 row-dispatch opportunities survive fragment caching, unlike the
   disappearing message forms. Reuse the existing instantiation algorithm;
   preserve lazy attribute casting, callbacks, SQL/events and live row-boundary
   checks. Need a usable public isolated artifact, resolution of the Prism
   build incompatibility, exact admission/ancestry and test certificates, and
   a per-model census separating STI/refused rows. No new AR runtime is
   authorized by this report; no speed percentage is forecast.
2. **Then examine sealed preload planning.** Warm opportunities are
   16/5/8/8/4 entry calls across the five routes. Cost attributable to planning
   (not all AR) must justify it; certify scopes, loaded state and metadata.
   Do not combine it with the first price, which would confound the result.
3. **Broaden token/collection certificates only for a priced target.**
   Search offers three live token calls and one collection; sidebar two and
   one. Warm room offers one token and no stock collection. The accepted blog
   form/token/collection result does not forecast a Campfire win. A composer
   scaffold is a new shape with live model/ActionText boundaries, not a
   string substitution for the blog form.
4. **POST/render/Cable later.** Six link/eight form/eight token calls plus
   duplicate render make it interesting, but its pending push job, clock,
   transactions and fanout require a real completion/delivery oracle first.
   `/cable`, avatar/CSS/health and mixed load stay out of the first cohort.
   Native inflate/digest/SQLite leaves are already native; no unsupported
   memoization or cache-policy rewrite is inferred from their self samples.

**Cohort request `campfire-r81-room-instantiate-v1` — NOT READY / unexecuted.**
Ask the coordinator to approve the bounded prerequisite work before any
runtime/build change, then authorize **one** interpreter-Ir cohort only after
all gates pass: the literal room fixture and route above, Ruby 4.0.7 / Rails
8.1.4, only sealed instantiation versus symmetric off-A/off-B (no preload,
helper or endpoint units), current expected hits 0 and prospective ceiling 54
rows/request, with the actual hit count fixed by the preflight ledger.

Reuse the accepted [blog protocol](passes/production-interpreter-reprice.md)
at [553e7aa](https://github.com/thomasklemm/lowrail/commit/553e7aafa88754fd32359e5e11ba0cc5bfcd6f65):
six randomized independent rounds, seed 41231, three serial arms, N0/N50
subtraction, balanced total/no-GC order, exact pages in all five pools,
512 MiB-brk/placement/interpreter gates, both A/A 95% intervals containing
zero within ±0.5%, one frozen-source cohort with all rejected rounds retained.
The reference −15.23% is **blog-only**, not an expected Campfire result.

Blocking prerequisites: successful untimed fixed-heap preflight with declared
capacity; public isolated build and nonzero certified hits; green own-suite
and browser parity for that exact artifact; complete cold entropy companions
covering raw headers/body, SQL/events/loads and exit effects without deleting
fields; native subscriber/once-only/deopt controls, all repeated post-cohort.
**No timing or slot request may be acted on while these blockers remain.**

## 9. Original Rails 8.2-alpha compatibility evidence

The unmodified original `af4dd9f` boots on its frozen Rails 8.2-alpha bundle.
Default verification runs 634 identities: 632 pass, two libvips skips, equal
per-test outcomes, zero hits and zero load-census differences. Strict SQL
**rejects** one concurrent counter-repair test at 41 → 40 own-thread queries.
Its own two internal threads still race with one Minitest worker.

Per coordinator instruction, the **entire fixed diagnostic**, with no retries
to green, is three off/off and three off/on pairs of that single test,
serially, same seed 41231:

| Pair | off/off SQL | off/on SQL |
|---|---:|---:|
| 1 | 40 → 41 | 40 → 41 |
| 2 | 41 → 41 | 41 → 41 |
| 3 | 41 → 41 | 41 → 41 |

All twelve executions pass with zero hits. Off/off reproduces the variation:
classify as **named concurrency nondeterminism**, retaining the original
strict rejection rather than changing its result or suppressing SQL.
The separate original production sealed build emits only one SHA memo unit;
the blog-only helper certificates refuse the framework/application domain.
No hit-bearing request or full sealed suite was claimed. **No Rails 8.2
support or speed claim** follows from this evidence.

## 10. Authorized prerequisite follow-up

Only the parser compatibility fix and untimed prerequisites were authorized.
No helper/token/collection domain was broadened. No POST message or Cable
experiment was added; room-only modes still perform the natural login POST.

### App-locked Prism: exact grammar or explicit refusal

The failing public build loads **the app bundle's Prism 1.4.0**, not Lowrail's
development Prism 2.0.0. Its first failing call was
`ARPlanSites.inventory` → `Prism.parse_file(..., version: "current")`.
1.4 rejects `current`, `4.0.7`, and `4.0` on this Ruby; selecting an older
development grammar or `latest` would not meet the exactness contract.

All 20 existing Ruby parse/lex sites in `gem/lib/lowrail` and the public helper census
now obtain an explicit **`RUBY_VERSION`** from one build/discovery-only admission
check. It memoizes success or refusal. The app's loaded parser is never
replaced. Unsupported grammar becomes `unsupported_prism_grammar`, naming
both versions; parser-independent builders still finish. Existing per-source
refusals keep their sites; an escaping refusal names the actual selected pass.
Diagnostic-only `bench/` parser callers remain outside this runtime fix.

The new public sealed-build regression locks a real app bundle to Prism
1.4.0: it fails on the base at `invalid version: current`; after the fix it
passes **1 test / 11 assertions**, including surviving Widget instantiation.
Thermos correctness and maintainability reviews ran independently. The
maintainability follow-up confirmed its failed-probe caching and hidden-pass
findings resolved, with no remaining material defect. Rust tests pass
**39 + 2 + 8**. The affected gem run passes **40 / 720**, with seven named
dependency skips. With all three supported Inertia gems installed, the separate
Inertia run passes **6 / 2,480**, with no failures, errors or skips.
The broad developer run is **not green**: 186 tests, seven failures, one
error, 23 skips. All eight failing identities reproduce on the untouched base
(mixed Minitest 5/6 and regenerated-blog provenance); none was suppressed.

The **owner-retained published blog source**, not the regenerated app, was
transferred by verified archive hash `56d74970…`, with source pin `86ebd4a8…`
and original lock `570c9c31…`. Before/after public builds at the same app path
isolate the four sealed rendering units. Both delivered ISeqs and lowered
sources are byte-identical; complete census `apps` data is identical, digest
`85e9bcc3e1618bea9ef2c48ac059518b6c8a14c00026df01f3515ea95b53615a`.
The delivered ISeq digests remain the published `d95122f0…` / `bea055e8…`.
Manifest build-source certificates change normally; no old certificate is
whitelisted. Retained failed proof attempts include a missing baseline native
extension and a shared Cargo target selecting the baseline CLI; only the
corrected pair with verified implementation source paths counts.

### Off-only fixed-heap calibration, N=10

The original N=50 all-arm page growth remains rejected. Before enabling on,
declare the smaller **N=10** finite window and apply the off-only method from
[00f2bff](https://github.com/thomasklemm/lowrail/commit/00f2bffb1bfa7e7dfb8287cbed2b02306e22d96f):
maximum start-live slots plus all full-window allocations, 50% headroom,
rounded up to 10,000, never below the original floors. GC/window policy is
unchanged. This is calibration, not repeated performance cohorts.

| Pool | Off whole-window slot budget | Frozen init slots | Exact eden pages |
|---|---:|---:|---:|
| 0 | 362,016 | 1,000,000 | 611 |
| 1 | 85,807 | 250,000 | 306 |
| 2 | 62,083 | 100,000 | 246 |
| 3 | 2,562 | 20,000 | 99 |
| 4 | 1,415 | 10,000 | 100 |

These derived floors equal the original floors: no arm-specific adjustment.
The same **Valgrind 3.19.0 / brk512** installation runs `--tool=none` only.
Four fresh serial workers (off/on × both phase orders) pass all **16** N0/N10
total/no-GC windows: exact target pages at every boundary, zero additional
allocated pages, no brk overflow. Each on full window completes 520 hits;
N0 and off have zero. No Callgrind extension, client requests, Ir or timing
counters are used. A startup JSON-version conflict is retained as a harness
failure; loading Bundler before Lowrail fixes it without an app change.

### Actual artifact, hits, and remaining refusals

The public `build --sealed --env production --jit interpreter` uses a normal
denylist to exclude every non-instantiation pass; no manifest pruning.
It emits **19 model units, zero delivered files**, manifest SHA256
`855ab8aa9ea5ef0f18154439530389b973281b4564bce90bb95e7e5ddf47b94b`.

| Model | Completed hits / warm room request |
|---|---:|
| Account | 5 |
| User | 5 |
| Message | 40 |
| Boost | 1 |
| Session | 1 |
| All other certified models | 0 |
| **Total** | **52** |

The remaining **two Room rows fall back for STI**; the inherited discriminator
column requires Rails' `instantiate` path. Warm and repeat agree, as do both
heap phase orders. Cold room has 94 hits and two STI fallbacks; cold work is
not the priced mix. Warm room still makes 18 SQL events, 16 preload entries,
three links and one form/token call. Those helper/preload calls are **not**
optimized by this artifact. The AR-plan survey now explicitly refuses Prism
1.4's unsupported grammar; other passes remain denylisted/quarantined or
outside the blog-only certificates, not silently admitted.

Raw cold off-A/off-B/on retains all headers/body. Status sequence is
200/302/200 (sign-in GET/POST, room GET). Both comparisons reject: sign-in
and room bodies differ at CSRF metadata and respectively one / 322 hidden
tokens; ETag, Set-Cookie and X-Runtime differ. Exit `sessions` differs in
`created_at`, `last_active_at`, `updated_at`, and `token`; queues/thread summaries
agree. Nothing is removed to produce an accepted HTTP comparison.
Separate census SQL/events are identical
off/off/on: cold **117 / 619**, warm/repeat **18 / 38**. These observer-based
comparisons are not complete arbitrary payload or bind-value coverage.

For this exact artifact, the non-system own suite passes **234 / 671** per
arm, 5,643 identical query counts/traces, zero load differences and zero hits.
Production sealed delivery explicitly refuses in test, as designed: this is
compatibility, not active sealed own-suite support.

The browser rerun passes **8 / 60** in both arms, zero hits/loads, but strict
verification **rejects** `SendingMessagesTest#test_sending_messages_between_two_users`
at **496 → 499** queries. Its own-thread SQL digest is identical
(`7f5b7ea6…`); the recorded `n` includes *both* own and other-thread events,
and the verifier gates `(own_digest, n)`. Three tests also have other-thread
digest advisories. No full-query lines were captured, so the extra queries
cannot be attributed to specific calls; no Lowrail effect or harmlessness is
claimed. No retry-to-green, control exemption or verifier change was made.

### Revised request: one conditional interpreter-Ir cohort

`campfire-r81-room-instantiate-v1`, **N0/N10**, off-A/off-B/on, six randomized
serial rounds, seed 41231, balanced total/no-GC phase order; exact app/lock,
artifact and harness digests in the appendix. Warm expected map is fixed at
**52** above (Room two fallbacks), floors/pages as above. Preserve interpreter,
placement, brk512, exact-page, A/A ±0.5% interval and all rejected-round gates
from the accepted blog protocol. Price only live sealed AR instantiation,
including its guards; no preload/helper/endpoint unit or cache-policy change.

**Not ready to execute.** The coordinator subsequently pre-approved exactly
this cohort, conditional on the browser classification, cold companions, and
**Fizzy's approved N=10 cohort releasing the slot**. The first cold companions
fail (§11), so no cohort starts. No speed estimate is inferred from
52 hits or the blog's −15.23%. No further runtime change is authorized here.

## 11. Fixed browser diagnostic and negative cold companions

The coordinator authorized exactly three off/off and three off/on pairs of
`SendingMessagesTest#test_sending_messages_between_two_users`, serial, seed
41231. No verifier retries or other browser tests run in this diagnostic.
Each of the twelve fresh processes passes **1 test / 9 assertions**, zero
hits; the production artifact refuses in test. Full normalized query lines
are retained privately with `LOWRAIL_SQL_TRACE=full`.

| Pair | Arms | Own queries A / B | Other-thread A / B | Total A / B |
|---|---|---:|---:|---:|
| 1 | off/off | 3 / 3 | 499 / 502 | 502 / 505 |
| 2 | off/off | 3 / 3 | 499 / 502 | 502 / 505 |
| 3 | off/off | 3 / 3 | 499 / 499 | 502 / 502 |
| 4 | off/on | 3 / 3 | 502 / 502 | 505 / 505 |
| 5 | off/on | 3 / 3 | 502 / 502 | 505 / 505 |
| 6 | off/on | 3 / 3 | 499 / 502 | 502 / 505 |

Every own-thread digest is the prior `7f5b7ea6…`; every complete load snapshot
has digest `d610cc4c…`. Other-thread digests also vary between off workers.
The coordinator accepts **named test/other-thread nondeterminism**, not an
attributed zero-hit Lowrail effect. The original strict rejection remains in
the ledger; no comparator, test, app code or query-count gate was changed.

`campfire_room_companion.rb` adds separate raw and declared seed-0/seed-1
off/off/on workers for the natural sign-in GET/POST and one room GET. It
reuses the blog's entropy machinery, byte/encoding-preserving values and
notification projection. A new pinned policy covers this app/lock, the loaded
OpenSSL 3.3.0 (not the stdlib lookalike), and Ruby 4's base58 session-token
`gen_random` path. Unknown entropy refuses. All original body/header bytes
and real clock observations survive in private receipts.

**Negative result:** the companion command exits **2**, with `pass: false`.
Both seeds have exactly matching full response bodies/headers (200/302/200),
all SQLite schema/rows, observed events, load snapshots, ancestry and entropy
traces in off/off/on. All 153 SQL event records agree, but ten cached events
per worker have unevaluated lazy-Proc binds: agreement of the uncovered marker
is **not** coverage of those bind values. Login plus cold room completes 103
hits on; that is not the warm room's 52-hit priced map.

The remaining differences/gaps are retained, not converted to success:

1. Redis has the same **42 key names and values**, but the absolute expiry of
   `rate-limit:sessions` differs **already off/off**. The other 41 expiries
   agree. Completed and post-process-exit states match within each worker.
2. Full feature lists differ on by `lowrail/ar_shadow.rb`,
   `lowrail/ar_instantiate.rb`, `lowrail/ar_guard.rb`, in that order. No other
   feature differs. This first command compares **all** features, stricter
   than the blog's existing Lowrail-internal feature exclusion; it does not
   silently apply that exclusion or suppress the three files.
3. All ten lazy cached bind-value gaps remain errors; the SQL text, cache
   flags and remaining fields are retained. No Proc is called or bind recast.

Completion is a bounded no-work certificate for this GET/login worker:
Resque queues empty, both WebPush executors have zero scheduled/completed
tasks, queue entries and threads, Cable listener/worker/event loop unstarted,
and no `Rails.error` reports. No thread kill, fabricated job execution or
cache clear occurs between requests. Redis is restored only between fresh
workers, as before. Raw HTTP remains rejected at named CSRF/token/cookie/
ETag/runtime/session-clock fields; all body byte chunks **outside** the named
CSRF values agree. That diagnostic never rewrites a response or clears a raw
rejection. Raw Redis fragment values also retain their clock differences.

Retained harness-development failures: v1 used a relative worker path after
changing working directory; v2's copied cookie-IV policy named the stdlib
OpenSSL path while the app actually loaded the identically hashed gem file.
The corrected final policy has **zero undeclared entropy** but still fails
the three gates above. No cohort is run or retried.

The coordinator accepts the browser classification and next authorizes one
companion rerun: retain Redis expiry as a named accepted off/off rejection,
reuse exactly the blog's Lowrail-own feature rule with path/content pins and
an explicit excluded-file list, and retain lazy binds as a named uncovered
gap. **These negative results are published before that rerun.** All other
fields, non-Lowrail feature order, loads and DB values must still match;
there is no Redis clock interposer or new runtime/default/quarantine change.
Only if that rerun passes and Fizzy releases the slot may the pre-approved
cohort start. Bet A's `script/native-bench` was absent from `origin/main` at
the check for this negative report, so native YJIT exploration has not run.

Reproduction (same dedicated Redis and fixture environment as below):

```sh
CAMPFIRE_DISPOSABLE_REDIS=1 BUNDLE_GEMFILE=/absolute/APP/Gemfile \
  mise exec ruby@4.0.7 -- bundle exec ruby \
  bench/experiments/campfire_room_companion.rb run APP SEED NEW_PRIVATE_OUTPUT
# Exit 2 is an honest rejected gate, not an install or performance result.
```

## Reproduction boundaries

Use an isolated corpus checkout and dedicated local disposable Redis; never
point this harness at shared data. `script/corpus campfire-r81` prepares the
dependency-only checkout and upstream assets. Build the gem's native primitive
and the CLI normally. Run the plain suite, then public default `lowrail verify`
for `bundle exec rails test --seed 41231` and separately `test:system` with one
worker and `LOWRAIL_VERIFY_LOADS=1`; archive both receipts before production.

Run `campfire_scenario.rb prepare APP NEW_SEED` through that app's frozen
bundle (set `BUNDLE_GEMFILE` to its absolute Gemfile). The seed is refused if
already present. Build the production public `all-opt-in --jit interpreter`
artifact with the seed's database/secret environment, preserving the separate
failed `--sealed` log. The seed secret must not be printed or committed.

The survey CLI is:

```sh
# Every invocation refuses an existing output directory. Receipt must be green.
export CAMPFIRE_DISPOSABLE_REDIS=1 # acknowledge exclusive localhost:6379/0
export BUNDLE_GEMFILE=/absolute/path/to/APP/Gemfile
mise exec ruby@4.0.7 -- bundle exec ruby bench/experiments/campfire_survey.rb \
  census APP SEED NEW_PRIVATE_OUTPUT GREEN_SUITE_JSON
# Other untimed modes: cold, profile, heap.
# profile needs an out-of-bundle StackProf 0.2.28:
export CAMPFIRE_STACKPROF_LOAD_PATH="$(mise exec ruby@4.0.7 -- ruby -e \
  'puts Gem::Specification.find_by_name("stackprof", "0.2.28").full_require_paths.join(File::PATH_SEPARATOR)')"
# heap additionally takes the pinned Valgrind executable as its last argument;
# the only launched tool is --tool=none. It contains no counter client seam.
```

Harness development failures are retained privately: missing local Resque/Cable
Redis caused the initial POST 500; the first exit-table reader incorrectly
assumed FTS shadow tables had `rowid`; the first profile loader found StackProf
hidden by Bundler. The corrected harness keeps every app file unchanged.
These are not extra performance cohorts. Nothing was posted to Basecamp or
any other foreign repository.
