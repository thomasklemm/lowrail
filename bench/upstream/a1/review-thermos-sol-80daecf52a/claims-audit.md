# Sentence and number audit

Reviewed the exact messages in [commits.txt](raw/commits.txt), the body below the YAML frontmatter of
`bench/upstream/pr-queue/items/A1.md`, and `bench/upstream/a1/kamipo-note.md` as present at Lowrail starting commit
`a9f0dab4cb009fa6c6562951fbef8c2f20988463`. This pass appends a review entry; it does not silently rewrite the
reviewed proposal. The summary and reproductions are in [README](README.md).

## Fix commit

1. **“Check the owner conditions only when an association scope was merged.”** Describes the guard, but not the
   correctness regression now motivating publication. Prefer a message about the demonstrated early-serialization
   failure after the implementation is narrowed/corrected. A scope exists in the chain, not necessarily on the
   final association itself; the Boolean records actual constraint iteration, appropriately.
2. **“Since the association scope can no longer remove the conditions tying the records to the owner, every
   association scope and join scope builds the differences between its where clauses before and after merging the
   scope, also when the association has no scope and nothing can be removed.”** The unconditional differences are
   real. **“Can no longer remove” is false on this main when the setting is false**: the merge deliberately put
   the behavior behind a flag and warns in the old mode. Read the actual `keep_owner_conditions` method and the
   fetched [merge description](raw/upstream-change.json). Say “to detect removed owner conditions” instead. A
   cached association load need not rebuild its scope, so avoid turning this into “every load does this work.”
3. **“Keep the where clauses and compute the differences only after a scope item was merged.”** Broadly describes
   the reader. In `join_scope`, the fixed-clause difference remains before `inject(..., &:merge!)`; only the guard
   is new. Distinguish “only if there are scope items” from “after merging” across the two methods. The message
   also needs to acknowledge that comparing predicates can call user code, and why moving it is valid; the current
   message explains only the optimization and does not justify the demonstrated new scoped behavior.

Author and committer are Thomas Klemm with the requested address. No trailers. No attribution defect.

## Test commit

1. **“Test that owner conditions are serialized when the query is built.”** **Too broad.** `scoped_late_serialization`
   demonstrates that even 8.1 can memoize the binds before SQL compilation, via relation merging and `Array#|`.
   Use a subject naming the concrete regressions rather than promising a global serialization point.
2. **“Comparing where clauses hashes their predicates once both sides have more than 16, which serializes the
   bind values.”** Confirmed for the `Array#-` implementation and shapes used on this Ruby, with 16/17 controls.
   It is not a general portable threshold promised by the Rails API. The threshold comment in the test is useful
   because otherwise a future simplification to a few columns would make the regression disappear.
3. **“Checking the owner conditions before the association scope runs, or for joins that have no scope,
   serialized them earlier than 8.1 did: a join raised ActiveModel::RangeError for an out of range default scope
   condition, and an association scope changing how its keys serialize no longer applied.”** Both concrete cases
   are reproduced against all five requested trees on both adapters and under both settings. The scope lambda
   itself still ran on main; it was its intended effect on already-memoized binds that was lost. That is the
   precise meaning supported by the result, not that association scopes stopped applying in general.

Identity and absence of trailers are correct on this commit too. Keeping fix and regression tests in one eventual
upstream fix commit would fit DECISIONS' “one commit per fix”; the current two-commit development branch is not an
attribution or correctness error by itself.

## A1 title and body, in order

1. **“Don't serialize owner-condition binds for associations without a scope.”** The intended no-owner-check case
   is clear, but the patch also moves work for scoped readers. The new scoped and extension cases in this review
   are not covered by a general “restores 8.1” story. If narrowed to joins, name that boundary in the title.
2. **“Since #59836, keep_owner_conditions compares the where clauses before and after the association scope with
   WhereClause#-, for every association scope and join scope, also when the association has no scope.”** The merge
   introduced the helper; the parent already compared/reapplied owner keys after the earlier change. The helper
   now compares captured owner clauses to the final relation. “On each scope build” is more exact than implying
   every access, and attributing all earlier bookkeeping to this merge would be wrong.
3. **“Array#- hashes both sides once each has more than 16 predicates, and QueryAttribute#== and #hash serialize
   the bind value, so binds are serialized earlier than in 8.1.”** The mechanisms are confirmed from the source
   and executed 16/17 and two-predicate probes. “Once” means the size boundary, not a promise of one hash call per
   predicate: the counter probes demonstrate that more than one invocation is possible. Earlier than 8.1 holds
   for the cited examples, not every scoped build; other relation operations already serialized on 8.1.
