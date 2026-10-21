# Stack bet — admission and interaction ledger

2026-10-21. Exploration on `thomasklemm/stack`; no main/default change.
The bet is that small exact reductions compose even when individual wall-time
effects are below noise. Allocation reduction is admission evidence, not a
latency claim. An instruction increase cannot be hidden by fewer allocations.

## Protocol

Use the shared `script/screen` from `thomasklemm/native-yjit-bench`
(`bfc682b97dbebdb1082d4f54e8ed426e7ff27c27`, including the pre-boot fixture
secret and Lobsters validation fixes), not another request harness.
Every comparison retains all three off-A/on/off-B rounds, a separate counted
probe, raw A/A spread, integer allocation samples, GC counts/time, RSS, boot
and actual YJIT state. Use larger declared warmup/sample counts than the short
defaults; effects inside the A/A band are unresolved, not wins or kills.
Pinned entropy companions are untimed and compare actual status, body and
all-header digests; timed requests retain native entropy. Hardware instruction
counters are unavailable in this orb environment.

Admission needs identical outputs, DB state and own-suite results, named
refusals, and non-increasing deterministic cost on each admitted app. A green
suite with zero fast-path hits does not certify the candidate. Production
sealed units refuse test processes: existing compatibility results do not
close their active own-suite gap. Screens below can therefore remain
**provisional**, even when their deterministic result is favorable. Nothing
here reaches main without the unchanged correctness gates and Thermos.

Build each selection normally with the public CLI and a pass denylist; do
not prune a manifest or remove guards. Measure off/full stack, each component
alone, and full stack minus each component. Define saved objects as off minus
on; a leave-one-out saving is (stack minus component) minus full stack.
Compare that marginal with the standalone saving to classify overlap or
synergy. Do not sum isolated micro results or mix fixtures/modes.
In the inventory below, Δ alone is on minus off; Δ inside is full minus
leave-one-out (negative saves objects). The LOO column uses the opposite
sign: objects saved by retaining that component in the full stack.

## Candidate inventory

`—` means not measured, never zero. “Pending” is not admission.

| Component | Apps active / eligible | Deterministic delta alone | Delta inside stack | Leave-one-out delta | Status |
|---|---|---|---|---|---|
| Existing sealed form scaffold | Blog show, retained fixture only | −378 objects/request | −378; 1 hit/request | +378 | Favorable screen, provisional: active own-suite gap retained |
| Existing sealed token tag | Blog show, retained fixture only | +32 objects/request | +32; 4 hits/request | −32 | Excluded on Blog by deterministic cost; live-token continuations retained |
| Existing sealed collection render | Blog show, retained fixture only | 0 objects/request | 0; 1 hit/request | 0 | Allocation tie, no win credit; active own-suite gap retained |
| Existing sealed AR instantiation | Blog / Campfire / Fizzy active; Lobsters warmed vector has zero hits | Blog 0; Campfire near tie; Fizzy median tie after `c10ccb8` | Blog 0; 3 hits/request; Fizzy combination pending | Blog 0 | Fizzy pre-fix exclusion superseded; provisionally neutral candidate, no saving/admission credit; DB/active own-suite gaps retained |
| Props `frozen_split` (`dd844dd`) | None of these four apps use Inertia | Isolated interpreter micro −0.460571% Ir, not request credit | — | — | Excluded: frozen-holder tier not implemented; do not freeze app holders to admit it |
| B fused views | Blog show/index | +113.14 / +136.20 objects/request in B's screen | B's fused+sealed screen still increases objects | — | Excluded: killed at deterministic cost gate; no integration |
| D freeze method epoch | None | TracePoint +71.326 objects/request; incomplete singleton seal | — | — | Excluded: killed as unsafe; visibility/refinement/suppressed-hook holes |
| E subset callbacks | None admitted | Blog show/index: zero objects saved in E's corrected exact screen | — | — | Coordinator killed: no deterministic saving, wall unresolved; census retained |
| F AR callsite compile | Fizzy buckets only; no admitted app | Local 9,072 / 9,072 → 8,500 (−572, −6.31%) | −572; sole applicable candidate, not a multi-component test | +572 against the measured off controls | Favorable guarded response screen, provisional; DB/SQL cold-state and active own-suite gates remain open |
| G framework fold | None admitted | — | — | — | Closed: notification/CSP elisions fail exactness in all four boots; no remaining qualifying slice |
| H boot image | None admitted | — | — | — | Await successful boot screen and correctness gates |
| Fizzy bench block-link | None | +0.403071% interpreter Ir (`8385e0c`) | — | — | Excluded: deterministic loss and no production admission |

