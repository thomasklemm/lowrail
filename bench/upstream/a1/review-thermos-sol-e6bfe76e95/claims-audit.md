# Sentence audit of A1 at e6bfe76e95

Reviewed from Lowrail starting commit `1e758c1336e45ba1c991e97c6aaa6e0e11e91f10`. The exact reviewed text is
saved as [commit](raw/commit.txt), [body](raw/body.md), and [note](raw/kamipo-note.md). Raw executions, not the
builder's summary, support the judgments below. No upstream text or Rails source was changed in this pass.

## Commit message

1. **“Don't compare owner conditions when joining an association without a scope.”** Accurate subject for the
   guard in `AbstractReflection#join_scope`. “Without a scope” means no association scope items; the target's
   default scope is intentionally still applied. It does not describe a reader change or promise all of 8.1's
   behavior. The prose below makes the scope-items boundary explicit.
2. **“To detect conditions that the association scope removed, join_scope subtracts where clauses before and
   after merging the scope items, also when there are none.”** Verified in the actual merge diff in
   [pins](raw/pins.txt): the initial `fixed_clause` difference precedes `inject`, and the two differences in
   `keep_owner_conditions` follow it. Main runs them even for an empty scope-items array. This no longer uses the
   false premise that the configuration always prevents scope removal.
3. **“Comparing predicates can call into their bind values: Array#- hashes both sides once they are large
   enough, and QueryAttribute#hash and #== serialize the value.”** Verified in `WhereClause#-`,
   `relation/query_attribute.rb:55–64`, and the original width-16/17 and two-predicate probes. “Can” is important:
   the linear case also reaches equality without the hash-table size threshold. It is not a universal promise
   about a specific Ruby implementation's threshold.
4. **“So a join whose target default scope has an out of range condition raised ActiveModel::RangeError
   instead of matching no records.”** Both original range probes and the exact added test reproduce this on
   main on both adapters and settings, with width 17. 8.1 and head return no matching records. The sentence
   describes a demonstrated failing join, not all possible joins; scoped joins are explicitly outside the fix.
5. **“Skip the comparison when the association has no scope items, since nothing can have removed a
   condition.”** The only intervening operation was `scope_chain_items.inject(klass_scope, &:merge!)`. With an
   empty array it does not execute any merge block. The route's fixed values and key equalities remain; scoped
   items take the identical statements in the identical order as main. The ordinary warning-sensitive probe
   and adversarial owner/type controls confirm the intended boundary.

One fix commit includes implementation, test and changelog, with Thomas Klemm as author and committer and no
trailers. It is exactly one commit on the requested main. No message rewrite is needed.

## Queue title and body, sentence by sentence

1. **Title: “Don't compare owner conditions when joining an association without a scope.”** Same accurate
   boundary as the commit subject. The title no longer suggests a reader optimization.
2. **“Since #59836, join_scope compares the where clauses before and after merging the association's scope
   items, to detect owner conditions the scope removed.”** The fetched merge has first parent `f0c9373b05` and
   introduces exactly this `join_scope` bookkeeping; [pins](raw/pins.txt) preserves the diff. The five-tree
   rerun locates the original join-probe change at that merge. This does not attribute every difference from
   8.1 to that merge.
3. **“It does so also when there are no scope items.”** Directly true on main; the new guard is the entire
   library change. Original non-scoped joins exercise the empty case, scoped controls the nonempty case.
4. **“Comparing predicates can call into their bind values: Array#- hashes both sides once they are large
   enough, and QueryAttribute#hash and #== serialize the value.”** Same source and executable evidence as commit
   sentence 3. No unproved global serialization point is asserted.
5. **“So joining an association whose target default scope has an out-of-range condition raises
   ActiveModel::RangeError instead of matching no records:”** Confirmed for the shown unscoped inner join by
   `range_plain.rb`, `range_join.rb` and the targeted test. The shown default scope uses 17 integer predicates;
   it is an example, not a claim that every out-of-range predicate always raises. Width 16 is a control, not a
   claimed failure. Ordinary model schema/connection boilerplate is omitted, as in many short Rails examples.
6. **Snippet.** `(0..16)` creates the necessary 17 key conditions and `2**70` exceeds the ordinary integer range
   on both tested databases. `has_many` has no association scope. `Parent.joins(:children).to_a` raises on main
   and returns `[]` on 8.1/head. It is an inner join: do not generalize this empty-parent result to an unfiltered
   outer join. Those retain owners with empty child collections in the raw probes.
