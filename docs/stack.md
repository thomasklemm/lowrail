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
| Existing sealed AR instantiation | Blog active; Lobsters warmed vector has zero hits; Campfire/Fizzy retesting | Blog 0; Campfire/Fizzy pre-fix excesses superseded pending corrected screens | Blog 0; 3 hits/request | Blog 0 | Blog tie, no win credit; Campfire/Fizzy final exclusion undecided |
| Props `frozen_split` (`dd844dd`) | None of these four apps use Inertia | Isolated interpreter micro −0.460571% Ir, not request credit | — | — | Excluded: frozen-holder tier not implemented; do not freeze app holders to admit it |
| B fused views | Blog show/index | +113.14 / +136.20 objects/request in B's screen | B's fused+sealed screen still increases objects | — | Excluded: killed at deterministic cost gate; no integration |
| D freeze method epoch | None | TracePoint +71.326 objects/request; incomplete singleton seal | — | — | Excluded: killed as unsafe; visibility/refinement/suppressed-hook holes |
| E subset callbacks | None admitted | Blog show/index: zero objects saved in E's corrected exact screen | — | — | Coordinator killed: no deterministic saving, wall unresolved; census retained |
| F AR callsite compile | None admitted | Preliminary DirectSite Fizzy buckets 9,085 → 8,323 (−8.39%); not integrated | — | — | Await published guarded SHA and rescreen; earlier micros are not additive request credit |
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
these excesses approximately track hits. **Exclusion is provisional**, not a
final AR negative: the corrected retest is running, without a local duplicate
implementation. Retain this entire superseded screen, including exactness RED.

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
shadow-predicate allocation cannot explain all of them. All six will be
retested on `acc130d` before final exclusion. No latency claim.

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

Corrected Blog attribution and initial four-app screens are complete;
post-shadow-fix Campfire/Fizzy retests are pending. Blog's signed allocation
effects are additive, not all beneficial. No cross-app win, native latency
gain, GC synergy or supported component is claimed.
Propose at most **one** whole-stack Callgrind/README price to the coordinator
only after a clear screen (>3× A/A wall noise or solid deterministic reduction)
and the correctness/admission boundaries are resolved. No Callgrind is launched
by this exploration ledger.