Inventory comes from the bet branches and their full thread histories, not
their titles. New exact screened candidates may replace pending rows; do not
duplicate their implementation work.

## Corpus and retained boundaries

- **Blog:** original retained archive SHA256
  `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`;
  source `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`;
  lock `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
  Fresh `BlogShowGetOnly` data, not an old job-bearing seed. Initial numbers
  are pre-dispatch-fix. The published corrections through `62f8a6b` are now
  integrated on the exploration branch, together with shadow fix `acc130d`;
  nine fresh public builds have completed corrected full/alone/LOO screens.
- **Campfire r81:** `02023b0f0cafc4d66e06e43be072cf4d6ca328fa`, dependency-only
  Rails 8.1.4 overlay, original `CampfireScenario` fixtures and authentication,
  dedicated disposable Redis. Room STI rows remain original. Queued POST
  delivery is not completion-certified; cold entropy/browser SQL refusals stay.
- **Fizzy:** `6f1d200316ec3bae91d32c557d88647300807ee9`, dependency-only
  overlay, original six-GET fixture/vector. Use `--exploration-only` with an
  independently built public artifact, never the rejected block-link specimen.
  Cache clocks, lazy cached binds and background completion remain boundaries.
- **Lobsters:** ruby/ruby-bench `351a39b77e6c06f4f4fa03148639b10a6bb0c716`,
  canonical dependency wrapper from C; shipped DB SHA256
  `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
  Never schema-load the historical SQLite-incompatible schema. Anonymous
  `/newest`, `/active`, `/recent`, `/hottest` are A's vector, not C's broader one.

## Measurements and pricing decision

### First full-stack screen: pre-dispatch-fix, provisional

Three rounds, **200 warmups / 300 samples**, CPU 2, Ruby 4.0.7 / Rails 8.1.4,
actual native YJIT. Full blog stack is form/token/collection plus 17 normally
built AR model units. No guards removed. All 18 measured two-seed response
comparisons pass: status, body and every header digest. All four DBs and
storage-file snapshots are unchanged by the checked GETs and identical across
all arms/seeds/rounds. This does not certify writes, arbitrary app behavior or
the active own suite.

| Blog `GET /articles/1` | off-A | off-B | full stack |
|---|---:|---:|---:|
| Integer objects/request, median | 2,412 | 2,412 | 2,019 |
| Native wall, mean of worker medians (µs) | 1,965.24 | 1,882.28 | 1,659.58 |

**−393 objects/request (−16.29%)** is a deterministic screen reduction.
Native paired wall is −14.90%, but A/A max absolute round spread is **13.76%**;
the effect is **unresolved**, not a wall win. Per-request counted hits:
Article 1, Comment 2, form 1, token 4, collection 1; zero fallbacks.

The known P1 `view.send` dispatch defect was not exercised by this fixture.
These results are **superseded, pre-dispatch-fix**, not deleted. The corrected
screens below replace them for current-source reasoning. The active
own-suite gap independently prevents admission/pricing.

### Corrected Blog: form-only beats the full stack

