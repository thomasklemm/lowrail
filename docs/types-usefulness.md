# Types usefulness: fixed slots, real answers, held-out questions

2026-10-23. Advisory types/MCP only, following [observed returns](types-returns.md).
No lowering, activation, application-source patch, upstream contribution or
speed/support claim. Apps are anonymized A–E; raw source, questions, boot
receipts, observations and diagnostic locations are not published in Git.

**The in-sample result is not a generalization claim.** After fixing gaps found
with 100 questions, a separate 50-question check was written and ground-truthed
before its first MCP run. No implementation, test or evaluator code changed
after that run. Its recall is substantially lower.

## Standalone use and bounded improvements

```sh
lowrail facts APP                         # explicit boot/materialization
lowrail types APP --rbs EXTERNAL_SIG_DIR  # subsequent reads need no Ruby boot
lowrail mcp APP                           # read-only JSON-RPC over stdio
```

Neither types nor MCP needs a lowering build, installation into the app, or
runtime activation. Existing boot facts remain required. Agents can ask about
schema/associations, method returns/locations/owners, routes, callers and view
inputs; answers expose evidence and limitations rather than certify execution.

- Resolve collection queries through the actual booted CollectionProxy or
  model-specific relation, including custom overrides, before using the
  version/source-checked Rails contract. Preserve element types through
  `order`, `to_a`, nullable `first`/`last`/`take`, and their bang variants.
  With-count overloads remain unions, not guessed single-element returns.
- Reuse the eight-round source return fixpoint. Add final top-level `return`,
  safe-navigation nil propagation, static parameter environments and bounded
  native constructor/Array-join/Hash-keys-values contracts. Unsupported early
  returns, control flow, blocks and unknown dependencies still refuse.
- Sample exact built-in Array/Hash contents using bound methods: eight entries
  per value, one level deep, with the existing 16-entry method/process cap.
  Empty containers, subclasses, nested members and unloaded relations are not
  guessed or recursively enumerated. No relation SQL is issued by sampling.
- Keep member evidence **observed**. It never feeds the static fixpoint or
  narrows a static generic. Direct Array/Hash member contradictions now join
  the conflict ledger; correlated union arms/nested members are not certified.
- `view_locals` reports literal partial-render bindings, collection/object
  locals, strict locals and route/source-matched controller exit-ivar context.
  These are contextual hints, **not availability/dominance facts at render**.
  Observed provenance survives expressions; no view hint feeds static inference.
  Missing/changed templates refuse; dynamic partial dispatch is not modeled.
- `callers` distinguishes concrete receiver identity even when two model
  constructors share an implementation. It separates unresolved candidates
  from known callers and always reports incomplete coverage. Blocks, dynamic
  receivers, ambiguous lexical constants and unindexed files remain boundaries.

## Same 21,063 effective slots

The transferred frozen facts/argument/return inputs reproduced the old ledger
exactly. Compare identities `(receiver, method, return/parameter ordinal/name)`,
not sample bytes or totals alone. Ivars, contextual view inputs and support
declarations are excluded from both sides. No slots were removed or added.

Order: **proven / static / observed / unknown**.

| App | Slots | Before | After |
|---|---:|---|---|
| A | 296 | 2/99/7/188 | **2/99/7/188** |
| B | 2,627 | 14/953/314/1,346 | **14/955/312/1,346** |
| C | 6,723 | 30/1,181/495/5,017 | **30/1,187/489/5,017** |
| D | 9,874 | 40/2,561/1,611/5,662 | **40/2,574/1,599/5,661** |
| E | 1,543 | 19/499/280/745 | **19/501/278/745** |
| **Total** | **21,063** | **105/5,293/2,707/12,958** | **105/5,316/2,685/12,957** |

There are **23 independently static contracts**: 22 previously observed and one
previously unknown. Repeating inference with **no observations file** reproduces
all 23 names/evidence without observed provenance. Samples are retained, not
promoted. One newly visible constructor-versus-test-double conflict remains:
15 real-instance samples and one verifying-double sample disagree with a native
constructor contract. The unchanged spec explicitly stubs that constructor.
The static type and contradictory sample both remain visible; no classification
or exception rule was weakened to achieve zero conflicts.

