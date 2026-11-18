# A1 at 80daecf52a: changes requested

Reviewer: `thermos-sol`, 2026-11-18, thread `T-01a1ec80-a3c9-72e0-b083-88c79272ced4`.
Both Thermos rubrics were loaded and applied by this reviewer in this thread, as requested. There were no
subagents or other review threads; this is not a claim of two independent reviewers.

**The original regression diagnosis is right, but the head is not a general restoration of 8.1 serialization
timing.** Both earlier repros and all the follow-up probes reproduce the reported revision split on both adapters.
New probes find a third answer on the head, including on the scoped path. The two added tests have the advertised
red/green behavior, but the range test needs one child row to protect its claimed result, not only absence of an
exception. The correctness PR's performance table and the unsolicited note's cost paragraph must be cut.

No Rails source was edited, no fork push was made, and nothing was posted upstream. Only the review record and
the queue pass are delivered in Lowrail. The draft body and note remain unchanged, so the findings below remain
open on the reviewed head.

## Scope and environment

| Tree | Exact commit |
| --- | --- |
| 8-1-stable | `aab611acd84b4754e2403a9ab005532ccb0ed374` |
| Parent of the owner-condition configuration merge | `f0c9373b05dd151fce6a28ba30d7cc8b376ea35e` |
| That merge | `ff53633d52d7f429d08a6250693cd74a0090c24c` |
| Requested main | `e30c36266b48016e74422e987dd46e85cacbeea8` |
| Reviewed head | `80daecf52a16cee2383b78d036e0126535598044` |

The head is fix `9877a852dd29208d4c15c04d6dea01506fc74982` (+17/−10, two library files) plus the +57-line test
commit. The test commit changes no library code. The two library files are also unchanged between census main
`4500a94c34` and the requested main. These are full-history checkouts fetched from the fork and canonical Rails,
not substituted methods or a patched installed gem. See [pins](raw/pins.txt), [commits](raw/commits.txt),
[diff](raw/candidate.diff), and [source identity](raw/source-identity.txt).

Ruby 4.0.9, SQLite 3.54.1 / sqlite3 2.10.2, PostgreSQL server 17.12 / pg 1.7.0 / libpq 18.0.6, minitest 6.1.0.
Dependencies came from the existing orb gem cache; Rails itself came from each selected tree. PostgreSQL databases
were newly created, disposable local test databases, never application databases. No MySQL, new timing benchmark,
Ruby master, YJIT-flat cohort or ZJIT run was performed.

## The claimed original regression is reproduced

[`run_matrix.sh`](run_matrix.sh) reruns the existing follow-up scripts without truncating their output. Both
earlier repros and the join-width controls ran at 16 and 17; `range_paths` ran at 17. Both settings were exercised,
with 8.1's missing setting left alone. There are ten [matrix receipts](raw/), one per tree and adapter. After their SHA/version headers, all output
is byte-identical within each group: **8.1 = parent = head**, and **merge = main**, separately on each adapter.

| Probe | 8.1 / parent / head | Merge / main |
| --- | --- | --- |
| Earlier scoped composite-key serialization, width 17 | record `[2]` | record `[1]` |
| Earlier scalar-key polymorphic join, width 17 | `k0=101` | `k0=1` |
| Both earlier repros at width 16 | same answer | same answer |
| Two-predicate `linear_join.rb` | `ParentX` | `Parent` |
| Built-in integer `2**70`, 17 target-default predicates, plain and polymorphic joins | no rows, SQL `1=0` | `ActiveModel::RangeError` |
| Same range joins at width 16 | no rows, SQL `1=0` | same |
| Range `eager_load` and `includes.references`, without a child-rejecting filter | **one parent, zero children** | `ActiveModel::RangeError` |
| Range reader and preload | `ActiveModel::RangeError` | same |
| Original `scoped_join.rb` control | `k0=1` | same |

The merge's first parent is exactly `f0c9373b05`. The history and executions establish the introduction point for
**these probes**, not for every possible serialization difference from 8.1. The built-in integer repro does not
need a custom serializer, comparison override or composite key. The two-predicate repro refutes a size-only
unconditional skip that promises exact behavior against main. It does not prove that no restricted safe subset
could ever be defined; that stronger impossibility claim should not be made.

**Receipt correction:** follow-up README's `range_paths` table says eager loading returns `[]`. Its own raw files,
and this rerun, say `[flag, :eager_load, 1, 0]` and `[flag, :includes_refs, 1, 0]`. Those are outer joins retaining
the parent. Empty parents require an inner join or the extra child-rejecting condition used by the added test.

## P2: the changed scoped path still has a third serialization order

Location: `activerecord/lib/active_record/associations/association_scope.rb:163–166`.

[`scoped_hash_phase.rb`](scoped_hash_phase.rb) uses a custom integer type with a stable `hash` result (`super`),
whose hash invocation increments a counter, and a string serializer reading that counter. The association scope
resets the counter before adding its label condition. Predicate equality and the integer's serialized values are
unchanged. Moving the three initial differences after that reset changes the label bind and selects a different
real row. This is deliberately effectful user code, not a claim that ordinary integer hashing changes SQL.