Sources include dispatch fixes `1c99962`/`62f8a6b` and the allocation-free
shadow predicate `acc130d`, merged on exploration at `db13e01`. Rebuilt all
nine artifacts with public `build --sealed --env production --jit yjit`
and normal denylists. Same fixture, three rounds, 200 warmups / 300 samples,
CPU 2. All nine selections pass actual two-seed status/body/all-header
comparisons; all DB/storage snapshots remain unchanged and identical across
arms/seeds/rounds. No test-tier or guard relaxation.

| Selection | Off-A / off-B objects | On objects | Objects saved vs off | LOO saving when omitted component is retained |
|---|---|---:|---:|---:|
| full: form + token + collection + AR | 2,412 / 2,412 | 2,066 | 346 | — |
| form alone | 2,412 / 2,412 | 2,034 | 378 | — |
| token alone | 2,412 / 2,412 | 2,444 | −32 | — |
| collection alone | 2,412 / 2,412 | 2,412 | 0 | — |
| AR alone | 2,412 / 2,412 | 2,412 | 0 | — |
| full minus form | 2,412 / 2,412 | 2,444 | −32 | +378 |
| full minus token | 2,412 / 2,412 | 2,034 | 378 | −32 |
| full minus collection | 2,412 / 2,412 | 2,066 | 346 | 0 |
| full minus AR | 2,412 / 2,412 | 2,066 | 346 | 0 |

**Form-only (−378 objects, −15.67%) beats full (−346, −14.34%).** These
components do not simply add up **as savings**. The LOO rows, not an assumed
per-hit budget, attribute the entire 32-object gap to token on this route;
collection and AR contribute zero at the measured medians. Signed allocation
deltas are additive here (−378 +32 +0 +0 = −346), with no measured overlap or
superadditivity. Exclude token from the Blog candidate stack. The stack
without token ties form-only; zero-cost active components receive no win
credit. This is one favorable component, not evidence for many tiny wins.

Full native wall is +0.62% against a 3.92% A/A spread, unresolved. Form-only
is −9.61% against 12.36% A/A, also unresolved. Do not turn either into a speed
claim. Full GC counts are on [8,8,9], off-A [6,6,6], off-B [6,6,7]: there is
no evidence of fewer collections. Full GC ms/request is 0.275 on versus
0.582/0.521 off; RSS is 181,777 KiB versus 179,945/179,904 KiB. The screen
does not fix heap layout across artifacts, so neither these measurements nor
cross-artifact differences establish GC synergy. Every case's GC counts/time,
native wall, RSS and coverage remain in the export.

**Retained-heap question, unmeasured:** the shared worker records allocation
counts, GC counts/time and RSS, but not a post-warmup `GC.stat` snapshot.
`heap_live_slots`, `old_objects` and `malloc_increase_bytes` are therefore
unavailable for every arm in this retained batch. A larger retained artifact
heap or earlier GC trigger could explain more collections despite fewer
objects/request, but neither is established by these data. Do not infer heap
occupancy from RSS or attribute the extra collections to a proven cause.
No new cohort is run to fill this gap. Collection-only and AR-only each save
zero objects/request on this route, despite their active hits.
The later `script/rps` at `b1e239f` records these three post-warmup heap fields
for future runs; it cannot supply them retroactively for this screen batch.

All favorable results remain **provisional** until active own-suite coverage
and the unchanged admission gates exist. No whole-stack price is requested.

### Campfire AR: superseded pre-shadow-fix exclusion screen

Same three-round 200/300 protocol, four GETs (POST omitted: queued work has
no completion certificate). Nineteen normally built AR units. Median object
counts and independent counted hits are:

| Route | Off-A / off-B / on objects | On minus off-A | AR hits / request |
|---|---|---:|---:|
| room | 15,528 / 15,528 / 15,579 | +51 | 52 |
| pagination | 6,811 / 6,810 / 6,857 | +46 | 46 |
| sidebar | 9,110 / 9,110 / 9,118 | +8 | 8 |
| search | 8,126 / 8,125 / 8,145 | +19 | 19 |