### Collection depth, not another slot-count claim

A new seed-1379, one-worker, 16-sample cohort supplies member histograms only.
Supplement the frozen observations by **method identity, exact source location,
slot and matching outer container class**; never replace their outer histograms,
calls, omitted returns or conflict classifications. The slot identities/statuses
above remain unchanged. Do not attach ivar samples to inflate this census.

| App | Original returns with unknown generic members | Improved | No remaining `untyped` member | Still incomplete |
|---|---:|---:|---:|---:|
| A | 0 | 0 | 0 | 0 |
| B | 21 | 19 | 15 | 6 |
| C | 46 | 38 | 36 | 10 |
| D | 149 | 124 | 91 | 58 |
| E | 15 | 13 | 13 | 2 |
| **Total** | **231** | **194** | **155** | **76** |

All 155 resolved names retain **observed** evidence, not static/proven evidence;
39 other returns improve only partially. Nested/empty/uncalled containers and
unknown member classes account for remaining gaps. In total 346 existing
return/argument slots receive usable member histograms. A more specific sampled
name still does not establish all possible values or nullable possibilities.

Sampling runs: A 21 tests/54 assertions, C 234/671 and E 119/381 are green;
B 124/458 has the same seven `Current#reset_all` errors as the historical cohort.
D completes 3,761 examples with **71 failures, 21 pending and one outside-example
error**: its socket-only PostgreSQL URL is rejected by DatabaseCleaner and its
missing local encrypted test credentials cause Short.io WebMock mismatches.
These are **partial observations**, not application support proof. A separate
local-DB connection check with an explicit localhost URL and Unix-socket host
parameter passes the cleaner safeguard; the failing cohort is retained, not
rerun until green or relabeled successful. Earlier zero-hook runs with a wrong
recorder root are retained separately and contribute no member evidence.

## Answer quality: discovery set and held-out set

`script/types-usefulness` launches the real stdio server and saves every raw
response, selection, wrong fact and missing fact. Each app has 20 fixed discovery
questions; the held-out set has 10 additional, nonduplicate tool/argument queries
per app. They cover associations, nullable attributes, application returns,
definitions, routes, view locals, callers and call-site types. Source definition
owners/lines, schemas, reflections and routes come from fresh Ruby boots;
controlled pure calls probe asymmetric and nil/non-nil cases. View/caller keys
are independently source-inspected, with hashes, not copied from MCP. This is
**tool-answer evaluation with preselected tools**, not an LLM tool-selection test
or a complete rendered-view/callback execution audit.

Expected and selected JSON facts are sets. Precision = \(TP/(TP+FP)\), recall =
\(TP/(TP+FN)\). `untyped`/unavailable answers abstain. An incorrect whole return
contract counts as one FP and one FN; a partially answered caller set contributes
its real TPs and missing FNs. This is strict expected-contract matching, not an
RBS subtyping/entailment checker. Route filters use the tool's documented substring
semantics. Answer columns distinguish exact / non-exact answered / abstained;
non-exact caller subsets are not fabricated callers.

| App | Discovery precision, before → after | Discovery recall, before → after | After exact / non-exact / abstained (20) | Held-out precision | Held-out recall | Held-out exact / non-exact / abstained (10) |
|---|---|---|---|---:|---:|---|
| A | 100 → 100% | 73.91 → 86.96% | 19 / 0 / 1 | 100% | 53.85% | 6 / 1 / 3 |
| B | 100 → 100% | 72 → 100% | 20 / 0 / 0 | 100% | 92.31% | 8 / 0 / 2 |
| C | 95.45 → 100% | 70 → 100% | 20 / 0 / 0 | 100% | 64.71% | 8 / 1 / 1 |
| D | 95 → 100% | 76 → 100% | 20 / 0 / 0 | 80% | 72.73% | 7 / 2 / 1 |
| E | 100 → 100% | 75.86 → 100% | 20 / 0 / 0 | 100% | 94.12% | 9 / 0 / 1 |
| **Total** | **97.98 → 100%** | **73.48 → 97.73%** | **99 / 0 / 1** | **97.06%** | **78.57%** | **38 / 4 / 8** |

