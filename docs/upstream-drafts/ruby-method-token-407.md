# Ruby 4.0.7 token fork: protocol before measurements

This is a fork-only experiment for Ruby #22459. No upstream post or PR is
authorized. The master patch remains available separately. The 4.0.7 backport
uses the existing callcache, not an epoch, registry or Ruby core token class.

## Fixed decision rule

* Run the real retained Rails 8.1.4 blog `GET /articles/1` and the six pinned
  Fizzy GETs, with fresh matching-mode artifacts and the existing disposable
  database/entropy fixtures. Preserve all status/body/header comparisons,
  including both off arms. Do not normalize differing bytes or retry gates
  until green. Keep private fixture data out of Git and release assets.
* `script/screen`: three fresh-process rounds, 20 vector warmups and 30 samples
  per route, CPU 2; separate stats-enabled coverage workers. Arms are off-A,
  existing guards (`on`), tokens, public reflection and off-B. No unsafe guard
  removal in these cohorts. Interpreter and native YJIT have separate artifacts.
* Report allocations/request and the actual native wall distributions. A wall
  benefit requires full exactness, an A/A 95% interval contained within ±2%,
  flat measured YJIT compilation/invalidation counters, and the token/hook
  interval wholly below three times the observed A/A noise floor. Otherwise
  the wall result is inconclusive, even if its point estimate is attractive.
* Compare the same guards on the same patched executable; do not attribute a
  stock/patched Ruby build difference to tokens. Record source, binary,
  artifact and fixture hashes. Run one RPS cohort when bet A's harness exists.
* A per-unit micro prices a complete captured method set, including public
  reflection for Module holders (the C API only accepts Class). It is not a
  request speedup. Public reflection is a correctness-capable alternative;
  hooks are cheaper but miss suppressed callbacks and own-class visibility.
* Suppressed-hook, visibility, prepend and refinement probes must distinguish
  invalidation from scope: tokens do not certify lexical refinements, actual
  receiver identity, mutable values or arbitrary reentry. The sealed contract
  and all existing value/holder/continuation checks remain. Extra lookup
  witnesses do not turn a sealed unit into an unrestricted specialization.
* Only a unit that cannot reasonably be a generic framework patch, cannot be
  handled by the existing JIT, AND demonstrates a gated end-to-end benefit is
  an upstream use case. No qualifying rows means say **none**, not a proposal
  to expose the primitive because it is small.

## Prior ceiling evidence (not token measurements)

Bet U's blog guard ceiling is 73 objects/request out of a gross 416 saving
(17.55%). It includes non-method checks that tokens cannot remove. Fizzy's
block-link suffix guard costs 1,220 objects/vector against a gross ceiling of
59.5 (about 0.028% of off); its full exactness gate is red even off/off.
Block-link remains killed. These observations motivate a cost comparison,
not a token speed claim or permission to remove unrelated checks.

## Result: keep the experiment in the fork

No upstream PR or issue comment was made. Public reflection solves the named
suppressed-hook correctness problem today. The smaller VM patch and the
allocation reduction below do not establish that Ruby should maintain an API.
The historical accepted blog instruction reduction did **not** use tokens.

### Shipped fork and maintenance boundary