4. **“A join whose target default scope has 17 conditions, one of them an out-of-range integer, raises
   ActiveModel::RangeError instead of matching no rows, and a type whose serialization depends on context
   serializes differently.”** Confirmed on both adapters, both settings, plain `has_many` and `as:`. Here the join
   must be unscoped for the head's fix; a scoped join removing the bad default condition is still broken on the
   head. The numeric predicate count is necessary repro data, not a performance claim.
5. **“This keeps the where clauses and compares them only when a scope was merged, after the scope ran.”** Correct
   for the reader's new initial differences, incomplete as a description of the join method, whose fixed clause
   is still computed before its scope-item merges. Also does not disclose the new third-order scoped behavior.
6. **“Without a scope nothing is compared, as on 8.1.”** **Overbroad.** No *owner-condition differences* are computed
   at the changed sites. Other comparisons/serialization remain, including `WhereClause#merge` / `Array#|`.
   `scoped_extension` also refutes general 8.1 equivalence even for the no-association-scope reader.
7. **“The added tests fail on main and pass on 8.1.”** Confirmed, and they also pass on the head, for both settings
   and adapters. The new full suite runs are on the exact head. This is process detail that DECISIONS says to
   leave out of an upstream body; the tests can speak for themselves in the diff.
8. **“It also saves five differences per association load and three per join scope.”** Recounted through the
   actual body fixture: [main](raw/differences-main.txt), [head](raw/differences-rails.txt). Five ordinary reader
   differences and three simple join-scope differences disappear only on no-scope builds. The scoped control
   retains five; cached loads need not perform them. Do not generalize to every association load.
9. **“Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT (A/A ≤ 0.08%).”** Metadata and all raw windows
   confirm the heading and A/A ceiling (maximum 0.07565%). It measures instructions, not elapsed time. Nevertheless
   **remove the performance heading/table from this correctness PR** under DECISIONS lines 358–363 and 402–405.
   A/A/methodology belongs in the internal record even for a performance PR.
10. **All five table rows.** All numbers and rounded changes match raw Callgrind and object data, independently
    reconstructed in this pass:

| Case | Objects main → branch | Instructions main → branch (rounded) | Change |
| --- | --- | --- | --- |
| posts | 121 → 111 | 720,039 → 706,950 | −1.8% |
| profile | 101 → 91 | 593,753 → 580,714 | −2.2% |
| belongs_to | 101 → 91 | 572,512 → 559,364 | −2.3% |
| through | 158 → 148 | 819,115 → 806,150 | −1.6% |
| join | 107 → 99 | 358,827 → 347,917 | −3.0% |

11. **“An association with a scope keeps the check; its allocations are unchanged.”** It keeps the check. Equal
    allocations are demonstrated for the one `published_posts` fixture (169 no-JIT, 172 YJIT), not universally.
    The checks' timing is not unchanged. Drop the performance clause along with the table rather than making the
    correctness body longer to explain the diagnostic measurement.

The body now contains **no YJIT sentence**, which addresses the earlier publication finding. The frontmatter's
“YJIT diagnostic only (no JIT-flat counters)” label is correct. The −1.2% to −4.1% range is rounded from −1.23109%
to −4.12515%; the scoped +0.3% is +0.27860%, A/A 0.09600% (0.10% rounded). No cause has been isolated. A fixed warmup
is not a JIT-flat gate: `script/upstream-bench` does not capture the requisite compilation/invalidation counters.
The old body cohort is not recertified by rerunning ordinary correctness tests on the same library code.

## Note for kamipo, in order

1. **Internal preface: posting needs Thomas's approval of the exact text.** Correct policy, and no posting was
   performed. **“The two lines of cost can be dropped if Thomas wants it to stay within that policy” must change:**
   the default policy already requires dropping them. An exception would need explicit approval; this review is
   not such approval. The numbers are not needed to understand a correctness repro.
2. **“Heads-up in case it's useful: keep_owner_conditions compares where clauses with WhereClause#- on every
   association scope and join, also when the association has no scope.”** Mechanism supported; qualify scope
   *builds*, not every cached load. The opening matches the approved human-readable note style.
3. **“That is five differences per author.posts load and three per join_scope.”** Counts confirmed in the measured
   fixture, subject to the no-scope-build qualification. These are unsolicited cost counts and can be cut too;
   the failure needs no subtraction-count prelude.
4. **“Array#- hashes both sides once each has more than 16 predicates, and QueryAttribute#hash serializes the bind
   value, so binds are now serialized before the query is built.”** The mechanisms and threshold probe hold on
   this Ruby. “Before SQL compilation” is less ambiguous than “before the query is built.” 8.1 already serializes
   some binds during relation building, so this should not suggest a universal new compilation boundary.