All mean-allocation paired intervals are positive. Sidebar passes both-seed
exact status/body/header comparisons. Room/pagination/search retain body or
header differences in **off/off as well as on/off**; no candidate-specific
correctness diagnosis follows. All wall effects are unresolved against A/A.

The coordinator identified `ARShadow.enabled?`'s per-call `%w[1 strict]`
Array as an existing main allocation bug; its allocation-free correction is
published at `acc130d`. The caller exists on the measured per-row path;
these excesses approximately track hits. The corrected retest below replaces
the provisional cost exclusion, without a local duplicate implementation.
Retain this entire superseded screen, including exactness RED.

### Corrected Campfire AR: old penalty gone, no admitted win

Rebuilt all 19 units normally against the disposable fixture on `acc130d`;
same three-round 200/300 screen, four GETs and natural guarded hits.

| Route | Off-A / off-B / on allocation medians | AR hits / request | Two-seed exact response |
|---|---|---:|---|
| room | 15,527 / 15,527 / 15,527 | 52 | FAIL |
| pagination | 6,810 / 6,811 / 6,810 | 46 | FAIL |
| sidebar | 9,109 / 9,110 / 9,109.5 | 8 | PASS |
| search | 8,126 / 8,125 / 8,125 | 19 | FAIL |

Medians are computed from integer observations; an even pooled sample can
have a half-object median. The former +51/+46/+8/+19 medians are **not a
current-source cost claim**. Room now ties exactly; other medians lie within
one object of the two controls. Small mean-allocation differences and their
A/A spread remain in the export; do not promote a one-object median shift
to a stable deterministic reduction. Room's paired mean allocation interval
straddles zero. Pagination/sidebar mean excesses are below one object/request
against off-A, while search saves below one, with comparable A/A variation.

Whole screen exits 2: room/pagination/search retain off/off body/header
differences, sidebar passes. DB completion remains uncovered; Room STI still
falls back naturally (room 2, pagination/search 1 per request). Native wall
changes −0.88%/+1.23%/+1.13%/−1.91% remain inside A/A spreads
1.64%/3.01%/2.30%/5.23%. **No admitted component or price:** this is near-tie
allocation evidence with unresolved correctness boundaries, not a final
negative based on the removed shadow penalty and not a cross-app win.

### Fizzy AR: superseded pre-shadow-fix exclusion screen

Same 200/300 protocol, six original GETs, 45 normally built AR units.
The two off controls sometimes differ by one object, so show both rather
than selecting the baseline that makes the effect larger.

| Route | Off-A / off-B / on objects | AR hits / request | Two-seed exact response |
|---|---|---:|---|
| buckets | 9,066 / 9,065 / 9,076 | 11 | PASS |
| filtered bubbles | 22,518 / 22,518 / 22,582 | 45 | FAIL |
| account users | 5,588 / 5,588 / 5,603 | 6 | PASS |
| workflows | 3,825 / 3,825 / 3,832 | 7 | PASS |
| notifications | 3,805 / 3,805 / 3,809 | 4 | FAIL |
| bubble show | 18,339 / 18,338 / 18,418 | 43 | FAIL |

The whole screen exits 2: retained exactness failures include off/off
differences, not a diagnosed candidate-specific failure. DB effects remain
uncovered. Some allocation excesses exceed the counted AR hits; the known
shadow-predicate allocation cannot explain all of them. The corrected retest
below supersedes these cost observations. No latency claim.

### Fizzy AR: superseded pre-names_of-fix residual-cost exclusion

Rebuilt the 45-unit public artifact using the original disposable fixture's
environment and DB, then screened all six GETs on `acc130d`, same three-round
200/300 protocol. No app/config patch or block-link specimen.