The raw `scoped-hash-*` receipts retain SQL and selected IDs for all five trees, both settings and adapters,
including the width-16 control. At width 17, 8.1 selects `chosen43` / record `[44]`, parent/merge/main select
`chosen34` / `[35]`, and the head selects **`chosen68` / `[69]`**. At width 16 all select `chosen25` / `[26]`.
**At width 17 the head is neither main nor 8.1.** The old fixed-value offset repro
does not cover this: moving the same hash calls across a scope callback is itself observable even when another
operation already memoized the integer binds. Thus the scoped relocation is a separate semantic change, not
established as a restoration merely because the original scoped repro agrees with 8.1.

**Must fix:** separate or correct the scoped relocation and add a regression for this boundary before describing
it as restored 8.1 behavior. Keeping eager differences on scoped builds is the smallest way to avoid introducing
this new scoped order; it also means the existing scoped regression test belongs with a separately completed
serialization fix. Do not add a predicate-count guard: the linear repro already defeats that rationale.

## P2: skipping reader checks does not generally restore 8.1 either

Location: `association_scope.rb:163–167`, where an unscoped build now omits the checks entirely.

[`scoped_extension.rb`](scoped_extension.rb) combines an ordinary association extension's `extended` hook with
the offset integer serializer, and records both hook and serialization events. At width 17, the plain association
with **no association scope** selects record `[3]` on 8.1, `[2]` on the parent/merge/main, and **`[4]` on the head**.
This reproduces on both adapters and under both settings. It is a third result, not a restoration. On the head
the first key serializes after the third extension hook, whereas 8.1 serializes after the second. The extra hook
already exists in the parent; it was not introduced by A1. **The changed selected record on the head is introduced
by A1's skip interacting with that pre-existing difference.** Width 16 already exhibits the pre-existing hook
count difference, and is not falsely reported as a new A1 defect.

The same script's scoped-through case also differs from 8.1 (record `[1]` there, `[2]` on parent/main/head at width
17). That difference predates A1; it is a limit on the restoration claim, not a newly introduced finding.

**Must fix:** address/test the remaining hook boundary or narrow this proposal to the demonstrated unscoped
`join_scope` fix, which does not run this reader extension sequence. Reframing the whole reader optimization as a
rollback does not by itself justify a result seen in neither released Rails nor the pre-merge tree.

## Other scoped limits, without false attribution

[`scoped_join_removed.rb`](scoped_join_removed.rb) uses only built-in integers. A 17-condition target default
scope contains the out-of-range value, but the association scope removes those conditions with `unscope(:where)`.
8.1 and the merge parent join the existing child and return parent `[1]`; merge/main/head raise before the scope
can discard the bad default condition. Width 16 returns `[1]` on all five trees. Both settings and adapters agree.
This is an unfixed regression of the merge, **not introduced by A1**, since scoped `join_scope` is unchanged.

The other retained probes are controls, not additional blockers:

* `scoped_late_serialization.rb`: changing the offset after `association.scope` returns does **not** automatically
  distinguish 8.1 from the head. At width 17, 8.1 already memoizes through relation merging (`WhereClause#merge` /
  `Array#|`), giving `[2]` on the simple scoped case on both. The test commit's “when the query is built” title is
  therefore too broad. There is no general promise that a bind remains unserialized until SQL compilation.
* `scoped_range.rb`: a wide out-of-range owner key raises on 8.1 as well as main/head. Do not misattribute that
  existing reader limitation to the new comparison code.
* `scoped_default_order.rb` and `scoped_removed_bind.rb` retain additional default-scope, removed-key and serializer
  controls, including both settings. Passing finite controls do not negate the two demonstrated third answers.

## Tests: genuine red/green, but strengthen the range test

The exact added class was extracted without changing its contents, prefixed only with `require "cases/helper"`,
and run using each tree's libraries and test helpers. Every adapter/tree/setting has a separate `targeted-*`
receipt. On 8.1 there is no setting; both invocations intentionally leave it alone.

| Adapter | Main, each setting | Head, each setting | 8.1, each invocation |
| --- | --- | --- | --- |
| SQLite | 2 tests, 1 failure / 1 error | 2 tests / 5 assertions, pass | 2 tests / 5 assertions, pass |
| PostgreSQL | 2 tests, 1 failure / 1 error | 2 tests / 5 assertions, pass | 2 tests / 5 assertions, pass |

The failures are the expected range exception and `[1]` rather than `[2]`. The tests are reasonably compact:
anonymous classes match existing has-many tests, private tables avoid fixture schema churn, nontransactional DDL
is appropriately isolated with teardown, and 17 columns intentionally reach the observed Ruby array boundary.
The one added threshold comment explains otherwise surprising test data; it is not a gratuitous implementation
narration. The file was already well above 1,000 lines before this change. There is no useful new helper or model
abstraction to extract from these two tests.