Discovery TP/FP/FN: **97/2/35 → 129/0/3**; exact answers **83 → 99**.
Held-out TP/FP/FN: **66/2/18**. Do not combine these cohorts or present the
discovery recall as out-of-sample performance.

### Wrong and missing answers, not just the aggregate

- The old discovery answers include two sampled return contracts missing
  nullable possibilities: a base-model return represented only by sampled
  subtypes, and a service represented only by sampled String returns. Source
  inference fixes these two particular methods. The final discovery abstention
  is implicit collection-to-partial dispatch (three missing local names).
- Initial new callers mixed different model constructors sharing the same Rails
  owner, producing false positives. Concrete receiver identity fixes that bug.
  Literal collection locals/counter/iteration fix the largest view-answer gap.
  One hand-keyed discovery caller was independently corrected from `new` to
  `show` in unchanged source; **both binaries** were replayed with that same key.
  Original keys/results remain retained.
- Held-out **D-h04** returns observed `String`; independent source and nil/name
  probes require `(String | nil)`. **D-h05** returns observed
  `Array[ActionController::Parameters]`; absent/present-parameter probes require
  `(Array[ActionController::Parameters] | nil)`. These are the two false facts.
  Both have observed evidence and null `proven_type`; they are not static proofs.
- Held-out **A-h09** finds one of two real callers, missing the call inside a
  `respond_to` block. **C-h09** finds one of six, missing mixin/explicit dynamic
  receiver sites. Returned callers are real; six missing sites in total demonstrate
  the bounded index's recall limit, with unresolved candidates kept separate.
- Eight held-out abstentions: five dynamic-receiver call-site types, one
  association-ID array contract, one ordinary comparison return, and one dynamic
  partial's three local names. No post-holdout code changes were made to improve
  these scores. They remain concrete follow-up gaps.

The held-out question file was frozen at SHA-256
`ac8cbabe8148a673c18e37da127d9aaa13d36e280b4111be5e9e6fd5a54267cb`,
and evaluated binary at
`63f28c0cde70a8117780055770f86a9268cceb4101b3e927f4bf87f627543f12`.
A per-file implementation/test/evaluator hash manifest is checked after replay
and before delivery. Ground-truth files precede the first held-out MCP call.

## Steep: still advisory, and deeper members expose another dependency

Ruby 4.0.7, RBS 4.2.0, Steep 2.1.0. Same unchanged copies of app models,
controllers, helpers and services, same generated-file layout and one worker:

```ruby
target :app do
  signature "sig"
  check "app"
end
```

| App | Old frozen export problems | New code, frozen samples | New code + sampled members | Final affected files | Final `rbs validate` |
|---|---:|---:|---:|---:|---|
| A | 2 | 2 | 2 | 1 | Pass |
| B | 885 | 885 | 886 | 96 | Pass |
| C | 926 | 925 | 928 | 102 | Pass |
| D | 2,050 | 2,045 | 2,049 | 181 | **Fail: missing OpenStruct declaration** |
| E | 518 | 518 | 524 | 59 | Pass |

**Every Steep invocation exits 1.** Counts include reported errors and warnings;
diagnostic-ID breakdowns and full outputs are retained. No warnings, nullable
associations, member types or new diagnostics were suppressed. A's two nullable
association/Turbo callback diagnostics remain the historical two errors.

All five frozen-sample exports validate. The deeper member cohort introduces
`Array[OpenStruct]` and a union containing that element into D's generated RBS.
Its name-only export does not supply an OpenStruct declaration: plain RBS validate
reports two unresolved type uses. An explicit `-r ostruct` check also fails because
RBS 4.2.0's installed library set has no such signature. This is a real remaining
consumer-integration gap, **not a passing RBS check**. It was found after the
held-out freeze and is reported rather than patched, stubbed or erased to green
the result. More member precision can expose diagnostics/dependencies instead of
monotonically decreasing a checker error count.