| Route | Off-A / off-B / on allocation medians | On minus either off median | Two-seed exact response |
|---|---|---:|---|
| buckets | 9,065 / 9,065 / 9,065 | 0 | PASS |
| filtered bubbles | 22,518 / 22,518 / 22,536 | +18 | FAIL |
| account users | 5,588 / 5,588 / 5,598 | +10 | PASS |
| workflows | 3,825 / 3,825 / 3,825 | 0 | PASS |
| notifications | 3,805 / 3,805 / 3,805 | 0 | FAIL |
| bubble show | 18,338 / 18,338 / 18,375 | +37 | FAIL |

The allocation-free shadow fix removes a real penalty, but not all AR cost.
Account users independently passes both-seed actual response checks and
retains +10 median objects/request; its paired mean interval is
+0.160% to +0.170%. That positive deterministic cost alone excludes this
component from the Fizzy stack, without depending on the failed routes.
Filtered/show mean intervals are also positive. Counted hits remain
11/45/6/7/4/43 per request, with no fallback in these probes.

Whole screen exits 2: filtered/notifications/show retain body/header
differences off/off too. DB effects remain uncovered. These refusals are not
normalized away or diagnosed as candidate-specific errors. No native latency
win is claimed; show records +6.06% paired wall against 1.79% A/A, but fails
exactness and is not an accepted price. Pre-fix data remain intact above.
The `c10ccb8` retest below supersedes this cost exclusion; these are retained
pre-names_of-fix results, not current-source evidence of a penalty.

### Bounded Fizzy AR allocation diagnosis: avoidable guard scratch

No new cohort. Reused the pinned seed, public AR artifact, original native
driver/login and 200 six-GET warmups in separate off/on workers. Adapted
`bench/experiments/allocations.rb`'s ObjectSpace generation census to one
request per target, with GC disabled only during tracing/enumeration so
dead objects cannot disappear. No runtime/app/config replacement. Counters
remain disabled; exact two-seed validation is outside the allocation trace.
A separate untimed TracePoint return observer records the actual caller and
match count, not a method override. [Full callsite counts and stacks](stack-ar-allocation-trace.json).

- **Account users cause:** its three `Account::UsersAssociationExtension`
  proxy extensions reach `Guard.note_extend` → `Guard.names_of`, whose
  `@names.each_key.select` allocates three empty Arrays and three Enumerators
  at `gem/lib/lowrail/guard.rb:103` despite matching no tracked method.
- **Show cause:** event-summary assignee resolution creates twelve proxies
  with the same extension, causing twelve empty Arrays and twelve
  Enumerators at the same guard line; this is invalidation scratch, not an
  inherent per-record construction cost.

All 3/12 observed name scans return zero matches. The index has three tracked
names. Original Rails row-object and payload/column Hash allocations merely
move to generated source locations and balance; do not count those relocated
objects as extra. The census totals are users 5,600 → 5,616 and show
18,357 → 18,392, **diagnostic totals, not replacement screen estimates**.
Native URI encoding contributes +8/−1 String differences; ObjectSpace leaves
an explicit +2/+12 VM-internal residual unassigned. Users remains response
exact for both seeds; show's existing exactness rejection stays red.

**Diagnosis-time proposal, subsequently landed upstream:** collect matching names
with a direct `@names.each_key` block and allocate the result Array lazily
only on the first match; let the two internal callers skip a nil no-match
result. Preserve collect-before-reset ordering, both visibility predicates,
all invalidation/override effects and the existing large-index branch.
A standalone selector sketch with the real three-name index allocates
30,001 versus **zero** objects over 10,000 no-match calls; public, private
and inherited match-selection controls agree. This corroborates three
avoidable objects per empty scan (9/36 per observed route), not a precise
request-level saving promise. The coordinator owns assignment and the usual
correctness/Thermos gates. The Campfire thread landed this independently at
`c10ccb8`; the exploration branch imports that unchanged published fix at
`a2c82f6`, not a duplicate implementation. The follow-up screen is below.

### Post-names_of-fix Fizzy AR: allocation-neutral candidate

