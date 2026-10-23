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