Master patch: `thomasklemm/ruby:thomasklemm/method-token-minimal`,
[`a21df07`](https://github.com/thomasklemm/ruby/commit/a21df07d7800aa4e0b3187378df84d179b6fd91b),
on current canonical master
[`5771bd7`](https://github.com/ruby/ruby/commit/5771bd7a39100a1ceb003d78937b367ec2531f02).
The remote master was checked again after measurement; it was unchanged.
The old mutation-epoch prototype remains untouched.

The 4.0.7 backport is `thomasklemm/ruby:method-token-4.0.7`,
[`274022581f`](https://github.com/thomasklemm/ruby/commit/274022581f7f446f603820f718cefeb0740cd741),
on canonical `v4.0.7`. Both patches add **255 lines in four files**:
26 VM implementation, 32 public-header contract, 47 extension-fixture and
150 Ruby test lines. Core would maintain two exported C functions and the
safe lifetime of externally retained normal callcaches. No epoch, registry,
new core type, mutation hook, GC callback or JIT change is added.

The caller retains raw VM values only in marked C slots, with relocation
when using movable marking; raw tokens must never enter Ruby containers.
They do not retain the holder or method entry. Existing weak processing
revokes caches before those objects are collected. GVL required; Box and
multi-Ractor execution refuse. After fork an unchanged cache can regain
availability, but a method-invalidated cache cannot revive. Lexical
refinements, receiver identity, mutable values and arbitrary reentry remain
outside the lookup contract. This dependency on VM/GC internals is a real
future maintenance obligation, even though production/header code is 58 lines.

The relocated Linux x86-64 prerelease is
[available in the fork](https://github.com/thomasklemm/ruby/releases/tag/lowrail-token-4.0.7-274022581f).
Its archive SHA256 is
`8f5d57cedf52249e014849ef1af57d4a2b7a0076a5ff64601a2167bb74c7549e`.
The opt-in installer was integrated by the coordinator on Lowrail main as
[`487bec5`](https://github.com/thomasklemm/lowrail/commit/487bec5065e7d9bec5d1b2df48831eb926e457cb).
Stock Ruby remains the default; this is not a deployment or compatibility claim.

### What the hot method share actually is

The sealed blog form/token/collection inventories are admission-only in the
existing hook arm. After 20 warm requests, an untimed traced show request
called two AR entry guards, four token guards, one collection guard and one
form guard, but **zero method-witness or fact-revalidation scans**. All three
sealed witnesses were nil in that arm. The hot method-identity allocation
share that tokens can remove is therefore **zero**, not the reported
73-object total guard ceiling. Tokens add checks here; they do not replace
the sealed promise, receiver/value checks or continuation checks.

F's DirectSite is different. Its existing hot scan checks **46 methods**, two
times per `/buckets` request. Isolating that scan allocates exactly 46
UnboundMethod wrappers/check; the token vector allocates zero. The attributable
identity share is **92 wrappers/request**, not every guard allocation. The
receiver-specific reader scans and schema/scope/reflection/connection checks
remain unchanged. Module dependencies elsewhere retain public reflection.

The exploratory per-set micro (five successive 20,000-check windows, no A/A
price claim) gave medians: original reflection scan 16.49 µs interpreter /
16.69 µs YJIT, complete captured reflection 19.71 / 19.05 µs, token vector
0.282 / 0.283 µs. These are loop/closure-inclusive diagnostics for all 46
dependencies, **not single-token prices or application speedups**.

### Real request screens, not accepted wall prices

All arms use the identical patched executable. Five arms, three fresh-process
rounds, 20 vector warmups and 30 samples/route, CPU 2; GC enabled. No failed
round or control was discarded. Matching interpreter/YJIT artifacts were
built before each mode. Coverage workers are separate from timing.
For DirectSite, `on` is F's original **reflection**, not hook-only checking;
the historical JSON key `tokens_hooks` means token-versus-existing there.

Allocation medians/request, off-A / existing / tokens / reflection / off-B:

| Workload | Interpreter | Native YJIT |
|---|---|---|
| Blog show | 2377 / 2032 / 2041 / 2446 / 2378 | 2382 / 2038 / 2046 / 2451 / 2381 |
| Fizzy `/buckets` | 8986.5 / 8424 / 8332.5 / 8426 / 8987 | 9074 / 8499 / 8406 / 8499.5 / 9072 |

The ~92-object DirectSite delta agrees with the isolated 46 × 2 scan.
Blog tokens instead add about 8–9 objects relative to its existing guards.
Medians of noisy full requests are not exact causal object counts.

| Workload/mode | Token/existing wall Δ, paired 95% | A/A 95% | Measured JIT flat |
|---|---|---|---|
| Blog interpreter | −3.09% [−15.77%, +8.82%] | [−14.00%, −7.86%] | n/a |
| Blog YJIT | −11.36% [−24.66%, +2.44%] | [−32.63%, +8.18%] | no |
| Buckets interpreter | −4.99% [−18.52%, +4.19%] | [+0.26%, +28.13%] | n/a |
| Buckets YJIT | +3.92% [−8.97%, +18.73%] | [−26.30%, +11.38%] | no |

Every A/A interval fails the prespecified ±2% gate. **No measurable accepted
wall-time benefit.** Full blog exact status/body/all-header checks pass both
seeds in every arm/round. `/buckets`, `/account/users`, `/workflows` also pass.
The remaining three Fizzy routes (`/bubbles`, `/notifications`, bubble detail)
fail body/header equality **including off-A/off-B**, in both execution modes.
The complete six-route cohort is rejected; no normalization or retry-to-green.
All six routes were measured and their failures are retained in the reduced
results. Separate coverage confirms two DirectSite hits per bucket request and
no bucket fallbacks; the blog keeps identical fast-path counts across backends.
Native instructions were unavailable (`perf_event_open` failed); no Ir claim.

### Real Puma RPS: no demonstrated token benefit

One prespecified causal cohort used bet A's `script/rps` from
[`b1e239f`](https://github.com/thomasklemm/lowrail/commit/b1e239f5bfcd2354166aeabddf1e6cc7a605fcaf):
six fresh-server rounds, 5-second warmup / 15-second load, c16, 4 Puma workers
× 1 thread, server CPUs 0–3 / client CPUs 4–7, unchanged app/Puma config.
The route is `/buckets`, not a six-route aggregate or a production traffic mix.
Every arm runs the **same** query program: off-A/off-B use public reflection;
`on` uses tokens. An empty public artifact prevents LOWRAIL=0/1 from adding
another treatment. The connection-local Site is rebuilt in every Puma worker.
Native Rack screens and RPS load windows never overlap in this orb.

| Reflection A median RPS | Token median RPS | Reflection B median RPS | Paired token/A Δ, 95% | Reflection A/A 95% |
|---|---|---|---|---|
| 474.86 | 485.95 | 478.81 | +1.05% [−2.97%, +4.97%] | [−3.78%, +2.10%] |

Cold and warm status/body/all-header workflows pass both seeds in all 18
measured servers and three separate coverage servers. All **128,893 timed +
28,740 warmup** completions are HTTP 200, with zero transport errors.
Independent Python auditing checks actual Site backend records in every
cold/warm sample (reflection in both controls, tokens only in treatment),
nonzero separate coverage hits, four workers' GC/RSS snapshots before/after
load, raw oha hashes, drained-elapsed RPS and all paired ratios. This also
disproves the static review's allegation that worker rebuilds collapse the
contrast: their `"on"` argument enables the query program; backend selection
comes from the already-selected inherited environment.

The largest A/A round spread is 9.10%. A/A fails ±2%, the effect includes
zero and is far below three times that noise floor. **No accepted RPS win.**
The RPS harness does not supply measured-window JIT-flat counters either.
This does not repair the rejected complete six-route Rack cohort.

### Existing alternatives and the upstream use-case bar

Save a Method/UnboundMethod and compare a fresh lookup using `==`, not
`equal?`; compare effective visibility separately. Capture the reflection and
equality implementations rather than dispatching through holder overrides.
This detects suppressed redefinitions, removal/undef, prepend and visibility.
It compares the current definition and may accept an identical restoration;
token revocation is more conservative. Owner-only comparison misses a
same-owner redefinition. `RubyVM.stat` has no scoped method generation;
YJIT/ZJIT invalidation hooks are internal. Public-header-only C reflection
also works but still allocates; core-basic predicates cover a narrower case.
The earlier master experiment prices these alternatives and exercises a real
Rails response after suppressing the digest singleton callback: hooks stay
stale, public reflection and tokens both fall back correctly.
Its [full alternatives table](https://github.com/thomasklemm/lowrail/blob/c2d489c65d969fe8f053e0c9a202bc3644735186/docs/upstream-drafts/ruby-method-token-minimal.md#existing-alternatives)
also records per-check costs and their failed A/A controls; those timings
must not be promoted into accepted prices.

An additional real DirectSite probe suppresses Bubble's singleton callback,
replaces `published_or_drafted_by` with a scope returning no rows and issues
the authenticated bucket request. In interpreter and YJIT, both tokens and
public reflection revoke the shortcut: hits stay **42 → 42**, fallback
counters advance, and status/body/all-header output matches the query-program-
disabled original with the same authenticated request inputs. No output
normalization. An initial scratch probe incorrectly compared two separate
logins (cookie/header mismatch) and assumed one fallback counter per row;
it is retained as a failed harness attempt. The corrected input replay and
counter invariant pass all four mode/backend combinations. This is correctness
validation, not a repeated performance cohort or proof of arbitrary reentry.

| Candidate | Generic Rails fix instead? | Existing JIT enough? | Qualifying token benefit? |
|---|---|---|---|
| Enum predicate from issue example | **Yes**, merged Rails [#59250](https://github.com/rails/rails/pull/59250) | New ordinary defs/direct calls are JIT-visible | No; withdraw example |
| Blog app-specific form/collection specialization | Not a drop-in generic helper rewrite | Does not synthesize app-specific literal rendering | No hot method scan removed; witnesses additive |
| Digest memo unit | Definition checks have a public alternative | Does not memoize this operation across requests | No gated request benefit in master experiment |
| Fizzy DirectSite SQL/bind program | Not a drop-in cleanup; a general Rails compiler would need scope/effect certification | Does not synthesize the query program | 92 wrappers removed, but no gated wall/RPS benefit established |
| Fizzy block-link suffix | Irrelevant: gross ceiling only 59.5/vector | Irrelevant to a ~0.028% ceiling | Killed even with free guards |

Aaron Patterson's new issue note was read, not merely inferred: Rails #59250
replaces ordinary finite enum predicate/bang bmethods with cached ordinary
defs; the predicate uses `self.status_for_database == 1` instead of
`public_send`. It preserves the remaining reader call and leaves non-finite
values/non-compilable names on their fallback paths. This is exactly the
generic-framework alternative the issue's enum example failed to consider.
There is **no row satisfying no generic fix / no existing JIT solution /
demonstrated gated end-to-end benefit**. Recommendation: keep the fork; do
not open the upstream PR on this evidence.

### Verification and review

Ruby 4.0.7 affected `make test-all`: interpreter **569 tests / 14,763
assertions**, YJIT **569 / 14,818**, zero failures/errors, two skips each.
Bootstrap: **2,044 interpreter / 2,041 YJIT**, all pass. Master affected suite:
566 / 17,232; broader YJIT 738 / 19,785, three skips; selected bootstrap 299
pass. No full-suite/alternate-GC/architecture/sanitizer certification.

Fork Lowrail guard tests: **6 / 41**, interpreter and YJIT, including suppressed
hooks, visibility, prepend, missing methods, compaction then invalidation and
collected holders. Screen comparison tests: **4 / 47**, asymmetric token-slower
input detects a wrong contrast. The broad gem run is **not green**: 188 /
2,637, seven failures, 24 skips; six failures are missing Minitest in synthetic
bundles, and one cold-witness comparison differs in existing template/preload/
AR-plan ancestry. All seven identities reproduce on an unchanged `acc130d`
control with its own compiled CLI/native extension and the same Ruby/fixtures
(7 runs / 95 assertions, seven failures). The cold control differs in exactly
the same eight ancestry fields. This establishes baseline failures for these
cases, not a full green suite or complete before/after equivalence.

Independent Thermos correctness and maintainability reviews were run on the
VM patch/backport and Lowrail. Confirmed Lowrail findings led to C-owned slots
instead of a Ruby Array, the explicit token/existing decision interval, A/A
containment and JIT-flat gates. A later ancillary `direction` label also now
uses that interval. That reporting-label change did not alter or rerun any
request cohort. The RPS wrapper explicitly sets the backend from the real arm
*before* enabling the same DirectSite program in every arm; backend names are
recorded from each actual Site, not assumed from the `on` label.
The final static reviewers found no C-vector lifetime defect. Their remaining
RPS-collapse allegation is contradicted by the executed cold/warm worker
records above; it is not silently treated as a passed review. No additional
VM or runtime behavior changed after those reviews.

Reduced numbers, all six route/control failures, per-round RPS/GC/RSS records,
source/binary/artifact/seed digests and raw-result hashes are in
[the JSON appendix](ruby-method-token-407-results.json). Private fixtures,
sessions and full raw logs are deliberately not published.

### Draft upstream PR description — not submitted

```text
[Feature #22459] C-only method-lookup tokens
Expose an existing normal call cache through acquire/check C functions.
No Ruby API, epoch, registry or extra invalidation path is added.
Consumers retain marked C values and guard receiver/reentry assumptions.
Tests cover lookup mutation, suppressed hooks, GC/compaction and mode refusal.
Public reflection detects the same named correctness failures, with allocation.
Lowrail removes 92 lookup wrappers on one Rails route, but has no gated speedup.
This is experimental; the small diff alone is not a reason for Ruby to ship it.
```