Rebuilt all 45 public AR units normally after integrating `c10ccb8`; no other
units. Same original seed/source/lock hashes, six GETs, three rounds,
200 warmups / 300 samples, CPU 2, actual Ruby 4.0.7 native YJIT / Rails 8.1.4.

| Route | Off-A / off-B / on allocation medians | AR hits / request | Two-seed exact response |
|---|---|---:|---|
| buckets | 9,065 / 9,065 / 9,065 | 11 | PASS |
| filtered bubbles | 22,518 / 22,519 / 22,518 | 45 | FAIL |
| account users | 5,588 / 5,588 / 5,588 | 6 | PASS |
| workflows | 3,825 / 3,825 / 3,825 | 7 | PASS |
| notifications | 3,805 / 3,805 / 3,805 | 4 | FAIL |
| bubble show | 18,339 / 18,339 / 18,339 | 43 | FAIL |

The former +18/+10/+37 excesses are gone at the measured medians. Every
route is no greater than either control at its median; all mean-allocation
effects are unresolved at the allocation A/A floor. For example users means
are 5,588.281 / 5,588.074 / 5,588.494 with a paired interval spanning zero;
do not present these data as proof of a strictly non-increasing expectation,
an AR saving or a price. They support a **provisionally neutral exploration
candidate**, not final admission. There are no counted AR fallbacks.

The whole screen exits **2**. Buckets/users/workflows pass actual both-seed
status/body/all-header equality in every round; every off/off-exact route
is also on/off exact. Filtered/notifications/show retain off/off body/header
differences. DB/completion and active own-suite gates remain open. Native
wall is unresolved under the 3× A/A rule; raw effects and both controls,
GC counts/time, RSS and coverage are retained. Show GC counts on [29,18,31]
versus off-A [20,17,27] and off-B [18,17,20] are not a fewer-GC result.

This supersedes, rather than deletes, the old cost exclusion. AR may now be
tested beside F's DirectSite as a neutral candidate. A combined/F-only
comparison on the same updated sources is still needed before assigning
any Fizzy within-stack or leave-one-out effect.

### Guarded F DirectSite: a second app-specific candidate, not synergy

Imported F's three experiment/check sources unchanged from `addf55e`;
`ar_request_sites.rb` SHA256 is
`e313ae13363783705471e8a3b57a44d84eea97ab31dc146d338317504b1f37e1`
and `ar_callsite.rb` is
`37529c994b613e840caf25254d5ff0d852cb305fffb76608855ac3ae1bd52ca5`.
Retained all fallback guards, source pins and F's existing pinned entropy
companions. Only the bucket program is enabled; EventSummary stays removed.
Normally built a **zero-unit** public YJIT artifact with per-model denylists,
including generated HABTM model names found by the build. No manifest pruning
or existing AR units, app/config edits, frozen holders or block-link specimen.

Same three-round 200/300 screen, CPU 2, all six original GETs. This F-alone
selection is the entire applicable Fizzy candidate stack at this checkpoint:
sealed form is Blog-only and existing AR is excluded. Removing the only
component is the measured off controls; it is not a separate multi-component
interaction or evidence of additive/superadditive savings.

| Route | Off-A / off-B / on allocation medians | DirectSite hits / request | Two-seed exact response |
|---|---|---:|---|
| buckets | 9,072 / 9,072 / 8,500 | 2 | PASS |
| filtered bubbles | 22,543 / 22,543 / 22,543 | 0 | FAIL |
| account users | 5,596 / 5,596 / 5,593 | 0 | PASS |
| workflows | 3,826 / 3,826 / 3,826 | 0 | PASS |
| notifications | 3,807 / 3,807 / 3,807 | 0 | FAIL |
| bubble show | 18,361.5 / 18,361 / 18,359 | 0 | FAIL |

Buckets saves **572 median objects/request (−6.31%)** against either control;
on [8,487,8,654] does not overlap off-A [9,061,9,218] or off-B
[9,061,9,227]. The counted probe has 20 guarded hits over 10 requests,
zero bucket fallbacks, and 200 SQL events in every arm. No reduction is
attributed to non-bucket routes with zero hits. The raw allocation means,
ranges and controls differ from F's separate −585 screen; do not mix runs.