**Must fix at `has_many_associations_test.rb:3745–3748`:** create a child associated with the parent. Currently
the child table is empty, so removing the entire default scope still passes both empty-result assertions. I ran
that mutation: **2 tests / 5 assertions still pass** ([receipt](raw/targeted-no-filter-control.txt)). With just
`owner = parent.create!; child.unscoped.create!(parent_id: owner.id)`, the real head still passes, and the same
no-filter mutation fails ([seeded real](raw/targeted-seeded_serialization-control.txt),
[seeded mutation](raw/targeted-seeded_no_filter-control.txt)). This is a two-line strengthening, not a request for
a larger fixture matrix. The scoped test's two asymmetric child rows already discriminate the wrong result.

The eager-load assertion adds `where.not(children: { id: nil })`, so its empty result is not a demonstration that
an unrestricted eager load drops parents. `assert_empty` exercises relation `empty?`/`exists?`; it is not a full
loaded-record or preload assertion. That is acceptable for this exception regression, but describe its coverage
accurately. The class defaults to the new setting in the full suite; the isolated runs above exercise both.

## Full requested head suites, with warnings enabled

| Adapter | Runs | Assertions | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| SQLite | 3,272 | 10,742 | 0 | 0 | 1 |
| PostgreSQL | 3,277 | 10,755 | 0 | 0 | 0 |

Full logs: [SQLite](raw/tests-head-sqlite3.txt), [PostgreSQL](raw/tests-head-postgresql.txt). Both exit 0.
The SQLite skip is `ActiveRecord::WhereTest#test_with_tuple_syntax_and_large_values_list`, explicitly skipped for
SQLite's expression-tree limit; a [verbose isolated run](raw/sqlite-skip.txt) confirms its identity.

From the head's `activerecord` directory:

```sh
ARCONN=sqlite3 ruby -w -I../railties/lib -I../activesupport/lib -I../activemodel/lib -Ilib -Itest \
  -e 'ARGV.each { |f| require File.expand_path(f) }' \
  test/cases/associations/*_test.rb test/cases/associations_test.rb \
  test/cases/reflection_test.rb test/cases/relation_test.rb test/cases/relations_test.rb \
  test/cases/relation/*_test.rb test/cases/scoping/*_test.rb
```

Repeat with `ARCONN=postgresql`. These globs cover every test file under the requested association/relation/scoping
directories; there are no nested association test files in this tree. An initial harness attempt passed an
unmatched nested glob literally to `require` and exited before tests. Removing that nonexistent path fixed the
harness; no actual test was excluded. PostgreSQL's default test databases were created locally before the suite.

## Messages, body, note, numbers and CHANGELOG

The [sentence-by-sentence audit](claims-audit.md) covers both commit messages, every body sentence and table row,
and the proposed note. [`audit_numbers.py`](audit_numbers.py) reconstructs all 36 instruction cells from 72 raw
Callgrind windows and checks all 36 raw object cells, means, deltas and A/A values; [output](raw/numbers-audit.txt).
The performance numbers are arithmetically correct. They do not belong in the body of a correctness PR under
DECISIONS. The note's cost paragraph is unsolicited numerical commentary on somebody else's change and must be
removed, not left as an optional policy waiver. No new speed measurement was done here.

The current body contains no YJIT claim; frontmatter labels those old observations diagnostic, correctly. Its
scoped +0.2786% instruction count versus 0.0960% A/A is not unchanged, and the record now says so. The body cohort
has no JIT-flat counters, so those observations cannot be promoted to a speed claim. Scope allocations are equal
only in the measured fixture, not a universal allocation contract.

**CHANGELOG judgment:** this fixes an unreleased regression and adds no feature/deprecation. The actual
contributor guide at `guides/source/contributing_to_ruby_on_rails.md:283,614–618` explicitly says a bug fix need not
have an entry and minor fixes generally should not. Thus there is no release-note necessity under the documented
contributor convention. `AGENTS.md` instead explicitly asks agents for an entry for bugs too. For an agent-authored
revision, follow that stricter instruction with one short entry unless the user grants an exception. This is an
instruction-compliance must-fix, not a claim that Rails' public contributor convention requires release notes for
every unreleased regression. Do not claim that the two repository instructions agree.

## Reproduction and limits

With Ruby 4.0.9 and its dependencies available, and disposable PostgreSQL databases `a1_review_probe` and
`a1_review_scoped` created, from Lowrail's root:

```sh
bash bench/upstream/a1/review-thermos-sol-80daecf52a/run_matrix.sh \
  81=/path/to/8-1-stable pre=/path/to/parent merge=/path/to/merge main=/path/to/main head=/path/to/head
bash bench/upstream/a1/review-thermos-sol-80daecf52a/run_scoped.sh \
  81=/path/to/8-1-stable pre=/path/to/parent merge=/path/to/merge main=/path/to/main rails=/path/to/head
python3 bench/upstream/a1/review-thermos-sol-80daecf52a/audit_numbers.py
```

These probes replace their own named tables. Never point them at a non-disposable database. New probe receipt
filenames use `rails` for the head; the original matrix uses `head`. The record includes synthetic adversarial
types to expose call timing, not evidence that every app's ordinary associations exhibit these failures.
No security exploit was found. The direct local implementation is readable and the scope guard has a coherent
role; the blockers are semantics, test discrimination and publication claims, not abstraction or file size.