## Receipts and reproduction

[Machine summary](types-usefulness.json) contains anonymized counts, cohort
hashes and diagnostic categories only. Private inputs, full selected facts and
responses, slot/member transitions, source hashes and all failed attempts remain
under the external experiment root `/tmp/lowrail-types-usefulness/`, with analysis
receipts in the ignored `.lowrail/private/types-usefulness/`. No corpus source or
private answer key is a repository fixture.

The transferred baseline archive SHA-256 is
`2fcc6d0ca0ecd97719437c380cbc3eb7ac9b89cb7984574800d7c4c3945a5343`;
its published returns ledger matched byte-for-byte. Compare baseline/current
outputs using the same copied pinned facts and filtered observations as in
[the returns reproduction](types-returns.md#reproduction), asserting identical
slot keys. Run the no-observation control separately. For fresh samples export
`LOWRAIL_OBSERVE_ROOT` inside the child shell, not just in the CLI's environment.

Freeze external question files and boot/source receipts before either replay:

```sh
script/types-usefulness QUESTIONS_20.json --lowrail OLD_BINARY > before.json
script/types-usefulness QUESTIONS_20.json --lowrail NEW_BINARY > after.json
script/types-usefulness HELD_OUT_10.json --questions-per-app 10 \
  --lowrail NEW_BINARY > held-out.json
rbs -I EXTERNAL_SIG_DIR validate
steep check --jobs=1 # in the disposable checker copy above
```

Verification on the frozen implementation: `cargo test --locked` **57 passed**;
observer subprocess tests, seed 1729, **7 runs / 87 assertions / no failures,
errors or skips**; `git diff --check` clean. Tests exercise override refusal,
safe-navigation boundaries, hostile singleton container methods, unloaded
relations, caps/nesting, member conflicts, stale templates, constructor receiver
identity, view evidence preservation and real MCP stdio discovery/exports.

## Held-out v2 on public apps (2026-11-02)

The private apps and question sets above are not available in this orb, so
their cohorts were **not** rerun. Instead, a separate agent wrote 40 new
questions (20 each for Campfire `af4dd9f` and Writebook `be1f8fc`) with
source-derived ground truth and froze them before any `types`/`mcp` call
(SHA-256 `d03454cd44d5fa1b1860b860d22cdfb6c57462ef296f3a684c9b68e2a961b05c`;
seed `20261102`; per app 9 `type_of`, 5 `callers`, 3 `view_locals`,
2 `model`, 1 `routes`). Two strata were redefined before evaluation because
neither app calls an app method inside `respond_to`: those questions ask for
route-helper callers instead. Inputs and results stay outside Git.

The changes measured here: callers keep the controller as `self` in Rails
`respond_to`/`format`/variant blocks and resolve module methods through the
queried including class (`via`); `view_locals` follows `render @record(s)`
when the model has stock `to_partial_path` (new boot fact `partial_path`) and
no subclasses; sampled returns keep a `nil` arm when the source can return nil
(bare/`nil` return, missing `else`, safe navigation). These were written from
the gaps listed above, **before** the v2 questions existed; nothing changed
after the first v2 run.

Same questions, same observations (`LOWRAIL_OBSERVE_TYPES_ONLY=1 lowrail
observe … --samples 16`, Campfire 634 runs / Writebook 119 runs, no
failures). Each binary used facts from the same dumper; the question writer's
facts already came from the working tree that contained the `partial_path`
change, which the older binary ignores.

| Run | Precision | Recall | TP/FP/FN | exact / wrong / abstained |
|---|---:|---:|---|---|
| before, no observations | 100% | 45.45% | 25/0/30 | 15 / 0 / 25 |
| after, no observations | 100% | 50.91% | 28/0/27 | 16 / 0 / 24 |
| before, observed | 83.78% | 56.36% | 31/6/24 | 21 / 6 / 13 |
| **after, observed** | **85.00%** | **61.82%** | **34/6/21** | **22 / 6 / 12** |

Strict string scoring. Treating `(T | nil)` and `T?` as the same spelling
(declared in the question file before evaluation) gives 86.49% / 58.18%
before and 90.00% / 65.45% after; report it beside, not instead of, the
strict score. This cohort is harder than the first held-out set (different
apps, more parameter and callback questions) and is not comparable with its
78.57% recall.

Remaining wrong answers: three sampled **parameter** types miss a nil the
callers can pass (the nil-path rule covers returns only), one `around_create`
callback return misses `false`. Abstentions: route-helper targets resolve to
no boot method (2), `ClassMethods` concern targets and instance-method callers
through dynamic receivers (4), a block-only caller (1), a scoped relation
assigned in a controller (`render @books`), a `render layout:` partial, and
two return/nil-ability questions without evidence.

**After v2 (in-sample, not held-out):** `callers` now answers named-route
helpers (`*_path`/`*_url` of a booted named route on a class that includes
`ActionDispatch::Routing::UrlFor`), which boot facts cannot see because they
live in an anonymous module. Rerunning v2 fixes c14 (strict 85.37% / 63.64%),
while w14 stays an abstention: `book_slug_url` comes from `direct`, not the
route table. v2 is no longer a held-out measure for this change.

## Held-out v3 on public apps (2026-11-03)

v2 is in-sample after the changes above, so a separate agent wrote 40 new
questions on two other public apps and froze them before any code change:
Fizzy `6f1d200` (with `fixtures/corpus/fizzy.patch`) and Lobsters `366e211`
(`.ruby-version`/lock pinned to Ruby 4.0.7, as in the census-4 overlay;
`database.yml.sample` copied). SHA-256
`d7ad9a59d324aea1aba0de41757bf15c074513e51b75e868182031f69e1cb9fd`, seed
`20261103`, same per-app strata as v2. Ground truth comes from app, Rails and
gem source. Eight questions are marked uncertain (f03, f06, f07, f14, f16,
l05, l06, l14). Departures were recorded before evaluation:
- Lobsters has no `collection:` renders, so its collection stratum became
  "partial rendered inside an `each`".
- The respond_to stratum drew `HomeController#params` (l14).
- The dynamic-partial pool misses `events/_event`.

Inputs, results and the writer's receipts stay outside Git.

The changes, written from the v2 gaps only, as first measured at `e39898b`.
The review fixes below narrow three of them:
- **Callers, constants in blocks:** callers resolve constant receivers inside
  blocks (constant lookup is lexical) and attribute them to the enclosing
  def. A relative constant names the top-level one only when no enclosing
  scope or ancestor of the innermost scope has it booted or as an
  autoloadable file; otherwise the call stays unresolved.
- **Callers, concern methods:** a queried module method (a concern, a
  `ClassMethods` module) is reported through each class that includes or
  extends it (`via`).
- **Callers, core iterators:** blocks of core iterators (`tap`, `each`,
  `map`, `gsub`, …) on an explicit non-self receiver keep the caller's self.
  An implicit-self `each` may be an app DSL and stays unresolved.
- **Callers, `direct` helpers:** helpers from `direct` resolve through the
  booted route helper modules.
- **`view_locals`:** follows partial layouts (`render layout: "x",
  locals:`). It also follows `render @records` when every sampled relation
  class names the same model.
- **Sampled positional parameters:** gain a nil arm only where a resolved
  call site passes a value whose type has one. Call sites are method bodies
  re-walked after observations, or templates calling a uniquely owned app
  helper with an incoming render's locals. The provenance names the site.
  Nothing feeds the static fixpoint, and this is no blanket `| nil`.

Implementation commit `e39898b`, binary SHA-256 `4ec2ed32…`; baseline
`origin/main` `206a2fc`, binary `d8fa11c6…`. Observations used
`LOWRAIL_OBSERVE_TYPES_ONLY=1 lowrail observe APP --samples 16`, seed 1379:
- **Fizzy:** `bin/rails test`, 124 runs, **7 errors**: `Current.reset_all`
  under the Rails 8.1.4 overlay.
- **Lobsters:** `rspec`, 927 examples, **1 failure**: an order-dependent
  duplicate banned domain in `submit_story_spec.rb:178`.

These are partial observations. They were kept rather than rerun until
green. Each binary answered v3 once, after the commit; nothing changed
afterwards.

### v3, held-out

| Run | Precision | Recall | TP/FP/FN | exact / wrong / abstained |
|---|---:|---:|---|---|
| before, no observations | 100% | 58.21% | 39/0/28 | 17 / 2 / 21 |
| after, no observations | 100% | 61.19% | 41/0/26 | 19 / 1 / 20 |
| before, observed | 96.08% | 73.13% | 49/2/18 | 27 / 4 / 9 |
| **after, observed** | **96.43%** | **80.60%** | **54/2/13** | **30 / 3 / 7** |

Strict string scoring. The `(T | nil)`/`T?` equivalence gives the same
numbers on v3, because no answer differs only in spelling. "Wrong" includes
partial caller and local sets with no false fact.

**Fixed:**
- f15: a call inside a `tap`/`each` block.
- l15: a call inside an iterator block.
- f18: `render @buckets` over sampled relation arms.

**Remaining wrong answers:**
- f03 (uncertain): `Bubble`, expected `Bubble?`. The sampled return has no
  source nil path.
- l05 (uncertain): `Array[(Array[untyped] | bool)]`; the member is unknown.
- l17: misses `linking_comments`, which a controller passes with
  `render partial:`.

**Abstentions:**
- f05, f06: methods of an association extension module.
- f12, f16, l12: receivers are association proxies, ivars or block
  parameters.
- f19: `render bubble.messages` on a partial local.
- l19: a render hash built in the controller (`render @above`).

### v2, in-sample

| Run | Strict precision / recall | TP/FP/FN | `T?` equivalence |
|---|---|---|---|
| before (`206a2fc`), no observations | 100% / 52.73% | 29/0/26 | 100% / 52.73% |
| after, no observations | 100% / 63.64% | 35/0/20 | 100% / 63.64% |
| before (`206a2fc`), observed | 85.37% / 63.64% | 35/6/20 | 90.24% / 67.27% |
| **after, observed** | **88.00% / 80.00%** | **44/6/11** | **96.00% / 87.27%** |

**Fixed:**
- c12, c16: `ClassMethods` targets.
- c17: `render layout:`.
- w14: `direct`.
- w15: a block-only caller.
- w19: `render @books`.
- c07, w06: parameter nils. c07 comes from a template local bound to an
  enum reader; w06 from a caller's local assigned from a method with a nil
  path.

c07 and w06 now answer `(String | nil)` and `(Array[String] | nil)`. Strict
scoring still counts them as wrong, as it does w01 and w03; the
equivalence counts all four as correct.

**Not changed, and why:**
- **w02:** an around callback's `yield` returns `false` only when a `before`
  callback nested inside it halts. Leaf's booted create chain has no
  `before` callbacks, and Leaf has no subclasses, so the yield returns the
  record id. **Disputed ground truth:** the uncertain `(Integer | false)` is
  not encoded, and w02 is still scored against it.
- **w07:** the caller passes `leaf.leafable.body.content` through a
  delegated type. Its ground truth is uncertain (NOT NULL column).
- **w12, w16:** receivers are an association proxy (`user.sessions`) and an
  ivar set in a concern's callback. Typing them would need certified
  cross-callback flow (invariant 6), so these stay abstentions.
- **c05, c09, w04:** returns without evidence; outside this change.
- **Spelling:** sampled unions keep the `(T | nil)` spelling that the
  existing tests and slot census use. This is decided: switching
  single-arm unions to `T?` would only inflate strict string matches.

Verification: `cargo test --locked`, 49 + 4 + 8 passed, including the
real-blog stdio round trip. Both new tests fail on `206a2fc`. `git diff
--check` is clean. The Lobsters checkout carries an AGENTS.md asking agents
not to contribute code to Lobsters. It was only read and observed as a
corpus app, as in the census.

### Review fixes and a second v3 measurement (2026-11-03)

An independent review of `e39898b` found five ways the changes above could
report a new false fact where `206a2fc` abstained. Each is fixed and has a
regression assertion that fails on `e39898b`:

1. **An iterator name does not prove the block keeps `self`.** A block
   keeps it only when the receiver's static, non-sampled type resolves the
   method to Ruby's own implementation: `Kernel#tap`/`then`/`yield_self`,
   or the `Array`/`Hash`/`Enumerable`/`String`/`Integer`/`Range` iterator
   with no Ruby override. An app `Driver#each`, an untyped receiver or an
   implicit-self `each` stays unresolved.
2. **Module names and file paths cannot prove that no constant shadows the
   top-level one** (`module Shop; Card = Other; end`). The dumper now
   records each module's own constant table, autoloads included, which
   loads nothing. It also records the constants of unnamed ancestors. A
   relative constant resolves only when every lexical scope and every
   ancestor of the innermost scope is booted with a table that lacks the
   name. Any unknown table refuses. The file-path heuristic is removed.
3. **Arguments are evaluated left to right on one environment.** In
   `consume(reset, @value)`, the call `reset` invalidates `@value` before
   it is read, so no stale nil is reported.
4. **Template helper calls inside blocks are used only when the block's
   method is a Rails `ActionView::Helpers::*` or `Turbo::FramesHelper`
   helper.** These run the block through `capture` with the view as
   `self`. Other blocks, such as `instance_eval`, are skipped.
5. **`layout:` names a partial layout only for an options-hash render with
   a block or beside `partial:`.** `render template: …, layout:` does not.

Same frozen v3 file (`d7ad9a59…`), observations and v2 inputs. Facts were
regenerated with the new dumper, which adds constant tables; dump errors
are unchanged per app. This is a **second measurement of v3**, taken after
a correctness fix prompted by review rather than by v3 results. It is not
a fresh held-out cohort; the first measurement above remains the held-out
result. Binary `32409f81…`.

| v3 run | Precision | Recall | TP/FP/FN | exact / wrong / abstained |
|---|---:|---:|---|---|
| `206a2fc`, no observations | 100% | 58.21% | 39/0/28 | 17 / 2 / 21 |
| fixed, no observations | 100% | 58.21% | 39/0/28 | 17 / 2 / 21 |
| `206a2fc`, observed | 96.08% | 73.13% | 49/2/18 | 27 / 4 / 9 |
| `e39898b`, observed (first measurement) | 96.43% | 80.60% | 54/2/13 | 30 / 3 / 7 |
| **fixed, observed (second measurement)** | **96.30%** | **77.61%** | **52/2/15** | **28 / 4 / 8** |

Strict scoring; the equivalence gives the same numbers on v3. Relative to
`e39898b`, only iterator certification changed answers:
- f15 is partial again: it misses `Notifier#generate`, whose call sits in
  an uncertified block.
- l15 abstains again.

f18 stays correct.

| v2 run (in-sample) | Strict P / R | TP/FP/FN | `T?` equivalence |
|---|---|---|---|
| `206a2fc`, no observations | 100 / 52.73 | 29/0/26 | 100 / 52.73 |
| fixed, no observations | 100 / 60.00 | 33/0/22 | 100 / 60.00 |
| `206a2fc`, observed | 85.37 / 63.64 | 35/6/20 | 90.24 / 67.27 |
| `e39898b`, observed | 88.00 / 80.00 | 44/6/11 | 96.00 / 87.27 |
| **fixed, observed** | **87.50 / 76.36** | **42/6/13** | **95.83 / 83.64** |

On v2, only w15 changed: it abstains again, because the receivers of its
`tap`/`gsub` blocks have no certified static type. c12, c16, c07 and w06
survive with constant tables and ordered arguments. Strict precision stays
above `206a2fc` on both sets.

Verification: `cargo test --locked`, 49 + 4 + 8 passed. `git diff --check`
is clean. `gem/test/facts_test.rb` has the same three real-blog failures
with and without this change.