7. **“This skips the comparison when there are no scope items, since nothing can have removed a condition.”**
   Supported by the empty-`inject` reasoning and the tests above. The text no longer claims general reader or
   scoped serialization equivalence to 8.1, or that every bind stays unserialized until SQL compilation.

**No-unasked-numbers audit:** no performance table, timing, allocation, instruction, suite, database or review
counts remain in the body. The numeric Ruby expressions are necessary executable reproducer input, not
unsolicited measurement data. The same-repository PR reference identifies the regression's introduction and
does not leak an internal queue ID. No Lowrail link/footer or process history is present. No must-fix.

## Draft note for kamipo, sentence by sentence

The title and material outside the two separators are Thomas's internal wrapper, not an upstream comment.

1. **Wrapper: “For Thomas, in case he prefers handing the fix over instead of opening a PR.”** Accurately
   presents a draft alternative, not an action already taken.
2. **“Posting needs his approval of this exact text.”** Matches DECISIONS' rule for an unsolicited comment on
   someone else's PR. No posting was performed or authorized by this review.
3. **“It contains no cost numbers, as that policy requires.”** Verified by reading the entire current note.
   The former unsolicited cost paragraph is gone, not hidden behind an optional policy waiver.
4. **“Heads-up in case it's useful: join_scope now compares where clauses with WhereClause#- also when the
   association has no scope.”** Correct for a join-scope build on main, supported by the source and probe.
   Unlike the old note it makes no claim about every association access or cached reader.
5. **“Array#- hashes both sides once they are large enough, and QueryAttribute#hash serializes the bind value,
   so this join raises on main and returns [] on 8.1:”** Both mechanism and this concrete result were rerun on
   the requested trees, SQLite/PostgreSQL, KEEP 0/1. It does not promise universal release equivalence.
6. **Snippet and inline result.** Same repro as the body with `k0..k16`; the comment tells the reader the
   columns are integers. The original built-in `range_plain` and polymorphic `range_join` reproduce it. SQL
   contains `1=0` on 8.1/head, whereas main raises. The setup comment explains a prerequisite rather than
   narrating an implementation and is useful.
7. **“thomasklemm/rails@e6bfe76e95 skips the comparison in join_scope when there are no scope items, with a
   test.”** Verified against the exact remote branch and patch. This identifies the concrete offered fix; it
   is not a benchmark, a publication or a request for credit. The seeded test has the required red/green and
   mutation behavior.
8. **“The association reader and scoped joins compare as on main; a scoped join that unscopes the bad
   condition still raises.”** `association_scope.rb` has the identical blob on head/main. The nonempty branch
   in `join_scope` has unchanged statements/order. All four earlier scoped-output groups are byte-identical
   to main; `scoped_join_removed.rb` still raises at width 17. This sentence is correctly about comparison
   logic, not a promise that arbitrary nested user callbacks in a larger query can never observe the changed
   unscoped join.
9. **Record footer.** Internal links resolve to the narrowed record and historical evidence. Keep this
   wrapper out of any eventual upstream paste, as its existing separators indicate.

No unsolicited cost numbers remain. Reproducer constants, the PR identifier in the wrapper and the exact offered
fix identifier are not performance claims. No must-fix; posting still needs Thomas's separate approval.

## Main README and CHANGELOG follow-through

The main A1 README's current-head preface now identifies the join-only head and explicitly limits its old reader
and “restores 8.1” sections to superseded heads. Its historical numbers are not new measurements of this head;
only the unscoped join cells remain relevant. The narrow record explicitly leaves reader/preload and scoped
out-of-range failures out of scope. This addresses the old overbroad-current-claim finding without pretending
the historical failed build never happened.

The changelog is a top-of-file `*   ` entry with an indented paragraph, blank separators and indented
`*Thomas Klemm*` credit, matching nearby entries and `AGENTS.md`. The entry has eight physical lines including
blank separators and credit (four description lines), not four total lines. Its concrete failure statement is
supported by the same range repro. No gratuitous implementation comment was added there or above a public
method. The public contributor guide permits omitting minor bug fixes; adding this short entry nevertheless
complies with the stricter agent guidance. No format or placement finding remains.