5. **“On 8.1 this returns []; on main it raises.”** The shown plain inner join does, on both adapters. It is a
   model snippet, not a standalone script: schema and connection setup are omitted, and the inline comment says
   the integer columns must exist. That is acceptable as a short example; complete executed scripts are retained.
   `0..16` makes 17 conditions and `2**70` is outside both adapters' ordinary integer ranges. The schema comment
   explains required setup and is useful, not a superfluous patch comment.
6. **Snippet result comment.** Correct for the inner join; do not transpose it to an unrestricted eager load,
   where the actual result is a retained parent with no associated child.
7. **“Custom types whose serialization depends on context see the same timing change.”** Demonstrated by both
   earlier examples, not an assertion that all custom types differ or that the head restores all such types.
8. **“Two predicates on one column are enough for that, because QueryAttribute#== serializes too.”** Verified in
   `linear_join.rb` across all five trees, both adapters and settings. It is necessary counterexample size data,
   not unsolicited benchmarking.
9. **“Cost per load against 8.1 in our fixture (Callgrind, interpreter, Ruby 4.0.9): author.posts +3.6%, A/A 0.01%;
   joins(:posts) +5.6%, A/A 0.01%.”** Numerically correct: the raw census main pair gives +3.56699% / A/A 0.01409%
   and +5.59496% / A/A 0.01028% against the raw 8.1 cells. **Cut this sentence under the no-unasked-numbers rule**,
   regardless of arithmetic. It compares census main `4500a94c34`, not a newly measured head; the relevant source
   files were checked unchanged at review main. This pass audits those records, not a new speed cohort.
10. **“About half of it is these comparisons, 10 of 107 objects per load.”** The branch micro saves 10 objects from
    main's 107-object fixture and about 2% of instructions, versus about 3.6% historical instruction regression.
    “Half” is a loose cross-cohort estimate, not isolated causal attribution. **There is no 8.1 allocation
    regression from 96 to 107:** that 96-object row is census 9; the raw 8.1 row is 148.05 objects versus main's
    107.04. Do not let this paragraph imply otherwise. Cut it with the preceding cost sentence.
11. **“thomasklemm/rails@80daecf52a skips the comparisons when no scope was merged, and adds tests for the case
    above and for a scope that changes how its keys serialize.”** Verified against the fetched tree and exact
    class. The tests pass as claimed but need the range-test strengthening. It is a branch reference, not an
    upstream posting or approval to publish.
12. **“When a scope was merged, the check still compares, after the scope ran.”** Correct as a terse reader
    account; distinguish the join method's before-merge fixed-clause difference if retaining this sentence. The
    new scoped third answer makes this an unresolved correctness boundary, not safety justification.
13. **Record footer and internal links.** They resolve within Lowrail and are appropriate for Thomas's draft
    wrapper, not material to paste into an upstream comment under “Nothing internal upstream.” No approval or
    upstream action is implied by the wrapper.

## Frontmatter and record-only numbers

The requested body audit does not turn every historical note into a fresh live-state certification. Numeric
frontmatter claims were checked where source records exist:

* The raw census micro confirms has-many +3.6%, has-one +5.3%, and joins +5.6% to +7.8% against 8.1. The mean
  has-one delta is +5.25232%, rounding to +5.3%. The maximum interpreter body A/A is below 0.08%.
* `share-A1.tsv` has 70 workload rows, 56 with nonzero self instructions, covering all eight apps. The reach
  numbers reconstruct; they describe that attribution cohort, not eight apps newly executed for this review.
* `census-per-request.txt` contains 29 summary rows: median −0.19%, minimum −0.89%, and objects lower in 28.
  The casa case-edit summary is 23,950 → 23,253 objects (−697). Those aggregate figures match the summary, but
  this A1 directory does **not** retain the underlying per-request Callgrind windows. This pass therefore does
  not independently certify their original extraction or the claimed cookie-harness attribution. Keep them
  internal and label their provenance; do not promote them to newly checked upstream evidence.
* Merge date 2026-11-17 and the merge SHA match the fetched upstream change records. “No open PR touches them,”
  the 15-PR cap usage, and other live queue conditions in the old note were not re-certified here. They are not
  part of an approved body and must be refreshed separately before any eventual opening.
* The original follow-up claims “8.1 = head in every case” only for its finite probe set; that set does match.
  Generalizing it to every association or custom type is refuted by the new receipts. “No exact fast path exists”
  should mean no unconditional no-scope skip is exact against main, not mathematical impossibility for every
  restricted subset one could define.