Native paired wall is −4.67% versus **3.46% A/A spread**, unresolved under
the screen policy. Bucket GC counts are off-A [11,9,9], off-B [12,10,9], on
[10,9,12]; GC ms/request 0.430/0.437/0.445 and RSS KiB
233,925/232,960/231,663. No fewer-GC or latency claim. All six routes' GC,
RSS, boot and wall results are retained, not only the favorable row.

The whole screen exits **2**: filtered/notifications/show retain exactness
differences in off/off too. The three other routes pass actual status, body
and every-header digest checks for both seeds in all rounds. Complete DB
equivalence is not established by this request screen.

F's directed check was also run unchanged, including warm baseline, eleven
mutation/fallback/restoration controls, 13 cases × two seeds. All response
triples agree, and warm/mutation SQL comparisons agree. The initial baseline
SQL and primary/cache DB comparisons fail, including off/off, so the overall
check exits **2**, not green. Read-only final primary DB comparison found
only `sessions.created_at`/`updated_at` differences (five rows per arm);
cache differences remain a named refusal. [Sanitized controls, hashes and
hit/fallback deltas](stack-directsite-controls.json) exclude raw binds,
entropy traces, cookies and response bodies. These are finite request and
fallback controls, not a general method/purity/mid-request certificate,
whole-DB gate or active own-suite proof. No main admission or stack price.

### Lobsters AR: warm-cache zero credit

Same 200/300 protocol, 24 normally built AR units. `/newest`, `/active`,
`/recent`, `/hottest` pass actual two-seed status/body/all-header checks;
logical DB snapshots are unchanged and identical across arms/seeds/rounds.
Off-A/off-B/on allocation medians are identical on each route: respectively
14,359, 1,437, 1,423 and 14,866 objects/request. Every measured route has
**zero AR fast-path hits** in the separate warm probe. This is a cached-path
control, not active-unit certification or an AR win. Native wall changes
(−1.07% to −1.87%) remain inside A/A spreads (2.02% to 4.84%).

Sanitized raw evidence, GC counts/time, RSS, per-unit coverage and all refused
comparisons: [stack-results.json](stack-results.json). Private fixture secrets,
response bodies/cookies and raw app logs are excluded. Export with:

```sh
mise exec ruby@4.0.7 -- ruby docs/stack-report.rb docs/stack-results.json \
  .lowrail/stack/screen-*
```

Corrected Blog attribution, initial four-app screens and post-shadow-fix
Campfire/Fizzy retests plus guarded F are complete: **17 retained screens**.
Blog's signed allocation effects are additive, not all beneficial. There is no admitted
multi-component stack across apps. Token is excluded on Blog; existing AR is
provisionally neutral on Fizzy after `c10ccb8`; Campfire offers no clear
reduction and retains exactness gaps; Lobsters' cached vector provides no active credit. Form's favorable
Blog request reduction stays provisional until active own suites exist.
Bet F's guarded `addf55e` now has a favorable local buckets allocation screen,
with existing AR excluded in that screen. Sealed form applies only to the
certified Blog fixture, not Fizzy; do not force a cross-app form/DirectSite combination.
No cross-app win, native latency gain, GC synergy or supported component is
claimed. Shared screen tests pass 2 tests / 39 assertions; imported dispatch
regressions pass form 2/202 and link 2/162; shadow-predicate regression 1/4.
Updated guard/AR guard/AR instantiation tests pass 13 tests / 107 assertions,
zero skips. These are runtime unit checks, not an active Fizzy own suite.
Propose at most **one** whole-stack Callgrind/README price to the coordinator
only after a clear screen (>3× A/A wall noise or solid deterministic reduction)
and the correctness/admission boundaries are resolved. No Callgrind is launched
by this exploration ledger.
