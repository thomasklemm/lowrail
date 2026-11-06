# Rails string-condition parentheses: history and differential

Research for [rails/rails#59642](https://github.com/rails/rails/pull/59642), answering
[matthewd's question](https://github.com/rails/rails/pull/59642#discussion_r4490568172).
2026-11-06. Nothing from this record or the draft below was posted as a PR comment.

## Answer

Grouping is necessary: a caller's top-level `OR` must not escape a later `AND`,
including association and STI constraints. But there are two different literal
types. `WhereClause` groups `SqlLiteral`/String, **not `BoundSqlLiteral`**. Since
Rails 7.2, the bound-literal constructors have supplied their own parentheses.

[#58427](https://github.com/rails/rails/pull/58427) moved those parentheses ahead
of placeholder dispatch. That also wrapped the sanitizer fallback for the first
time. Empty string was the first app failure noticed, not the only change.
Ordinary strings with unused values, sprintf conditions, already-parenthesized
conditions, whitespace and comments all get another pair. Predicate equality and
deduplication change too. Blank strings also start converting unused values.

**Implemented recommendation:** retain shared dispatch, but request wrapping only
when it constructs a bound literal. Pass original fallback text to `sanitize_sql`.
This restores the old SQL and node representation without parsing SQL, changing
explicit Arel nodes, or undoing the bind-parameter change for full statements.

Fork head: [`805ab062624df73231d665c0fcf0131ec36d9ee0`](https://github.com/thomasklemm/rails/commit/805ab062624df73231d665c0fcf0131ec36d9ee0),
force-pushed with an explicit lease on `41b234e19c7c2690b70098e054d21b39896fba82`.
It drops the CHANGELOG entry (#58427 is unreleased, on main only) and rewraps
and retitles the commit; runtime and test sources are byte-identical to
`41b234e19c`. Earlier candidates were `7819d582f4a9f90297a428cd7162509a0ed9acf5`,
`0bf8c93b00e15fe03b60ed6cc6e9b1cd5e070f94` and
`58a6ff8355ff6b905c6aeae2ea939466f464b4fa`. Author and committer are both
Thomas Klemm <github@tklemm.eu>; no trailers. The PR's title/body were not edited:
the replacement title and body are in the [CW1 queue item](../../bench/upstream/pr-queue/items/CW1.md),
and the final reply is below. Nothing has been posted.

## Archaeology and sources

A fresh `rails/rails` clone had all commit history (`--is-shallow-repository` was
`false`); blobs were fetched on demand. This was git archaeology, not a changelog
search alone. Relevant commands included:

```sh
git log -S'"(#{' -- activerecord/lib/active_record/relation/query_methods.rb
git log -S'Grouping' -- activerecord/lib/active_record/relation/query_methods.rb
git log -S'Grouping' -- activerecord/lib/active_record/relation/where_clause.rb
git log -G'condition.*\)|\).*condition' --before=2005-10-19 -- activerecord/lib/active_record/base.rb
git log -L :merge_conditions:activerecord/lib/active_record/base.rb 1fb78e3ed8^
git log -L :merge_conditions:activerecord/lib/active_record/base.rb e328bdaab6^
git log -L :build_where:activerecord/lib/active_record/relation/query_methods.rb 00693209ec^
git log -L :collapse_wheres:activerecord/lib/active_record/relation/query_methods.rb a5fcdae0a0^
git log -L :predicates_with_wrapped_sql_literals:activerecord/lib/active_record/relation/where_clause.rb 1e235cee11
git blame -L 197,213 1e235cee11 -- activerecord/lib/active_record/relation/where_clause.rb
```

The table records the relevant placement/type changes, not whitespace-only edits
or every change elsewhere in Arel. Reasons below come from the corresponding
commit, tests, or linked discussion. A dash in the PR column means a direct
commit is the source; GitHub returned no associated PR for the important 2015
and 2017 commits. Old ticket numbers are not present-day GitHub PR numbers.

| Date | Commit / PR | Change and verified reason |
| --- | --- | --- |
| 2004-11-24 | [`db045dbbf60b53dbe013ef25554fd013baf88134`](https://github.com/rails/rails/commit/db045dbbf60b53dbe013ef25554fd013baf88134), initial import | `add_conditions!` does **not** wrap user conditions. `type_condition` already wraps its own generated STI disjunction; that is not the user-fragment wrapper being traced here. |
| 2005-09-24 | [`2a35baa0bb4312d95e1340074cce731afedecde0`](https://github.com/rails/rails/commit/2a35baa0bb4312d95e1340074cce731afedecde0), old ticket #1871, no GitHub PR | First explicit fix found for wrapping user `:conditions`: puts parentheses around extra conditions in `find` and `has_many#find`. Message: “to prevent problems with OR's”; added eager-association test checks that another author's posts do not leak in. |
| 2005-10-18 | [`328ef3feaad4c110a7277e3432e9203c7fbbb9e2`](https://github.com/rails/rails/commit/328ef3feaad4c110a7277e3432e9203c7fbbb9e2), — | Generalizes to `add_conditions!` and association paths. Changelog: “Always parenthesize :conditions options so they may be safely combined with STI and constraints.” Builds `WHERE (a) AND (b)`. |
| 2008-03-23 | [`0ff031992f1dc36cf36eaf26a1e476f67c29c048`](https://github.com/rails/rails/commit/0ff031992f1dc36cf36eaf26a1e476f67c29c048), old ticket #10764, — | Extracts `merge_conditions` from condition/scoping construction. Sanitizes, rejects blank segments, then wraps the survivors. Fixes merging blank conditions; tests explicitly include `["", {}]` in nested scopes. This is a sanitation-and-merging helper, not `sanitize_sql` itself adding parentheses. |
| 2008-06-17 | [`e328bdaab6c1cf920af3cabc0a27e32798a9fcb6`](https://github.com/rails/rails/commit/e328bdaab6c1cf920af3cabc0a27e32798a9fcb6), — | Moves `merge_conditions` to public visibility; same sanitizer-then-parenthesize body. |
| 2010-01-20 | [`1fb78e3ed8142782f19877a195f10b1828dd672c`](https://github.com/rails/rails/commit/1fb78e3ed8142782f19877a195f10b1828dd672c), — | Deletes `Base.merge_conditions` as no longer needed; relation `build_where` now directly sanitizes and builds `SqlLiteral("(#{sql})")` for present SQL. |
| 2010-01-21 | [`da142cd86584d56299470ee4dd6f90be7127b477`](https://github.com/rails/rails/commit/da142cd86584d56299470ee4dd6f90be7127b477), — | Moves wrapping from `build_where` to `build_arel`; existing `SqlLiteral`s pass through. Commit's reason: “Supplying Arel::SqlLiteral is much faster.” |
| 2010-07-28 | [`1c030a3c3c61d6d6262785bf67e1d8f44da87ea5`](https://github.com/rails/rails/commit/1c030a3c3c61d6d6262785bf67e1d8f44da87ea5), then [`d69949ed0d63ba19051a24cba992bd4655d0f5be`](https://github.com/rails/rails/commit/d69949ed0d63ba19051a24cba992bd4655d0f5be), — | Briefly changes `build_arel` dispatch to avoid calling `to_sql` twice; reverted minutes later (“Shouldn't have committed this!”). No lasting move. |
| 2010-09-28 | [`8d9f7b5b9987cccd392442b92c3945fc20a12fff`](https://github.com/rails/rails/commit/8d9f7b5b9987cccd392442b92c3945fc20a12fff), then [`dec3a759d189c3acb812bef3aebcc5a2e061c28a`](https://github.com/rails/rails/commit/dec3a759d189c3acb812bef3aebcc5a2e061c28a), — | Simplifies String/SqlLiteral handling, then replaces textual wrapping in `build_arel` with `Grouping.new(where)`, converting plain strings with `Arel.sql`. Messages describe removing redundant conditionals/code. |
| 2010-11-17 | [`00693209ecc222842949d7cab076f89890cbd507`](https://github.com/rails/rails/commit/00693209ecc222842949d7cab076f89890cbd507), old ticket #4598, — | Moves grouping into `collapse_wheres`; non-equality predicates retain `Grouping`. Goal: collapse same-table/column equality conditions into ORs. |
| 2013-08-24 | [`fbbb6c87fd5e8fcd913c0dbf518024edd7538072`](https://github.com/rails/rails/commit/fbbb6c87fd5e8fcd913c0dbf518024edd7538072), [#12011](https://github.com/rails/rails/pull/12011), fixes [#11963](https://github.com/rails/rails/issues/11963) | Keeps the grouping but collapses all where predicates under one `And`; fixes association-join conditions being joined by commas rather than `AND`. PR explanation and result-based regression tests confirm the reason. |
| 2015-01-27 | [`a5fcdae0a04d97dbd8fd05af6f352d3e09b2815f`](https://github.com/rails/rails/commit/a5fcdae0a04d97dbd8fd05af6f352d3e09b2815f), — | “Move where grouping into `WhereClause`.” Removes `collapse_wheres`; introduces `predicates_with_wrapped_sql_literals` and `non_empty_predicates`. Added tests assert grouping and exact-empty-string removal. |
| 2015-01-27 | [`c2c95cd279c988e7bd94008264e956e30b78c9ec`](https://github.com/rails/rails/commit/c2c95cd279c988e7bd94008264e956e30b78c9ec), — | “Use the `WhereClause` ast building logic for having”; `having_clause.ast` now shares the same grouping path. |
| 2017-07-24 | [`213796fb4936dce1da2f0c097a054e1af5c25c2c`](https://github.com/rails/rails/commit/213796fb4936dce1da2f0c097a054e1af5c25c2c), — | Refactors bind values onto Arel's AST to avoid separate bind-list bookkeeping. Narrows automatic `WhereClause` grouping to `SqlLiteral` and String instead of all non-equality nodes. |
| 2020-04-25 | [`699b64ab6322a549a84c7d116fe18cbb522ce64f`](https://github.com/rails/rails/commit/699b64ab6322a549a84c7d116fe18cbb522ce64f), [#39046](https://github.com/rails/rails/pull/39046) | Avoids a redundant `And` around a single predicate, retaining literal grouping. Commit/PR state AST traversal performance as the reason. |
| 2020-04-26 | [`7d3bff1fdb79dd2c71017804a3f396dc7fe2c9da`](https://github.com/rails/rails/commit/7d3bff1fdb79dd2c71017804a3f396dc7fe2c9da), [#39051](https://github.com/rails/rails/pull/39051) | `WhereClause#or` unwraps outer `Grouping`s and supplies one around the combined OR. Flattens OR ASTs to avoid stack overflow. [matthewd's review](https://github.com/rails/rails/pull/39051#discussion_r415138574) explicitly checks safety from OR's lower precedence than AND. |
| 2024-02-20 | [`8e6a5deca626c944933211d7977f4e7e76869e74`](https://github.com/rails/rails/commit/8e6a5deca626c944933211d7977f4e7e76869e74), [#51139](https://github.com/rails/rails/pull/51139) | Builds `BoundSqlLiteral` for named/positional placeholders instead of eager interpolation, avoiding connection checkout during relation construction and allowing statement reuse. New bound constructors put textual parentheses around the fragment; sanitizer fallback stays unwrapped. No separate wrapping rationale is stated, but the changed SQL assertions retain one pair around bound expressions. |
| 2025-04-20 | [`a2928dd9d987ce76609811904c4e3cb18abace9e`](https://github.com/rails/rails/commit/a2928dd9d987ce76609811904c4e3cb18abace9e), [#54951](https://github.com/rails/rails/pull/54951) | Stops re-wrapping existing `SqlLiteral`s via `Arel.sql`, preserving `retryable`; keeps AST `Grouping`. The PR's “wrapped” also refers to object conversion, not just parentheses. |
| 2026-08-09 | [`8c4ed25f0aa80f6067a358731fd5782be3817952`](https://github.com/rails/rails/commit/8c4ed25f0aa80f6067a358731fd5782be3817952), [#58427](https://github.com/rails/rails/pull/58427) | Extracts common dispatch to `Sanitization#bound_sql_literal_for` and uses it for array-form find/count-by-SQL. Moves textual parentheses into `build_where_clause` **before** dispatch, unintentionally extending them to sanitizer fallback strings. |
| 2026-11-02 | [`54c9eeb510e2d98c7bc8f00919cdf5600631f022`](https://github.com/rails/rails/commit/54c9eeb510e2d98c7bc8f00919cdf5600631f022), [#59533](https://github.com/rails/rails/pull/59533) | Fuses empty-string filtering and literal wrapping into one pass to remove an Array allocation; same predicate comparison, ordering and grouping. |
| 2026-11-03 | [`f903005e4902c0c989c52946ac2893aba579c038`](https://github.com/rails/rails/commit/f903005e4902c0c989c52946ac2893aba579c038), [#59576](https://github.com/rails/rails/pull/59576) | Adds a single-predicate fast path and extracts `wrap_sql_literal` again; same String/SqlLiteral-only rule. This is why current blame lands on recent optimization commits rather than the original grouping move. |

The November 2026 commits are not the cause: the differential below gives exactly the same
old/new differences across #58427 itself as between 8-1-stable and pinned main.

### What #58427 actually needs

The PR body and its single commit say: array-form `find_by_sql` and `count_by_sql`
were eagerly interpolating despite the documented parity with `where`; dispatch
should be shared and placeholder values should become binds. At inspection it
had **zero issue comments, zero review comments, and zero submitted reviews**.
There is no discussion claiming that fallback condition SQL should gain parens.

Its three tests check that positional/named find-by-SQL and positional
count-by-SQL send `Mary` in the query payload's `binds` and do not interpolate
`'Mary'` into SQL. Those are full SELECT statements and must remain unwrapped.
None asserts an additional pair for sanitizer fallback conditions. The revised
patch keeps all three passing and leaves `_sql_for_find` unchanged.

[#51139's discussion](https://github.com/rails/rails/pull/51139#issuecomment-1956264462)
explicitly left `%` interpolation with `sanitize_sql`; matthewd's earlier
[comment](https://github.com/rails/rails/pull/51139#issuecomment-1954453661) described
moving internals to compilation while retaining sanitize as existing public API.
[#54951's discussion](https://github.com/rails/rails/pull/54951#discussion_r2060026459)
distinguishes passing through literal objects from passing through all Arel nodes.
Neither is a decision to change which raw fragments get extra textual grouping.

## Differential

Pinned checkouts (the requested main pin is used rather than today's moving tip):

| Label | SHA |
| --- | --- |
| 8-1-stable | `6e091242176c322edc5a8907583c01b08b8a60bc` |
| main | `1e235cee11b0a7aecb189d8837534807626287aa` |
| immediately before #58427 | `ea29a755f0252d9ce38656b206c85e2d157f6bac` |
| #58427 | `8c4ed25f0aa80f6067a358731fd5782be3817952` |
| revised fork | `7819d582f4a9f90297a428cd7162509a0ed9acf5` |

Ruby 4.0.7 (`229531a6cf`), sqlite3 gem 2.10.1, SQLite 3.54.1, in-memory DB,
prepared statements enabled. Three rows: `(n, name)` = `(1, one)`, `(2, two)`,
`(3, three)`. Each case captures `to_sql`, executed result values sorted by `n`
or exception class/first message line, plus where/having clause emptiness.
It does not swallow failures as successes. Both construction-time and
execution-time errors are recorded, separately.

**44 inputs × 2 forms × 16 compositions = 1,408 cases per checkout.**
Forms are `where(string, values)` and `where([string, values])`, with equivalent
forms for having/not. The script below defines every input and composition.

| Comparison | Differing cases |
| --- | ---: |
| 8-1-stable vs main | **683 / 1,408** |
| parent of #58427 vs #58427 | **683 / 1,408**, same identities and outputs as above |
| 8-1-stable vs parent of #58427 | **0 / 1,408** |
| main vs #58427 | **0 / 1,408** |
| 8-1-stable vs revised fork | **0 / 1,408** |

This is a finite differential, not a claim that all possible SQL has been parsed
or all adapters tested. The exact differing cases and their output pairs are in
the generated appendix; identical output pairs are grouped without normalizing
SQL. All 725 remaining cases are identical, including named/positional binds and
explicit Arel nodes (except `SqlLiteral` with extra values, which follows String
dispatch and therefore changes too).

### What differs

* **Fallback strings acquire an extra textual pair before AST grouping.** E.g.
  `where("n = 1", {})`: `WHERE (n = 1)` becomes `WHERE ((n = 1))`.
  `where("(n = 1)", {})` gains a third pair. `%s` formatting does too.
  The successful nonempty examples return the same rows; the SQL is not the same.
* **Deduplication changes.** For `x = "n = 1 OR n = 3"`,
  `Item.where(x, {}).merge(Item.where(x))` was `WHERE (n = 1 OR n = 3)`;
  main emits `WHERE ((n = 1 OR n = 3)) AND (n = 1 OR n = 3)`.
  Replacing `merge` with `or` was the same single predicate; main emits
  `WHERE ((n = 1 OR n = 3) OR n = 1 OR n = 3)`. Both still return `[1, 3]`.
* **Exact-empty chained conditions regress from rows to SQL errors.** E.g.
  `Item.where(n: [2, 3]).where("", {})` was
  `SELECT "items".* FROM "items" WHERE "items"."n" IN (2, 3)` → `[2, 3]`;
  main adds `AND (())` → SQLite syntax error. Array form, unused named and
  positional values, merge and reverse order are covered. The matrix has 52
  previously successful executions whose outcomes change (including the
  intentionally raising unused object); all are empty-fragment cases.
* **Whitespace/comment-only fragments are not newly invalid.** With values,
  `" "`, `" \t\n"`, `"-- x"`, `"-- x\n"`, `"/* x */"` already produce invalid
  SQL on 8.1. Their SQL gains parens and some error messages change. A trailing
  `-- x` without newline already swallows the closing paren and fails; adding
  a newline or using a trailing block comment works, with extra SQL parens on main.
* **Blank statements start touching unused objects.** For a value whose `to_s`
  raises, `where(" ", value)` used to construct SQL (failing only at execution);
  main raises during construction. Wrapping defeats `sanitize_sql_array`'s
  `statement.blank?` early return. `where("", value)` similarly stops ignoring it.
* **True placeholder paths are unchanged.** Named/positional binds, top-level OR,
  already-parenthesized bound strings, trailing comments, and placeholders inside
  comments all match exactly in this corpus. The last category deliberately
  records existing placeholder dispatch, not SQL-aware comment parsing.
* **Having's blank short circuit matters.** `having("", {})` and `having(" ", {})`
  are already no-ops before `build_having_clause`, while the array forms reach
  it and differ. Nonblank having conditions share where's extra-wrapper change.

### Correcting the earlier reply to skipkayhil

[Our earlier comment](https://github.com/rails/rails/pull/59642#discussion_r4488047157)
was too broad. `where("")` short-circuits and has an empty clause;
`where("", {})`/`where(["", {}])` do not. On 8.1 the latter have a nonempty
predicate list containing an empty literal. It is removed during AST building,
but standalone `to_sql` still emits `SELECT "items".* FROM "items" WHERE ` and
execution fails. `where.not("", {})` emits `NOT ()`; OR with a different predicate
can also be invalid. This fix deliberately preserves those historical results.

Thus `parts = []` is **not** an equivalent compatibility fix: it would change the
standalone query, clause emptiness, OR behavior and empty negation. Even our earlier
statement that it gives “the same query” needs the chained-AND qualification.

## Alternatives and decision

| Option | Benefit | Cost / reason not selected |
| --- | --- | --- |
| Keep the original `opts.empty?` exception | One-line app regression fix | Leaves doubled SQL, changed deduplication and whitespace unused-value conversion; treats one symptom. |
| Drop `"(#{opts})"` entirely | Smallest edit, fixes fallback | Removes the only grouping for string-created bound literals. With `"n = ? OR n = ?", 1, 3` and a subsequent `where(n: [2, 3])`, ungrouped precedence admits `1`; historical result is `[3]`. |
| Move all literal grouping to `WhereClause`, including `BoundSqlLiteral` | One conceptual grouping layer | Changes explicit caller-supplied BoundSqlLiteral semantics and changes AST/node equality relative to historical bound strings. `WhereClause#or` unwraps Grouping; merge/dedup and direct-node equivalence need a larger compatibility decision. |
| Reintroduce pre-#58427 dispatch in `build_where_clause` | Can restore exact old behavior | Duplicates the shared named/positional/fallback dispatch, giving up part of #58427's stated consolidation. |
| Return a bound node and wrap it as `Grouping` in `build_where_clause` | Keeps dispatch shared, fixes fallback | Changes the node representation and equality with an explicitly supplied `Arel.sql("(n = ?)", 1)`; SQL/dedup behavior is no longer exactly historical. |
| **Add `wrap: false` to shared helper; where/having pass `true`** | **Keeps shared dispatch and exact old bound representation, sanitizes original fallback text, leaves full statements unwrapped** | **Small internal helper option and two constructor-site conditional interpolations. Selected.** |
| Normalize all blank/comment-only conditions to `[]` | More consistently treats “nothing” as no filter | Intentionally changes historical invalid cases, NOT and OR; comment recognition would need SQL parsing. Separate policy question, not necessary for this regression. |

The selected patch changes only the grouping placement, not the sanitizer or
placeholder grammar. Its keyword cannot capture SQL's own `:wrap` bind: SQL
values are passed separately as the positional `values` array/hash.

## Verification and independent review

On the final candidate, with `GEM_HOME`/`GEM_PATH` pointing at Lowrail's retained
Ruby 4.0.7 gate gems and a component-only external Gemfile (AS/AM/AR/AP/AV/AJ/
Railties paths to this Rails checkout; minitest 6.0.6, minitest-mock, sqlite3
2.10.1, bcrypt, rake):

```sh
BUNDLE_GEMFILE=/tmp/where-tests.Gemfile PARALLEL_WORKERS=1 RAILS_STRICT_WARNINGS=1 \
  mise exec ruby@4.0.7 -- \
  ruby activerecord/bin/test activerecord/test/cases/relation \
    activerecord/test/cases/relation_test.rb activerecord/test/cases/relations_test.rb \
    activerecord/test/cases/sanitize_test.rb activerecord/test/cases/finder_test.rb \
    --seed 1729 --verbose
# 1332 runs, 3775 assertions, 0 failures, 0 errors, 4 skips
```

Skips: SQLite tuple-syntax/large-values-list, two load-async instrumentation
tests, and select-with-nonexistent-field. They explicitly skip in this adapter/
configuration. A separate focused run of where/sanitize/finder gave **386 runs,
1,018 assertions, 0 failures, 0 errors, 1 skip** and explicitly executed all three
`*_binds_the_value` tests from #58427. The differential intentionally includes
unused formatting values, which emit Ruby's existing “too many arguments for
format string” warnings. The retained regression tests use matching sprintf
values and pass with Rails' strict-warning policy enabled.

Both new regression tests were also run against **unmodified main sources**
using a component bundle whose paths pointed to `/tmp/rails-main`: **2 runs,
1 failure, 1 error** (doubled parentheses and empty-fragment SQL error). Same two
tests on the revised fork: **2 runs, 18 assertions, no failures/errors/skips**.
`git diff --check` passed. No complete multi-adapter Rails suite claim is made.

An independent read-only skeptical subagent reviewed exact head
`0bf8c93b00e15fe03b60ed6cc6e9b1cd5e070f94` against its parent
`7a78da5a5576d7ab7549b10fb13156788478ba35`: **no confirmed findings or blockers**.
It independently reran the initial 1,232-case matrix (595 main differences,
zero candidate/8.1 differences), checked boolean precedence and direct-bound-node
deduplication, and probed sync/async find/count binds and quote escaping. Its
focused suites gave **481 runs, 1,261 assertions, 0 failures, 0 errors, 1 skip**.
The extra literal-equivalence compositions bringing the matrix to 1,408 cases
were added afterward by the primary investigator; the reviewed code did not
change. Review limitations: SQLite only; async APIs did not exercise a genuinely
background executor; not the full Rails suite.

The same independent reviewer then read the complete final patch at
`7819d582f4a9f90297a428cd7162509a0ed9acf5` against the same parent:
**no confirmed findings or blockers**. It verified byte-identical runtime sources
relative to the previous candidate, reproduced the old extra-parentheses behavior
for all three revised sprintf fixtures, and judged that the fixture correction
leaves no material coverage gap. Its independent strict-warning run of where,
finder, merging, OR, where-clause and sanitize again gave **481 runs, 1,261
assertions, 0 failures, 0 errors, 1 skip**. It also confirmed the unused-format-value
warning with an intentionally caught negative control. It did not repeat the
larger suite or the differential on this test-only revision; the primary
investigator reran both on final head, as recorded above and below.

The first pushed candidate's [Buildkite build 136272](https://buildkite.com/rails/rails/builds/136272)
failed: the new fallback test supplied unused values to nonblank, placeholder-free
SQL, triggering Ruby's existing formatting warning. Rails' hosted strict-warning
policy turns that warning into an error. The
[SQLite 4.0 job](https://buildkite.com/rails/rails/builds/136272#01a1b01f-295c-4692-b0c6-9fc09d5bcc08)
reported **10,010 runs, 35,254 assertions, 0 failures, 1 error, 54 skips**;
the error was `test_where_with_sanitized_string_condition_and_values`.
The final head changes only those fixtures to matching sprintf strings/values;
runtime sources are unchanged. The full local command above was rerun with
`RAILS_STRICT_WARNINGS=1` and passed. The final head's differential was also rerun:
**0 / 1,408 differences from 8.1**.

The pushed head is not merged. [Final-head Buildkite build 136274](https://buildkite.com/rails/rails/builds/136274)
was still running when this section was prepared. An automatic exact-head CI subscription was created for the fork;
the Amp GitHub App cannot subscribe to `rails/rails`, so upstream checks are read
with the authenticated GitHub CLI. No workflow was manually triggered.

### Follow-up review nits

Sol and Astra's nits on `7819d582f4` were applied in
`41b234e19c7c2690b70098e054d21b39896fba82`, with no production-code change.
The sanitized-condition test's OR alternative is now `sink_id = 4`, not
`sink_id = 1`: fixtures have sink IDs 2–5, so the former exposes a missing
grouping. An executed negative control returned `[2, 4]` without grouping and
`[2]` with the corrected condition. The commit body now explains #58427's
fallback regression and preservation of full-statement binds.

On SQLite with `RAILS_STRICT_WARNINGS=1` and seed 1729:

* The two regression tests: **2 runs, 18 assertions, no failures/errors/skips**.
* `relation/where_test.rb`: **75 runs, 146 assertions, no failures/errors, 1 skip**.
* The entire relation directory: **617 runs, 1,522 assertions, no failures/errors,
  4 skips**.
* The same updated tests using the pinned main production sources: **2 runs,
  1 assertion, 1 failure, 1 error**; the SQL-shape assertion detects doubled
  parentheses and the chained empty condition raises a SQLite syntax error.

The earlier differential and independent reviews above cover `7819d582f4`, not
this new test/message-only head. Its production sources are unchanged. The new
two-paragraph PR body, with the original footer and Chatwoot permalinks, is only
in the CW1 queue item; no GitHub body edit or comment was made.

### Final review (Claude Code, 2026-11-06)

Verdict: **nits**, fixed in `805ab06262`. Code and tests unchanged.

* **History.** Every reply claim was checked against the commits in a full
  `rails/rails` clone. The parent of `2a35baa` wraps no user `:conditions`; the
  only earlier parentheses are around the generated `type_condition`. The
  movement order `0ff0319` → `1fb78e3` → `da142cd` → `dec3a75` → `0069320` →
  `a5fcdae` → `213796f` → #51139 (`8e6a5de`) → #58427 (`8c4ed25`) is correct, and
  PR/commit mappings were confirmed with `gh`.
* **Differential.** The runner above (same SHA-256) on Ruby 4.0.7/SQLite 3.54.1:
  head vs 8-1-stable 0 / 1,408; head merged into today's main (`cadf0fc8d6`,
  which now has `_where!`) vs 8-1-stable 0 / 1,408; base and main vs 8-1-stable
  683 / 1,408. A second, ad hoc runner added `rewhere`, `invert_where`,
  `where.not` with OR, STI, association scopes (lazy, eager, preload),
  association `where`, `?` inside quotes, named values without placeholders or
  with a quoted `:n`, named arrays and relations, having with bound/sprintf OR,
  direct Arel bound nodes merged with equivalent strings, `Grouping`, `where!`,
  and sync/async `find_by_sql`/`count_by_sql` with captured SQL and binds. Head
  removes the extra parentheses and `(())` failures in every case that differs
  from the base. Against 8.1 the only differences are #58427's intended binds
  (and quoting in one error message), plus `where!` with values, which is broken
  on the base and fixed on main by `e4852e04bb`; merged with main it matches 8.1.
* **Shape.** A `wrap:` keyword on the nodoc helper is the smallest option: a
  `BoundSqlLiteral` cannot be re-wrapped after construction without changing
  node equality, and dispatching in `build_where_clause` would undo #58427's
  consolidation.
* **Tests.** Both new tests fail on the base (1 failure, 1 error) and pass on
  head (2 runs, 18 assertions). Comparing `to_sql` against the equivalent plain
  string is the right assertion here: the regression is in SQL shape and
  deduplication, which results alone don't show, and the comparison stays
  adapter-neutral.
  With `RAILS_STRICT_WARNINGS=1`, seed 1729: SQLite relation, relation(s),
  sanitize, finder, associations, scoping, base and inheritance tests: head
  3,544 runs, 11,190 assertions, 0 failures/errors, 5 skips; merged into main
  3,550 runs, 11,209 assertions, 0 failures/errors, 5 skips. PostgreSQL 15.19
  relation, relation(s), sanitize, finder: head 1,363 runs, 3,908 assertions;
  merged 1,367 runs, 3,923 assertions; 0 failures/errors, 1 skip each.
* **Fixed.** Removed the CHANGELOG entry: #58427 is in no tag and not in
  8-1-stable, so no released user saw the regression (`e4852e04bb`, the
  `where!` regression fix, likewise had none). Rewrapped the commit body to 72
  columns and retitled the commit and PR from the old empty-only title.

## Reply to matthewd (superseded by the revised reply below, not posted)

As far as I can tell, they were first added in [2a35baa](https://github.com/rails/rails/commit/2a35baa0bb4312d95e1340074cce731afedecde0) (2005), to stop an OR in `:conditions` escaping an association constraint. [328ef3f](https://github.com/rails/rails/commit/328ef3feaad4c110a7277e3432e9203c7fbbb9e2) extended that to STI and scope conditions. The wrapping then moved through `merge_conditions`, `build_where`, `build_arel`, AST `Grouping` and `collapse_wheres`, and [into `WhereClause` in 2015](https://github.com/rails/rails/commit/a5fcdae0a04d97dbd8fd05af6f352d3e09b2815f). [A 2017 refactor](https://github.com/rails/rails/commit/213796fb4936dce1da2f0c097a054e1af5c25c2c) limited it to String/`SqlLiteral`. [#51139](https://github.com/rails/rails/pull/51139) added textual parentheses to the bound literals it builds from strings, and [#58427](https://github.com/rails/rails/pull/58427) moved them ahead of dispatch, so the sanitizer fallback got wrapped too. [Full timeline and reproducer](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/where-parens-history.md).

The grouping should stay, for AND/OR precedence, but only once: `WhereClause` groups `SqlLiteral`s, while string-built `BoundSqlLiteral`s carry their own parentheses. The fallback doesn't need a second pair.

Empty string was the failure I noticed, not the only change. Comparing with 8.1 also showed extra parentheses for ordinary and sprintf conditions with values, identical conditions no longer deduplicating on `merge` or `or`, and whitespace-only strings converting values they used to ignore. My earlier reply was also too broad: on 8.1 an empty condition with values already produced a dangling `WHERE` on its own; what worked was combining it with another condition.

I've revised the patch to pass the original text to the shared helper and add parentheses only to bound literals built for `where`/`having`. That keeps #58427's shared dispatch and its find/count-by-SQL binds. Moving all grouping into `WhereClause` would also work, but would change explicitly passed bound nodes and their equality/deduplication. Dropping empty predicates earlier would change OR/NOT behaviour. The revised head matches 8.1 in every case I compared on SQLite.

## Option B: one grouping layer (2026-11-06)

matthewd's "Should they exist at all?" may point at a single grouping layer, so
this section tests that structure against the minimal fix (`805ab06262`).

### Explicit bound nodes escape AND on 8.1 and main

Yes. `WhereClause` groups only String/`SqlLiteral`, so an explicitly passed
`BoundSqlLiteral` with a top-level `OR` is emitted bare. Every release since
`Arel.sql` accepted binds ([`6444ec0d30`](https://github.com/rails/rails/commit/6444ec0d30), 7.1.0) has this bug; it is not a
#58427 regression (re-verified on 7-1-stable, 7-2-stable and 8-0-stable). Data: ids 1–5 =
`(n, owner, type)` `(1,b,-)`, `(2,a,-)`, `(3,a,Special)`, `(3,b,-)`, `(1,b,Special)`;
`node = Arel.sql("n = ? OR n = ?", 1, 3)`. Output is identical on 8-1-stable
`6e09124217` and main `cadf0fc8d6`:

| Case | SQL (explicit node) | ids | Same via string `where("n = ? OR n = ?", 1, 3)` |
| --- | --- | --- | --- |
| `Item.where(node).where(n: [2, 3])` | `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` | [1, 3, 4, 5] | `WHERE (n = 1 OR n = 3) AND …` → [3, 4] |
| `Item.where(n: [1, 2]).where(node)` | `WHERE "items"."n" IN (1, 2) AND n = 1 OR n = 3` | [1, 3, 4, 5] | [1, 5] |
| `Item.where(n: [1, 2]).merge(Item.where(node))` | `WHERE "items"."n" IN (1, 2) AND n = 1 OR n = 3` | [1, 3, 4, 5] | [1, 5] |
| `Item.where(node).merge(Item.where(n: [2, 3]))` | `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` | [1, 3, 4, 5] | [3, 4] |
| `has_many … -> { where(node) }`, `a.items` | `WHERE "items"."owner_id" = 1 AND n = 1 OR n = 3` | [3, 4] | [3] |
| `a.items.where(node)` | `WHERE "items"."owner_id" = 1 AND n = 1 OR n = 3` | [3, 4] | [3] |
| `Special.where(node)` (STI) | `WHERE "items"."type" = 'Special' AND n = 1 OR n = 3` | [3, 4, 5] | [3, 5] |
| `Item.group(:id).having(node).having(n: [2, 3])` | `HAVING n = 1 OR n = 3 AND "items"."n" IN (2, 3)` | [1, 3, 4, 5] | [3, 4] |
| `Owner.joins(:items).where(items: { type: nil }).merge(Item.where(node))` | `WHERE "items"."type" IS NULL AND n = 1 OR n = 3` | owners [1, 2, 2] | [2, 2] |
| `Owner.eager_load(:node_scoped_items)` | `LEFT OUTER JOIN "items" ON "items"."owner_id" = "owners"."id" AND n = ? OR n = ?` | a's items [3, 4] | [3] |
| `Item.where(node).where(n: [2, 3]).invert_where` | `WHERE NOT (n = 1 OR n = 3 AND "items"."n" IN (2, 3))` | [2] | `NOT ((n = 1 OR n = 3) AND …)` → [1, 2, 5] |
| `Item.where.not(node).where(n: [1, 2])` | `WHERE NOT (n = 1 OR n = 3) AND "items"."n" IN (1, 2)` | [2] | same ids (`Not` supplies parens) |
| `Item.where(node).or(Item.where(n: 2)).where(owner_id: 1)` | `WHERE (n = 1 OR n = 3 OR "items"."n" = 2) AND …` | [2, 3] | same ids (`or` supplies parens) |

`where.not` and `or` are safe because `Not`/`Grouping(Or)` add parentheses.
Every other composition leaks rows.

### Prototype

Branch [`thomasklemm/where-group-bound-literals`](https://github.com/thomasklemm/rails/tree/thomasklemm/where-group-bound-literals),
head [`10346a258e1fd105de7561437ad7917ff3cb9b47`](https://github.com/thomasklemm/rails/commit/10346a258e1fd105de7561437ad7917ff3cb9b47)
on rails main `cadf0fc8d6`. One commit, author and committer Thomas Klemm
<github@tklemm.eu>, no trailers. **5 files, +48/−3; runtime 2 lines changed:**
(Replaces `f6a0268e9c`, which had an `Amp-Thread-ID` trailer added by Amp's
commit wrapper; same tree plus the CHANGELOG entry. See Review.)

```diff
--- a/activerecord/lib/active_record/relation/query_methods.rb
-            parts = [model.bound_sql_literal_for("(#{opts})", rest)]
+            parts = [model.bound_sql_literal_for(opts, rest)]
--- a/activerecord/lib/active_record/relation/where_clause.rb
-          when Arel::Nodes::SqlLiteral, ::String
+          when Arel::Nodes::SqlLiteral, Arel::Nodes::BoundSqlLiteral, ::String
```

Tests: the minimal fix's two tests (empty string with values; sanitized
conditions match plain-string SQL), plus `test_where_with_bound_sql_literal_is_grouped`.
The new test asserts an explicit node gives the same SQL as the string form and
returns `[4]`, not `[2, 4]`, after `where` and `merge`. `relation_test.rb`'s
"merging a hash interpolates conditions" expectation changes from
`Arel.sql("(foo = ?)", "bar")` to `Arel.sql("foo = ?", "bar")` (the node no
longer carries textual parens). CHANGELOG entry for the explicit-node fix, added in
the final review.

Blank bound literals: string-built empty/blank conditions with values never
become `BoundSqlLiteral` (no placeholder → sanitizer fallback → `SqlLiteral`), so
the existing `node.eql?("")` handling covers them. Only an explicit
`Arel.sql("", a: 1)` is affected: 8.1 renders `WHERE ` / `AND  `, B renders
`WHERE ()`; both are SQL errors (message changes from "incomplete input" to
`near ")"`). Skipping blank bound nodes would make an invalid explicit input
silently filter nothing, so it was left alone.

### Differential

Same runner (SHA-256 `6d4bd527…`), Ruby 4.0.7, SQLite 3.54.1:

| Comparison | 1,408-case runner | extended runner (325) |
| --- | ---: | ---: |
| 8-1-stable vs main | 683 | 0 |
| 8-1-stable vs minimal (`805ab06262` merged into main) | 0 | 0 |
| 8-1-stable vs option B | **204** | **173** |
| minimal vs option B | **204** | **173** |
| main vs option B | 887 | 173 |

B removes all 683 #58427 differences (zero overlap with them). Its 204 differences from 8.1:

* **12 result changes, all explicit-node precedence fixes:** `arel_bound` and
  `arel_bound_extra` × args/array × `and_after`, `merge_reverse`, `having_and`.
  E.g. `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` → [1, 3] becomes
  `WHERE (n = 1 OR n = 3) AND "items"."n" IN (2, 3)` → [3].
* **48 SQL-only, explicit nodes gain one pair** (`arel_bound`, `arel_bound_extra`,
  `arel_merge_equivalent` in where/and/merge/having). `Arel.sql("(n = ?)", 1)`
  now renders `((n = 1))`. Dedup changes: `Item.where(Arel.sql("(n = ?)", 1)).merge(Item.where("n = ?", 1))`
  was `WHERE (n = 1)` (string node `"(n = ?)"` equalled the explicit node), now
  `WHERE ((n = 1)) AND (n = 1)`. Conversely, a string-built `where("n = ?", 1)` now
  equals an explicit `Arel.sql("n = ?", 1)`, so those dedup where they did not.
* **144 SQL-only, string-built bound conditions under `not`/`or`:** the 12 placeholder
  inputs × args/array × `not`, `not_and`, `or`, `or_reverse`, `or_literal_equivalent`,
  `having_or`. `NOT ((n = 1))` → `NOT (n = 1)`; `((n = 1) OR "items"."n" = 2)` →
  `(n = 1 OR "items"."n" = 2)` because `WhereClause#or` unwraps an outer
  `Grouping` but not textual parens. Results and errors identical (the `-- x` cases
  fail identically on both).

Extended runner (`ext.rb`, SHA-256 `943ee533…`): 14 inputs × 23 compositions
(adds association scope/where, STI, joins+merge, rewhere, unscope, invert_where,
or with common predicates, string↔node dedup, array binds, `Fragments`, blank
bound nodes) + 3 equality probes. 8.1 = main = minimal on all 325. B differs on
173: 81 result changes (43 explicit-node precedence fixes and 38 blank-node
error-message changes), the other 92 SQL-only of the kinds above. The equality probes
`where("n = ?", 1).where_clause == where(Arel.sql("n = ?", 1)).where_clause`,
the same with `"(n = ?)"`, and relation `==` flip from false to true.

Path check (`paths.rb`, SHA-256 `af7875ff…`): eager_load/joins/preload with
string-scoped associations, `update_all`, `delete_all`, `exists?`, `count`,
`scoping` with update/`first_or_create!`, `in_batches`, subqueries, having,
`where_values_hash`, scope attributes for `new`, query cache, find/count-by-SQL.
String-built conditions stay grouped on every path. B vs 8.1: only the
explicit-node eager_load fix (`AND n = ? OR n = ?` → `AND (n = ? OR n = ?)`,
items [3, 4] → [3]), `NOT ((…))` → `NOT (…)`, and #58427's intended binds in
find/count-by-SQL (also on the minimal fix).

### Tests

`RAILS_STRICT_WARNINGS=1 PARALLEL_WORKERS=1`, seed 1729, on `f6a0268e9c`:

* SQLite: `relation/`, `relation_test`, `relations_test`, `sanitize_test`,
  `finder_test`, `associations/`, `associations_test`, `scoping/`,
  `inheritance_test`, `base_test`, `bind_parameter_test`, `arel/`:
  **4,517 runs, 13,226 assertions, 0 failures, 0 errors, 5 skips.** The first run
  had 1 failure, the `relation_test.rb` expectation above, fixed in the commit.
* PostgreSQL 15.19, same set without `arel/`: **3,748 runs, 12,018 assertions,
  0 failures, 0 errors, 1 skip.**
* The three where tests on B: 3 runs, 21 assertions, pass. On unmodified main:
  all three fail (strict-warning error for the empty case, SQL-shape failure for
  the sanitized case, `[2, 4]` vs `[4]` for the bound-node case).

These runs were on `f6a0268e9c`; `10346a258e` differs only by the CHANGELOG entry.
Fork CI for `10346a258e` is subscribed; not yet reported here.

### Review

The first separate Claude Code review did not run (rate limit). It ran later
the same day:

### Final review of option B (Claude Code, 2026-11-06)

Verdict: **correct; one real problem fixed (commit hygiene), CHANGELOG added.**
New head [`10346a258e`](https://github.com/thomasklemm/rails/commit/10346a258e1fd105de7561437ad7917ff3cb9b47),
force-pushed with a lease on `f6a0268e9c`. Same tree plus the CHANGELOG entry.

* **Fixed: trailer.** `f6a0268e9c` carried an `Amp-Thread-ID` trailer. Amp's
  commit wrapper adds it to `git commit`, so the new commit was built with
  `git commit-tree` and has no trailers. Author and committer are both Thomas Klemm.
* **Added: CHANGELOG.** The explicit-node fix changes released behaviour, so it
  needs an entry. Its example SQL was executed on 8.1 (bare) and on B (grouped).
  The #58427 part needs none: it is unreleased.
* **Commit message.** Rewritten slightly. It now states that the string path was
  only safe because of #51139's textual parens, and it names the SQL-text costs
  (`where.not`/`or` lose a pair; string and explicit node now compare equal).
  Wrapped at 72 columns, no trailers.
* **Latent bug: confirmed, and older than claimed.** Independent runner
  (`latent.rb`, 5 rows, owners a/b, STI `Special`), node
  `Arel.sql("n = ? OR n = ?", 1, 3)`. Identical bare output on **7-1-stable,
  7-2-stable, 8-0-stable, 8-1-stable `6e09124217`, main `cadf0fc8d6`** and the
  minimal fix merged into main. `where(node).where(n: [2, 3])` emits
  `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` → ids [1, 3, 4, 5] (string
  form [3, 4]). It is not limited to 7.2+: `Arel.sql` binds landed in
  `6444ec0d30` (7.1.0), and 7.1 leaks too. Leaks reproduced through `where`
  before/after, `merge`, association scope, association `where`, STI, `having`,
  `joins`+`merge`, `eager_load` join ON, `invert_where`, `update_all` (4 rows vs
  2), `delete_all` (4 vs 2), `exists?` (true vs false), `count` (4 vs 2).
  `where.not` and `or` are safe on every version.
* **Consumers on B.** All of the above are grouped and return the string-form
  rows. `ast` is the only place the grouping is applied; predicates stay
  unwrapped in storage, so `or` (unwraps the outer `Grouping`), `invert`
  (single predicate → `node.invert` → `Not`), `merge`/`except`/`-`/`|`,
  `==`/`hash`, `contradiction?` and `to_h` see the same nodes as before. Only
  node equality changes, because string-built nodes no longer carry `(…)`.
  `find_by_sql`/`count_by_sql` stay unwrapped and bound (`WHERE n = ?`).
  An explicit `Grouping` node is not re-wrapped (the visitor collapses nested
  groupings anyway): `WHERE (n = 1 OR n = 3) AND …` on all versions. Blank
  explicit bound node: `WHERE  AND …` → `WHERE () AND …`, an SQL error either way.
  Leaving it as an error is right.
* **Not covered, all versions:** `Arel::Nodes::Fragments` (`Arel.sql("n = 1") +
  Arel.sql(" OR n = 3")`) is still bare on 7.1–B. It can hold arbitrary nodes,
  so grouping it is a separate decision. Not a B regression. Worth a follow-up
  mention, not part of this PR.
* **SQL-text and dedup changes: acceptable.** Placeholder strings under
  `NOT`/`OR` go back to exactly the 7.1 SQL in 140 of 144 differential cases.
  The other 4 are `or_literal_equivalent` with OR placeholders: 7.1 interpolated
  eagerly and deduplicated against the literal string. No string-built
  condition changes rows. String vs explicit-node dedup now works
  (`where("n = ?", 1).merge(where(Arel.sql("n = ?", 1)))` → one predicate).
  Only an explicit node with its own outer parens gains a pair: `((n = 1))`.
* **Differential rerun** (runner SHA-256 `6d4bd527…` extracted from this record,
  Ruby 4.0.7, sqlite3 2.10.1): 8.1 vs main 683; 8.1 vs minimal merged into main 0;
  8.1 vs B 204; minimal vs B 204; main vs B 887; overlap with the 683 = 0.
  Result changes 8.1 → B: exactly the 12 `arel_bound`/`arel_bound_extra` ×
  `and_after`/`merge_reverse`/`having_and` cases. Matches the record.
* **Tests** (SQLite, `RAILS_STRICT_WARNINGS=1 PARALLEL_WORKERS=1`, seed 1729,
  B tree): `relation/`, `relation_test`, `relations_test`, `sanitize_test`,
  `finder_test`, `associations/`, `associations_test`, `scoping/`,
  `inheritance_test`, `base_test`, `bind_parameter_test`, `arel/`:
  **4,517 runs, 13,226 assertions, 0 failures, 0 errors, 5 skips.** The three
  new where tests: 3 runs, 21 assertions on B. On unmodified main: 2 failures,
  1 error (strict-warning error, SQL-shape failure, `[2, 4]` vs `[4]`).
  PostgreSQL was not rerun in this review.

### Recommendation

Offer **B** as the answer to matthewd and the proposed PR shape, pending his
agreement. It is the structural fix he asked about: one grouping layer in
`WhereClause` for every SQL literal, no textual parentheses, 2 runtime lines.
It also fixes a real row-leaking precedence bug for explicit bound nodes,
present since 7.1, that the textual-parens design never covered. Its costs
are SQL-text changes only (no string-built condition changes rows): one pair
fewer inside `NOT`/`OR` for placeholder strings (back to 7.1's SQL), one pair
more for explicit nodes with their own parens, and string-built and explicit
bound literals now compare equal. Apps asserting exact `to_sql` or query-log
text will see diffs in those cases. The branch has a CHANGELOG entry for the
explicit-node fix; the #58427 part needs none.

Keep **805ab06262** as the fallback: exact 8.1 compatibility, scoped to the
#58427 regression only. If matthewd prefers not to change explicit-node SQL in a
regression fix, ship it and propose B separately as the precedence fix.

### Reply to matthewd (final, posted 2026-11-06 as discussion_r4492126885)

Replaces the revised draft. Checked claim by claim in the final review above.

They were first added in [2a35baa](https://github.com/rails/rails/commit/2a35baa0bb4312d95e1340074cce731afedecde0) (2005), to stop an OR in `:conditions` escaping an association constraint. [328ef3f](https://github.com/rails/rails/commit/328ef3feaad4c110a7277e3432e9203c7fbbb9e2) extended that to all `:conditions`, so they could be combined with STI and scope constraints.

From there they moved through `merge_conditions` (2008), the relation's `build_where` and `build_arel` (2010, where they became an AST `Grouping`) and `collapse_wheres`, and landed [in `WhereClause`](https://github.com/rails/rails/commit/a5fcdae0a04d97dbd8fd05af6f352d3e09b2815f) in 2015. [A 2017 refactor](https://github.com/rails/rails/commit/213796fb4936dce1da2f0c097a054e1af5c25c2c) limited that grouping to String/`SqlLiteral`. Through 7.1, placeholder values were interpolated into a plain string, so every string condition was grouped there. [#51139](https://github.com/rails/rails/pull/51139) started building `BoundSqlLiteral`s, which `WhereClause` doesn't group, so it gave them textual parens. [#58427](https://github.com/rails/rails/pull/58427) moved those parens ahead of dispatch, so the sanitizer fallback got them too, on top of `WhereClause`'s. [Timeline and reproducer](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/where-parens-history.md).

Should they exist? The grouping, yes. The textual parens, no: they never covered bound nodes passed in directly. Since 7.1, `Item.where(Arel.sql("n = ? OR n = ?", 1, 3)).where(n: [2, 3])` emits `WHERE n = 1 OR n = 3 AND "items"."n" IN (2, 3)` and returns `n = 1` rows. The same happens through `merge`, association scopes, STI, `having`, `eager_load` join conditions, `invert_where`, `update_all` and `delete_all`.

Empty string isn't the only change. Against 8.1, sanitized conditions with values also get doubled parens, identical conditions stop deduplicating on `merge`/`or`, and blank strings start converting values they used to ignore. (My earlier reply was too broad: on 8.1, `where("", {})` on its own already produced a dangling `WHERE`. Only combining it with another condition worked.)

The alternative I'd suggest is [this branch](https://github.com/thomasklemm/rails/commit/10346a258e1fd105de7561437ad7917ff3cb9b47): `WhereClause` groups `BoundSqlLiteral` like `SqlLiteral`, and the `"(#{opts})"` goes away. That's two lines, and find/count-by-SQL stay unwrapped. It fixes both the #58427 regression and the explicit-node case. Results change only for explicit bound nodes, but the SQL text changes too: placeholder strings lose a redundant pair inside `NOT`/`OR` (back to 7.1's output), explicit bound nodes gain one, and a string condition now equals the same explicit node for dedup. If you'd rather keep this PR to exact 8.1 output, the current head does that, and I can send the grouping change separately.

## Reproducer and exact differing outputs

The following appendices are generated from the executed runner and captured
JSON, not transcribed SQL. The runner loads local Rails sources for each pin and
uses the same installed dependency versions for every run. Copy it out and run
`ruby where-differential.rb /path/to/rails-checkout > result.json` under the
Ruby/gem environment above. `args` versus `array` in a case ID identifies the
argument shape; the third component is the exact operation in the runner.

Every changed case is listed once below. Cases with identical complete output
pairs are grouped. Error messages are the first line only, by design of the
capture function; SQL strings retain every space, tab, newline and parenthesis.

### Executed runner

```ruby
require "json"
gem "sqlite3", "2.10.1"
root = ARGV.fetch(0)
%w[activesupport activemodel activerecord].reverse_each { $LOAD_PATH.unshift "#{root}/#{_1}/lib" }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:items) { |t| t.integer :n; t.string :name }
end
class Item < ActiveRecord::Base; end
[[1, "one"], [2, "two"], [3, "three"]].each { |n, name| Item.create!(n: n, name: name) }
class UnusedValue
  def to_s = raise("unused value was converted")
  def inspect = "UnusedValue.new"
end
inputs = {
  empty: ["", {}], empty_unused_named: ["", { n: 1 }], empty_unused_positional: ["", 1],
  empty_unused_object: ["", UnusedValue.new], space_unused_object: [" ", UnusedValue.new],
  space: [" ", {}], whitespace: [" \t\n", 1], line_comment: ["-- x", {}],
  line_comment_newline: ["-- x\n", {}], block_comment: ["/* x */", {}],
  literal: ["n = 1", {}], unused_positional: ["n = 1", 2],
  trailing_line: ["n = 1 -- x", {}], trailing_line_newline: ["n = 1 -- x\n", {}],
  trailing_block: ["n = 1 /* x */", {}], already_parens: ["(n = 1)", {}],
  or_literal: ["n = 1 OR n = 3", {}], sprintf: ["name = '%s'", "one"],
  sprintf_parens: ["(name = '%s')", "one"], sprintf_or: ["name = '%s' OR n = 3", "one"],
  sprintf_trailing_block: ["name = '%s' /* x */", "one"],
  positional: ["n = ?", 1], named: ["n = :n", { n: 1 }],
  positional_or: ["n = ? OR n = ?", 1, 3], named_or: ["n = :n OR n = :m", { n: 1, m: 3 }],
  positional_parens: ["(n = ?)", 1], named_parens: ["(n = :n)", { n: 1 }],
  positional_line: ["n = ? -- x", 1], named_line: ["n = :n -- x", { n: 1 }],
  positional_block: ["n = ? /* x */", 1], named_block: ["n = :n /* x */", { n: 1 }],
  comment_question: ["n = 1 /* ? */", 2], comment_named: ["n = 1 /* :n */", { n: 2 }],
  no_values_empty: [""], no_values_space: [" "], no_values_literal: ["n = 1"],
  no_values_or: ["n = 1 OR n = 3"], no_values_line: ["n = 1 -- x"],
  arel_literal: [Arel.sql("n = 1 OR n = 3")],
  arel_literal_values: [Arel.sql("n = 1 OR n = 3"), {}],
  arel_bound: [Arel.sql("n = ? OR n = ?", 1, 3)],
  arel_bound_extra: [Arel.sql("n = ? OR n = ?", 1, 3), {}],
  arel_merge_equivalent: [Arel.sql("(n = ?)", 1)],
  arel_node: [Item.arel_table[:n].eq(1).or(Item.arel_table[:n].eq(3))]
}
operations = {
  where: ->(args) { Item.where(*args) },
  and_after: ->(args) { Item.where(*args).where(n: [2, 3]) },
  and_before: ->(args) { Item.where(n: [2, 3]).where(*args) },
  or: ->(args) { Item.where(*args).or(Item.where(n: 2)) },
  or_reverse: ->(args) { Item.where(n: 2).or(Item.where(*args)) },
  not: ->(args) { Item.where.not(*args) },
  not_and: ->(args) { Item.where(n: [2, 3]).where.not(*args) },
  merge: ->(args) { Item.where(n: [2, 3]).merge(Item.where(*args)) },
  merge_reverse: ->(args) { Item.where(*args).merge(Item.where(n: [2, 3])) },
  merge_duplicate: ->(args) { Item.where(*args).merge(Item.where(*args)) },
  merge_bound_equivalent: ->(args) { Item.where(*args).merge(Item.where("n = ?", 1)) },
  merge_literal_equivalent: ->(args) { Item.where(*args).merge(Item.where("n = 1 OR n = 3")) },
  or_literal_equivalent: ->(args) { Item.where(*args).or(Item.where("n = 1 OR n = 3")) },
  having: ->(args) { Item.group(:id).having(*args) },
  having_and: ->(args) { Item.group(:id).having(*args).having(n: [2, 3]) },
  having_or: ->(args) { Item.group(:id).having(*args).or(Item.group(:id).having(n: 2)) }
}
capture = ->(&block) do
  block.call
rescue StandardError => e
  { error: e.class.name, message: e.message.lines.first.chomp }
end
rows = {}
inputs.each do |name, args|
  %i[args array].each do |form|
    passed = form == :args ? args : [args]
    operations.each do |operation, build|
      key = "#{name}/#{form}/#{operation}"
      rows[key] = capture.call do
        relation = build.call(passed)
        {
          sql: capture.call { relation.to_sql },
          result: capture.call { relation.to_a.map(&:n).sort },
          empty: relation.where_clause.empty?, having_empty: relation.having_clause.empty?
        }
      end
    end
  end
end
puts JSON.pretty_generate({ ruby: RUBY_DESCRIPTION, sqlite_gem: SQLite3::VERSION, sqlite: SQLite3::SQLITE_VERSION, inputs: inputs.transform_values { _1.map(&:inspect) }, rows: rows })
```

Runner SHA-256: `6d4bd5271f927086d315d997bbc52b72e6c352fcd5d788e8efbcc7baed999263`.

### Input registry

```json
{
  "empty": [
    "\"\"",
    "{}"
  ],
  "empty_unused_named": [
    "\"\"",
    "{n: 1}"
  ],
  "empty_unused_positional": [
    "\"\"",
    "1"
  ],
  "empty_unused_object": [
    "\"\"",
    "UnusedValue.new"
  ],
  "space_unused_object": [
    "\" \"",
    "UnusedValue.new"
  ],
  "space": [
    "\" \"",
    "{}"
  ],
  "whitespace": [
    "\" \\t\\n\"",
    "1"
  ],
  "line_comment": [
    "\"-- x\"",
    "{}"
  ],
  "line_comment_newline": [
    "\"-- x\\n\"",
    "{}"
  ],
  "block_comment": [
    "\"/* x */\"",
    "{}"
  ],
  "literal": [
    "\"n = 1\"",
    "{}"
  ],
  "unused_positional": [
    "\"n = 1\"",
    "2"
  ],
  "trailing_line": [
    "\"n = 1 -- x\"",
    "{}"
  ],
  "trailing_line_newline": [
    "\"n = 1 -- x\\n\"",
    "{}"
  ],
  "trailing_block": [
    "\"n = 1 /* x */\"",
    "{}"
  ],
  "already_parens": [
    "\"(n = 1)\"",
    "{}"
  ],
  "or_literal": [
    "\"n = 1 OR n = 3\"",
    "{}"
  ],
  "sprintf": [
    "\"name = '%s'\"",
    "\"one\""
  ],
  "sprintf_parens": [
    "\"(name = '%s')\"",
    "\"one\""
  ],
  "sprintf_or": [
    "\"name = '%s' OR n = 3\"",
    "\"one\""
  ],
  "sprintf_trailing_block": [
    "\"name = '%s' /* x */\"",
    "\"one\""
  ],
  "positional": [
    "\"n = ?\"",
    "1"
  ],
  "named": [
    "\"n = :n\"",
    "{n: 1}"
  ],
  "positional_or": [
    "\"n = ? OR n = ?\"",
    "1",
    "3"
  ],
  "named_or": [
    "\"n = :n OR n = :m\"",
    "{n: 1, m: 3}"
  ],
  "positional_parens": [
    "\"(n = ?)\"",
    "1"
  ],
  "named_parens": [
    "\"(n = :n)\"",
    "{n: 1}"
  ],
  "positional_line": [
    "\"n = ? -- x\"",
    "1"
  ],
  "named_line": [
    "\"n = :n -- x\"",
    "{n: 1}"
  ],
  "positional_block": [
    "\"n = ? /* x */\"",
    "1"
  ],
  "named_block": [
    "\"n = :n /* x */\"",
    "{n: 1}"
  ],
  "comment_question": [
    "\"n = 1 /* ? */\"",
    "2"
  ],
  "comment_named": [
    "\"n = 1 /* :n */\"",
    "{n: 2}"
  ],
  "no_values_empty": [
    "\"\""
  ],
  "no_values_space": [
    "\" \""
  ],
  "no_values_literal": [
    "\"n = 1\""
  ],
  "no_values_or": [
    "\"n = 1 OR n = 3\""
  ],
  "no_values_line": [
    "\"n = 1 -- x\""
  ],
  "arel_literal": [
    "\"n = 1 OR n = 3\""
  ],
  "arel_literal_values": [
    "\"n = 1 OR n = 3\"",
    "{}"
  ],
  "arel_bound": [
    "#<Arel::Nodes::BoundSqlLiteral \"n = ? OR n = ?\" [1, 3]>"
  ],
  "arel_bound_extra": [
    "#<Arel::Nodes::BoundSqlLiteral \"n = ? OR n = ?\" [1, 3]>",
    "{}"
  ],
  "arel_merge_equivalent": [
    "#<Arel::Nodes::BoundSqlLiteral \"(n = ?)\" [1]>"
  ],
  "arel_node": [
    "#<Arel::Nodes::Grouping:0x00007f7bc2321cf8 @expr=#<Arel::Nodes::Or:0x00007f7bc2321d70 @children=[#<Arel::Nodes::Equality:0x00007f7bc2321f00 @left=#<struct Arel::Attributes::Attribute relation=#<Arel::Table:0x00007f7bc23356e0 @name=\"items\", @klass=Item(id: integer, n: integer, name: string), @type_caster=#<ActiveRecord::TypeCaster::Map:0x00007f7bc2327c98 @klass=Item(id: integer, n: integer, name: string)>, @table_alias=nil>, name=\"n\">, @right=#<Arel::Nodes::Casted:0x00007f7bc2321f50 @value=1, @attribute=#<struct Arel::Attributes::Attribute relation=#<Arel::Table:0x00007f7bc23356e0 @name=\"items\", @klass=Item(id: integer, n: integer, name: string), @type_caster=#<ActiveRecord::TypeCaster::Map:0x00007f7bc2327c98 @klass=Item(id: integer, n: integer, name: string)>, @table_alias=nil>, name=\"n\">>>, #<Arel::Nodes::Equality:0x00007f7bc2321e60 @left=#<struct Arel::Attributes::Attribute relation=#<Arel::Table:0x00007f7bc23356e0 @name=\"items\", @klass=Item(id: integer, n: integer, name: string), @type_caster=#<ActiveRecord::TypeCaster::Map:0x00007f7bc2327c98 @klass=Item(id: integer, n: integer, name: string)>, @table_alias=nil>, name=\"n\">, @right=#<Arel::Nodes::Casted:0x00007f7bc2321e88 @value=3, @attribute=#<struct Arel::Attributes::Attribute relation=#<Arel::Table:0x00007f7bc23356e0 @name=\"items\", @klass=Item(id: integer, n: integer, name: string), @type_caster=#<ActiveRecord::TypeCaster::Map:0x00007f7bc2327c98 @klass=Item(id: integer, n: integer, name: string)>, @table_alias=nil>, name=\"n\">>>]>>"
  ]
}
```

### Every differing case (683 cases, 233 exact output pairs)

```jsonl
{"cases":["empty/args/where","empty/args/merge_duplicate","empty/array/where","empty/array/merge_duplicate","empty_unused_named/args/where","empty_unused_named/args/merge_duplicate","empty_unused_named/array/where","empty_unused_named/array/merge_duplicate","empty_unused_positional/args/where","empty_unused_positional/args/merge_duplicate","empty_unused_positional/array/where","empty_unused_positional/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/and_after","empty/args/merge_reverse","empty/array/and_after","empty/array/merge_reverse","empty_unused_named/args/and_after","empty_unused_named/args/merge_reverse","empty_unused_named/array/and_after","empty_unused_named/array/merge_reverse","empty_unused_positional/args/and_after","empty_unused_positional/args/merge_reverse","empty_unused_positional/array/and_after","empty_unused_positional/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (()) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/and_before","empty/args/merge","empty/array/and_before","empty/array/merge","empty_unused_named/args/and_before","empty_unused_named/args/merge","empty_unused_named/array/and_before","empty_unused_named/array/merge","empty_unused_positional/args/and_before","empty_unused_positional/args/merge","empty_unused_positional/array/and_before","empty_unused_positional/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/or","empty/array/or","empty_unused_named/args/or","empty_unused_named/array/or","empty_unused_positional/args/or","empty_unused_positional/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (() OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/or_reverse","empty/array/or_reverse","empty_unused_named/args/or_reverse","empty_unused_named/array/or_reverse","empty_unused_positional/args/or_reverse","empty_unused_positional/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR ())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/not","empty/array/not","empty_unused_named/args/not","empty_unused_named/array/not","empty_unused_positional/args/not","empty_unused_positional/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ()","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/not_and","empty/array/not_and","empty_unused_named/args/not_and","empty_unused_named/array/not_and","empty_unused_positional/args/not_and","empty_unused_positional/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ()","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/merge_bound_equivalent","empty/array/merge_bound_equivalent","empty_unused_named/args/merge_bound_equivalent","empty_unused_named/array/merge_bound_equivalent","empty_unused_positional/args/merge_bound_equivalent","empty_unused_positional/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (()) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/merge_literal_equivalent","empty/array/merge_literal_equivalent","empty_unused_named/args/merge_literal_equivalent","empty_unused_named/array/merge_literal_equivalent","empty_unused_positional/args/merge_literal_equivalent","empty_unused_positional/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (()) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/args/or_literal_equivalent","empty/array/or_literal_equivalent","empty_unused_named/args/or_literal_equivalent","empty_unused_named/array/or_literal_equivalent","empty_unused_positional/args/or_literal_equivalent","empty_unused_positional/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (() OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["empty/array/having","empty_unused_named/array/having","empty_unused_positional/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (())","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["empty/array/having_and","empty_unused_named/array/having_and","empty_unused_positional/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING \"items\".\"n\" IN (2, 3)","result":[2,3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (()) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["empty/array/having_or","empty_unused_named/array/having_or","empty_unused_positional/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (() OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["empty_unused_object/args/where","empty_unused_object/args/merge_duplicate","empty_unused_object/array/where","empty_unused_object/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/and_after","empty_unused_object/args/and_before","empty_unused_object/args/merge","empty_unused_object/args/merge_reverse","empty_unused_object/array/and_after","empty_unused_object/array/and_before","empty_unused_object/array/merge","empty_unused_object/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3)","result":[2,3],"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/or","empty_unused_object/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/or_reverse","empty_unused_object/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/not","empty_unused_object/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ()","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/not_and","empty_unused_object/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ()","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/merge_bound_equivalent","empty_unused_object/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/merge_literal_equivalent","empty_unused_object/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/args/or_literal_equivalent","empty_unused_object/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING \"items\".\"n\" IN (2, 3)","result":[2,3],"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["empty_unused_object/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/where","space_unused_object/args/merge_duplicate","space_unused_object/array/where","space_unused_object/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/and_after","space_unused_object/args/merge_reverse","space_unused_object/array/and_after","space_unused_object/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/and_before","space_unused_object/args/merge","space_unused_object/array/and_before","space_unused_object/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/or","space_unused_object/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (  OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/or_reverse","space_unused_object/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR  )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/not","space_unused_object/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/not_and","space_unused_object/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/merge_bound_equivalent","space_unused_object/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/merge_literal_equivalent","space_unused_object/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/args/or_literal_equivalent","space_unused_object/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (  OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( ) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space_unused_object/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (  OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"error":"RuntimeError","message":"unused value was converted"}}
{"cases":["space/args/where","space/args/merge_duplicate","space/array/where","space/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/and_after","space/args/merge_reverse","space/array/and_after","space/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( )) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/and_before","space/args/merge","space/array/and_before","space/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/or","space/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (  OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( ) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/or_reverse","space/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR  )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR ( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/not","space/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/not_and","space/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/merge_bound_equivalent","space/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( )) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/merge_literal_equivalent","space/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( ) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( )) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/args/or_literal_equivalent","space/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (  OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( ) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["space/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( )","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( ))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["space/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( ) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( )) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["space/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (  OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( ) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["whitespace/args/where","whitespace/args/merge_duplicate","whitespace/array/where","whitespace/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/and_after","whitespace/args/merge_reverse","whitespace/array/and_after","whitespace/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/and_before","whitespace/args/merge","whitespace/array/and_before","whitespace/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ( \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/or","whitespace/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/or_reverse","whitespace/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR  \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR ( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/not","whitespace/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ( \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/not_and","whitespace/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ( \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/merge_bound_equivalent","whitespace/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n)) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/merge_literal_equivalent","whitespace/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n)) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/args/or_literal_equivalent","whitespace/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ( \t\n OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (( \t\n) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["whitespace/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( \t\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( \t\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["whitespace/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( \t\n) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( \t\n)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["whitespace/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ( \t\n OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (( \t\n) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["line_comment/args/where","line_comment/args/merge_duplicate","line_comment/array/where","line_comment/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/and_after","line_comment/args/merge_reverse","line_comment/array/and_after","line_comment/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/and_before","line_comment/args/merge","line_comment/array/and_before","line_comment/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (-- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/or","line_comment/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/or_reverse","line_comment/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/not","line_comment/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (-- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/not_and","line_comment/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (-- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/merge_bound_equivalent","line_comment/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x)) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/merge_literal_equivalent","line_comment/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x)) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/or_literal_equivalent","line_comment/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["line_comment/args/having","line_comment/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["line_comment/args/having_and","line_comment/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["line_comment/args/having_or","line_comment/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["line_comment_newline/args/where","line_comment_newline/args/merge_duplicate","line_comment_newline/array/where","line_comment_newline/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/and_after","line_comment_newline/args/merge_reverse","line_comment_newline/array/and_after","line_comment_newline/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/and_before","line_comment_newline/args/merge","line_comment_newline/array/and_before","line_comment_newline/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (-- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/or","line_comment_newline/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/or_reverse","line_comment_newline/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR -- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/not","line_comment_newline/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (-- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/not_and","line_comment_newline/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (-- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/merge_bound_equivalent","line_comment_newline/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n)) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/merge_literal_equivalent","line_comment_newline/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n)) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/or_literal_equivalent","line_comment_newline/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (-- x\n OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((-- x\n) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["line_comment_newline/args/having","line_comment_newline/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x\n)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x\n))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["line_comment_newline/args/having_and","line_comment_newline/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x\n) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x\n)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["line_comment_newline/args/having_or","line_comment_newline/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (-- x\n OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((-- x\n) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["block_comment/args/where","block_comment/args/merge_duplicate","block_comment/array/where","block_comment/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/and_after","block_comment/args/merge_reverse","block_comment/array/and_after","block_comment/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/and_before","block_comment/args/merge","block_comment/array/and_before","block_comment/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (/* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/or","block_comment/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */ OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/or_reverse","block_comment/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR /* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/not","block_comment/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (/* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/not_and","block_comment/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (/* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/merge_bound_equivalent","block_comment/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */)) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/merge_literal_equivalent","block_comment/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */)) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/or_literal_equivalent","block_comment/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (/* x */ OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((/* x */) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":false,"having_empty":true}}
{"cases":["block_comment/args/having","block_comment/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (/* x */)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((/* x */))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["block_comment/args/having_and","block_comment/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (/* x */) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((/* x */)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["block_comment/args/having_or","block_comment/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (/* x */ OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \"OR\": syntax error:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((/* x */) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: near \")\": syntax error:"},"empty":true,"having_empty":false}}
{"cases":["literal/args/where","literal/args/merge_duplicate","literal/array/where","literal/array/merge_duplicate","unused_positional/args/where","unused_positional/args/merge_duplicate","unused_positional/array/where","unused_positional/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1))","result":[1],"empty":false,"having_empty":true}}
{"cases":["literal/args/and_after","literal/args/merge_reverse","literal/array/and_after","literal/array/merge_reverse","unused_positional/args/and_after","unused_positional/args/merge_reverse","unused_positional/array/and_after","unused_positional/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["literal/args/and_before","literal/args/merge","literal/array/and_before","literal/array/merge","unused_positional/args/and_before","unused_positional/args/merge","unused_positional/array/and_before","unused_positional/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (n = 1)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1))","result":[],"empty":false,"having_empty":true}}
{"cases":["literal/args/or","literal/array/or","unused_positional/args/or","unused_positional/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["literal/args/or_reverse","literal/array/or_reverse","unused_positional/args/or_reverse","unused_positional/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR n = 1)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["literal/args/not","literal/array/not","unused_positional/args/not","unused_positional/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (n = 1)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["literal/args/not_and","literal/array/not_and","unused_positional/args/not_and","unused_positional/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (n = 1)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["literal/args/merge_bound_equivalent","literal/array/merge_bound_equivalent","unused_positional/args/merge_bound_equivalent","unused_positional/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["literal/args/merge_literal_equivalent","literal/array/merge_literal_equivalent","unused_positional/args/merge_literal_equivalent","unused_positional/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["literal/args/or_literal_equivalent","literal/array/or_literal_equivalent","unused_positional/args/or_literal_equivalent","unused_positional/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["literal/args/having","literal/array/having","unused_positional/args/having","unused_positional/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1)","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1))","result":[1],"empty":true,"having_empty":false}}
{"cases":["literal/args/having_and","literal/array/having_and","unused_positional/args/having_and","unused_positional/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["literal/args/having_or","literal/array/having_or","unused_positional/args/having_or","unused_positional/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["trailing_line/args/where","trailing_line/args/merge_duplicate","trailing_line/array/where","trailing_line/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/and_after","trailing_line/args/merge_reverse","trailing_line/array/and_after","trailing_line/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/and_before","trailing_line/args/merge","trailing_line/array/and_before","trailing_line/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/or","trailing_line/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/or_reverse","trailing_line/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/not","trailing_line/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/not_and","trailing_line/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/merge_bound_equivalent","trailing_line/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x)) AND (n = 1)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/merge_literal_equivalent","trailing_line/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x)) AND (n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/or_literal_equivalent","trailing_line/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x) OR n = 1 OR n = 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":false,"having_empty":true}}
{"cases":["trailing_line/args/having","trailing_line/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x))","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["trailing_line/args/having_and","trailing_line/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x)) AND \"items\".\"n\" IN (2, 3)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["trailing_line/args/having_or","trailing_line/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x) OR \"items\".\"n\" = 2)","result":{"error":"ActiveRecord::StatementInvalid","message":"SQLite3::SQLException: incomplete input:"},"empty":true,"having_empty":false}}
{"cases":["trailing_line_newline/args/where","trailing_line_newline/args/merge_duplicate","trailing_line_newline/array/where","trailing_line_newline/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n))","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/and_after","trailing_line_newline/args/merge_reverse","trailing_line_newline/array/and_after","trailing_line_newline/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/and_before","trailing_line_newline/args/merge","trailing_line_newline/array/and_before","trailing_line_newline/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (n = 1 -- x\n)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1 -- x\n))","result":[],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/or","trailing_line_newline/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/or_reverse","trailing_line_newline/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR n = 1 -- x\n)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1 -- x\n))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/not","trailing_line_newline/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (n = 1 -- x\n)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1 -- x\n))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/not_and","trailing_line_newline/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (n = 1 -- x\n)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1 -- x\n))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/merge_bound_equivalent","trailing_line_newline/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/merge_literal_equivalent","trailing_line_newline/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n)) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/or_literal_equivalent","trailing_line_newline/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 -- x\n OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 -- x\n) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["trailing_line_newline/args/having","trailing_line_newline/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x\n)","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x\n))","result":[1],"empty":true,"having_empty":false}}
{"cases":["trailing_line_newline/args/having_and","trailing_line_newline/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x\n) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x\n)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["trailing_line_newline/args/having_or","trailing_line_newline/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 -- x\n OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 -- x\n) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["trailing_block/args/where","trailing_block/args/merge_duplicate","trailing_block/array/where","trailing_block/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */))","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/and_after","trailing_block/args/merge_reverse","trailing_block/array/and_after","trailing_block/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/and_before","trailing_block/args/merge","trailing_block/array/and_before","trailing_block/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (n = 1 /* x */)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1 /* x */))","result":[],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/or","trailing_block/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */ OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/or_reverse","trailing_block/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR n = 1 /* x */)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1 /* x */))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/not","trailing_block/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (n = 1 /* x */)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1 /* x */))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/not_and","trailing_block/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (n = 1 /* x */)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1 /* x */))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/merge_bound_equivalent","trailing_block/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/merge_literal_equivalent","trailing_block/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */)) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/or_literal_equivalent","trailing_block/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 /* x */ OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 /* x */) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["trailing_block/args/having","trailing_block/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 /* x */)","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 /* x */))","result":[1],"empty":true,"having_empty":false}}
{"cases":["trailing_block/args/having_and","trailing_block/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 /* x */) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 /* x */)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["trailing_block/args/having_or","trailing_block/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 /* x */ OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 /* x */) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["already_parens/args/where","already_parens/args/merge_duplicate","already_parens/array/where","already_parens/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1))","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1)))","result":[1],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/and_after","already_parens/args/merge_reverse","already_parens/array/and_after","already_parens/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1))) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/and_before","already_parens/args/merge","already_parens/array/and_before","already_parens/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1))","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (((n = 1)))","result":[],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/or","already_parens/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1)) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/or_reverse","already_parens/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1))","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR ((n = 1)))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/not","already_parens/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1))","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (((n = 1)))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/not_and","already_parens/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1))","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (((n = 1)))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/merge_bound_equivalent","already_parens/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1))) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/merge_literal_equivalent","already_parens/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1)) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1))) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/or_literal_equivalent","already_parens/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((n = 1)) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["already_parens/args/having","already_parens/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1))","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((n = 1)))","result":[1],"empty":true,"having_empty":false}}
{"cases":["already_parens/args/having_and","already_parens/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((n = 1))) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["already_parens/args/having_or","already_parens/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((n = 1)) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["or_literal/args/where","or_literal/args/merge_duplicate","or_literal/array/where","or_literal/array/merge_duplicate","arel_literal_values/args/where","arel_literal_values/args/merge_duplicate","arel_literal_values/array/where","arel_literal_values/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3))","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/and_after","or_literal/args/merge_reverse","or_literal/array/and_after","or_literal/array/merge_reverse","arel_literal_values/args/and_after","arel_literal_values/args/merge_reverse","arel_literal_values/array/and_after","arel_literal_values/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3)) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/and_before","or_literal/args/merge","or_literal/array/and_before","or_literal/array/merge","arel_literal_values/args/and_before","arel_literal_values/args/merge","arel_literal_values/array/and_before","arel_literal_values/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (n = 1 OR n = 3)","result":[3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((n = 1 OR n = 3))","result":[3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/or","or_literal/array/or","arel_literal_values/args/or","arel_literal_values/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3 OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3) OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/or_reverse","or_literal/array/or_reverse","arel_literal_values/args/or_reverse","arel_literal_values/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR n = 1 OR n = 3)","result":[1,2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (n = 1 OR n = 3))","result":[1,2,3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/not","or_literal/array/not","arel_literal_values/args/not","arel_literal_values/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (n = 1 OR n = 3)","result":[2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((n = 1 OR n = 3))","result":[2],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/not_and","or_literal/array/not_and","arel_literal_values/args/not_and","arel_literal_values/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (n = 1 OR n = 3)","result":[2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((n = 1 OR n = 3))","result":[2],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/merge_bound_equivalent","or_literal/array/merge_bound_equivalent","arel_literal_values/args/merge_bound_equivalent","arel_literal_values/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/merge_literal_equivalent","or_literal/array/merge_literal_equivalent","arel_literal_values/args/merge_literal_equivalent","arel_literal_values/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3)) AND (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/or_literal_equivalent","or_literal/array/or_literal_equivalent","arel_literal_values/args/or_literal_equivalent","arel_literal_values/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((n = 1 OR n = 3) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["or_literal/args/having","or_literal/array/having","arel_literal_values/args/having","arel_literal_values/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 OR n = 3)","result":[1,3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 OR n = 3))","result":[1,3],"empty":true,"having_empty":false}}
{"cases":["or_literal/args/having_and","or_literal/array/having_and","arel_literal_values/args/having_and","arel_literal_values/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 OR n = 3) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 OR n = 3)) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":true,"having_empty":false}}
{"cases":["or_literal/args/having_or","or_literal/array/having_or","arel_literal_values/args/having_or","arel_literal_values/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (n = 1 OR n = 3 OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((n = 1 OR n = 3) OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":true,"having_empty":false}}
{"cases":["sprintf/args/where","sprintf/args/merge_duplicate","sprintf/array/where","sprintf/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one')","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one'))","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/and_after","sprintf/args/merge_reverse","sprintf/array/and_after","sprintf/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one') AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/and_before","sprintf/args/merge","sprintf/array/and_before","sprintf/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (name = 'one')","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((name = 'one'))","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/or","sprintf/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one') OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/or_reverse","sprintf/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR name = 'one')","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (name = 'one'))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/not","sprintf/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (name = 'one')","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((name = 'one'))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/not_and","sprintf/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (name = 'one')","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((name = 'one'))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/merge_bound_equivalent","sprintf/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one') AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/merge_literal_equivalent","sprintf/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one') AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/or_literal_equivalent","sprintf/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one') OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf/args/having","sprintf/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one')","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one'))","result":[1],"empty":true,"having_empty":false}}
{"cases":["sprintf/args/having_and","sprintf/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one') AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one')) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["sprintf/args/having_or","sprintf/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one') OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["sprintf_parens/args/where","sprintf_parens/args/merge_duplicate","sprintf_parens/array/where","sprintf_parens/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one'))","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one')))","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/and_after","sprintf_parens/args/merge_reverse","sprintf_parens/array/and_after","sprintf_parens/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one'))) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/and_before","sprintf_parens/args/merge","sprintf_parens/array/and_before","sprintf_parens/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((name = 'one'))","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (((name = 'one')))","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/or","sprintf_parens/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one') OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one')) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/or_reverse","sprintf_parens/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (name = 'one'))","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR ((name = 'one')))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/not","sprintf_parens/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((name = 'one'))","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (((name = 'one')))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/not_and","sprintf_parens/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((name = 'one'))","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (((name = 'one')))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/merge_bound_equivalent","sprintf_parens/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one'))) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/merge_literal_equivalent","sprintf_parens/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one')) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one'))) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/or_literal_equivalent","sprintf_parens/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one') OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (((name = 'one')) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_parens/args/having","sprintf_parens/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one'))","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((name = 'one')))","result":[1],"empty":true,"having_empty":false}}
{"cases":["sprintf_parens/args/having_and","sprintf_parens/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one')) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((name = 'one'))) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["sprintf_parens/args/having_or","sprintf_parens/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one') OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (((name = 'one')) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
{"cases":["sprintf_or/args/where","sprintf_or/args/merge_duplicate","sprintf_or/array/where","sprintf_or/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3))","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/and_after","sprintf_or/args/merge_reverse","sprintf_or/array/and_after","sprintf_or/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3)) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/and_before","sprintf_or/args/merge","sprintf_or/array/and_before","sprintf_or/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (name = 'one' OR n = 3)","result":[3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((name = 'one' OR n = 3))","result":[3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/or","sprintf_or/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3 OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3) OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/or_reverse","sprintf_or/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR name = 'one' OR n = 3)","result":[1,2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (name = 'one' OR n = 3))","result":[1,2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/not","sprintf_or/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (name = 'one' OR n = 3)","result":[2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((name = 'one' OR n = 3))","result":[2],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/not_and","sprintf_or/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (name = 'one' OR n = 3)","result":[2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((name = 'one' OR n = 3))","result":[2],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/merge_bound_equivalent","sprintf_or/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/merge_literal_equivalent","sprintf_or/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3) AND (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3)) AND (n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/or_literal_equivalent","sprintf_or/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' OR n = 3 OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' OR n = 3) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_or/args/having","sprintf_or/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' OR n = 3)","result":[1,3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' OR n = 3))","result":[1,3],"empty":true,"having_empty":false}}
{"cases":["sprintf_or/args/having_and","sprintf_or/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' OR n = 3) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' OR n = 3)) AND \"items\".\"n\" IN (2, 3)","result":[3],"empty":true,"having_empty":false}}
{"cases":["sprintf_or/args/having_or","sprintf_or/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' OR n = 3 OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' OR n = 3) OR \"items\".\"n\" = 2)","result":[1,2,3],"empty":true,"having_empty":false}}
{"cases":["sprintf_trailing_block/args/where","sprintf_trailing_block/args/merge_duplicate","sprintf_trailing_block/array/where","sprintf_trailing_block/array/merge_duplicate"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */))","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/and_after","sprintf_trailing_block/args/merge_reverse","sprintf_trailing_block/array/and_after","sprintf_trailing_block/array/merge_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/and_before","sprintf_trailing_block/args/merge","sprintf_trailing_block/array/and_before","sprintf_trailing_block/array/merge"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND (name = 'one' /* x */)","result":[],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND ((name = 'one' /* x */))","result":[],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/or","sprintf_trailing_block/array/or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */ OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */) OR \"items\".\"n\" = 2)","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/or_reverse","sprintf_trailing_block/array/or_reverse"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR name = 'one' /* x */)","result":[1,2],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (\"items\".\"n\" = 2 OR (name = 'one' /* x */))","result":[1,2],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/not","sprintf_trailing_block/array/not"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT (name = 'one' /* x */)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE NOT ((name = 'one' /* x */))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/not_and","sprintf_trailing_block/array/not_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT (name = 'one' /* x */)","result":[2,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE \"items\".\"n\" IN (2, 3) AND NOT ((name = 'one' /* x */))","result":[2,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/merge_bound_equivalent","sprintf_trailing_block/array/merge_bound_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */) AND (n = 1)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */)) AND (n = 1)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/merge_literal_equivalent","sprintf_trailing_block/array/merge_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */)) AND (n = 1 OR n = 3)","result":[1],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/or_literal_equivalent","sprintf_trailing_block/array/or_literal_equivalent"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" WHERE (name = 'one' /* x */ OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true},"main":{"sql":"SELECT \"items\".* FROM \"items\" WHERE ((name = 'one' /* x */) OR n = 1 OR n = 3)","result":[1,3],"empty":false,"having_empty":true}}
{"cases":["sprintf_trailing_block/args/having","sprintf_trailing_block/array/having"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' /* x */)","result":[1],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' /* x */))","result":[1],"empty":true,"having_empty":false}}
{"cases":["sprintf_trailing_block/args/having_and","sprintf_trailing_block/array/having_and"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' /* x */) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' /* x */)) AND \"items\".\"n\" IN (2, 3)","result":[],"empty":true,"having_empty":false}}
{"cases":["sprintf_trailing_block/args/having_or","sprintf_trailing_block/array/having_or"],"stable":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING (name = 'one' /* x */ OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false},"main":{"sql":"SELECT \"items\".* FROM \"items\" GROUP BY \"items\".\"id\" HAVING ((name = 'one' /* x */) OR \"items\".\"n\" = 2)","result":[1,2],"empty":true,"having_empty":false}}
```

### Identical cases (725)

```json
[
  "empty/args/having",
  "empty/args/having_and",
  "empty/args/having_or",
  "empty_unused_named/args/having",
  "empty_unused_named/args/having_and",
  "empty_unused_named/args/having_or",
  "empty_unused_positional/args/having",
  "empty_unused_positional/args/having_and",
  "empty_unused_positional/args/having_or",
  "empty_unused_object/args/having",
  "empty_unused_object/args/having_and",
  "empty_unused_object/args/having_or",
  "space_unused_object/args/having",
  "space_unused_object/args/having_and",
  "space_unused_object/args/having_or",
  "space/args/having",
  "space/args/having_and",
  "space/args/having_or",
  "whitespace/args/having",
  "whitespace/args/having_and",
  "whitespace/args/having_or",
  "positional/args/where",
  "positional/args/and_after",
  "positional/args/and_before",
  "positional/args/or",
  "positional/args/or_reverse",
  "positional/args/not",
  "positional/args/not_and",
  "positional/args/merge",
  "positional/args/merge_reverse",
  "positional/args/merge_duplicate",
  "positional/args/merge_bound_equivalent",
  "positional/args/merge_literal_equivalent",
  "positional/args/or_literal_equivalent",
  "positional/args/having",
  "positional/args/having_and",
  "positional/args/having_or",
  "positional/array/where",
  "positional/array/and_after",
  "positional/array/and_before",
  "positional/array/or",
  "positional/array/or_reverse",
  "positional/array/not",
  "positional/array/not_and",
  "positional/array/merge",
  "positional/array/merge_reverse",
  "positional/array/merge_duplicate",
  "positional/array/merge_bound_equivalent",
  "positional/array/merge_literal_equivalent",
  "positional/array/or_literal_equivalent",
  "positional/array/having",
  "positional/array/having_and",
  "positional/array/having_or",
  "named/args/where",
  "named/args/and_after",
  "named/args/and_before",
  "named/args/or",
  "named/args/or_reverse",
  "named/args/not",
  "named/args/not_and",
  "named/args/merge",
  "named/args/merge_reverse",
  "named/args/merge_duplicate",
  "named/args/merge_bound_equivalent",
  "named/args/merge_literal_equivalent",
  "named/args/or_literal_equivalent",
  "named/args/having",
  "named/args/having_and",
  "named/args/having_or",
  "named/array/where",
  "named/array/and_after",
  "named/array/and_before",
  "named/array/or",
  "named/array/or_reverse",
  "named/array/not",
  "named/array/not_and",
  "named/array/merge",
  "named/array/merge_reverse",
  "named/array/merge_duplicate",
  "named/array/merge_bound_equivalent",
  "named/array/merge_literal_equivalent",
  "named/array/or_literal_equivalent",
  "named/array/having",
  "named/array/having_and",
  "named/array/having_or",
  "positional_or/args/where",
  "positional_or/args/and_after",
  "positional_or/args/and_before",
  "positional_or/args/or",
  "positional_or/args/or_reverse",
  "positional_or/args/not",
  "positional_or/args/not_and",
  "positional_or/args/merge",
  "positional_or/args/merge_reverse",
  "positional_or/args/merge_duplicate",
  "positional_or/args/merge_bound_equivalent",
  "positional_or/args/merge_literal_equivalent",
  "positional_or/args/or_literal_equivalent",
  "positional_or/args/having",
  "positional_or/args/having_and",
  "positional_or/args/having_or",
  "positional_or/array/where",
  "positional_or/array/and_after",
  "positional_or/array/and_before",
  "positional_or/array/or",
  "positional_or/array/or_reverse",
  "positional_or/array/not",
  "positional_or/array/not_and",
  "positional_or/array/merge",
  "positional_or/array/merge_reverse",
  "positional_or/array/merge_duplicate",
  "positional_or/array/merge_bound_equivalent",
  "positional_or/array/merge_literal_equivalent",
  "positional_or/array/or_literal_equivalent",
  "positional_or/array/having",
  "positional_or/array/having_and",
  "positional_or/array/having_or",
  "named_or/args/where",
  "named_or/args/and_after",
  "named_or/args/and_before",
  "named_or/args/or",
  "named_or/args/or_reverse",
  "named_or/args/not",
  "named_or/args/not_and",
  "named_or/args/merge",
  "named_or/args/merge_reverse",
  "named_or/args/merge_duplicate",
  "named_or/args/merge_bound_equivalent",
  "named_or/args/merge_literal_equivalent",
  "named_or/args/or_literal_equivalent",
  "named_or/args/having",
  "named_or/args/having_and",
  "named_or/args/having_or",
  "named_or/array/where",
  "named_or/array/and_after",
  "named_or/array/and_before",
  "named_or/array/or",
  "named_or/array/or_reverse",
  "named_or/array/not",
  "named_or/array/not_and",
  "named_or/array/merge",
  "named_or/array/merge_reverse",
  "named_or/array/merge_duplicate",
  "named_or/array/merge_bound_equivalent",
  "named_or/array/merge_literal_equivalent",
  "named_or/array/or_literal_equivalent",
  "named_or/array/having",
  "named_or/array/having_and",
  "named_or/array/having_or",
  "positional_parens/args/where",
  "positional_parens/args/and_after",
  "positional_parens/args/and_before",
  "positional_parens/args/or",
  "positional_parens/args/or_reverse",
  "positional_parens/args/not",
  "positional_parens/args/not_and",
  "positional_parens/args/merge",
  "positional_parens/args/merge_reverse",
  "positional_parens/args/merge_duplicate",
  "positional_parens/args/merge_bound_equivalent",
  "positional_parens/args/merge_literal_equivalent",
  "positional_parens/args/or_literal_equivalent",
  "positional_parens/args/having",
  "positional_parens/args/having_and",
  "positional_parens/args/having_or",
  "positional_parens/array/where",
  "positional_parens/array/and_after",
  "positional_parens/array/and_before",
  "positional_parens/array/or",
  "positional_parens/array/or_reverse",
  "positional_parens/array/not",
  "positional_parens/array/not_and",
  "positional_parens/array/merge",
  "positional_parens/array/merge_reverse",
  "positional_parens/array/merge_duplicate",
  "positional_parens/array/merge_bound_equivalent",
  "positional_parens/array/merge_literal_equivalent",
  "positional_parens/array/or_literal_equivalent",
  "positional_parens/array/having",
  "positional_parens/array/having_and",
  "positional_parens/array/having_or",
  "named_parens/args/where",
  "named_parens/args/and_after",
  "named_parens/args/and_before",
  "named_parens/args/or",
  "named_parens/args/or_reverse",
  "named_parens/args/not",
  "named_parens/args/not_and",
  "named_parens/args/merge",
  "named_parens/args/merge_reverse",
  "named_parens/args/merge_duplicate",
  "named_parens/args/merge_bound_equivalent",
  "named_parens/args/merge_literal_equivalent",
  "named_parens/args/or_literal_equivalent",
  "named_parens/args/having",
  "named_parens/args/having_and",
  "named_parens/args/having_or",
  "named_parens/array/where",
  "named_parens/array/and_after",
  "named_parens/array/and_before",
  "named_parens/array/or",
  "named_parens/array/or_reverse",
  "named_parens/array/not",
  "named_parens/array/not_and",
  "named_parens/array/merge",
  "named_parens/array/merge_reverse",
  "named_parens/array/merge_duplicate",
  "named_parens/array/merge_bound_equivalent",
  "named_parens/array/merge_literal_equivalent",
  "named_parens/array/or_literal_equivalent",
  "named_parens/array/having",
  "named_parens/array/having_and",
  "named_parens/array/having_or",
  "positional_line/args/where",
  "positional_line/args/and_after",
  "positional_line/args/and_before",
  "positional_line/args/or",
  "positional_line/args/or_reverse",
  "positional_line/args/not",
  "positional_line/args/not_and",
  "positional_line/args/merge",
  "positional_line/args/merge_reverse",
  "positional_line/args/merge_duplicate",
  "positional_line/args/merge_bound_equivalent",
  "positional_line/args/merge_literal_equivalent",
  "positional_line/args/or_literal_equivalent",
  "positional_line/args/having",
  "positional_line/args/having_and",
  "positional_line/args/having_or",
  "positional_line/array/where",
  "positional_line/array/and_after",
  "positional_line/array/and_before",
  "positional_line/array/or",
  "positional_line/array/or_reverse",
  "positional_line/array/not",
  "positional_line/array/not_and",
  "positional_line/array/merge",
  "positional_line/array/merge_reverse",
  "positional_line/array/merge_duplicate",
  "positional_line/array/merge_bound_equivalent",
  "positional_line/array/merge_literal_equivalent",
  "positional_line/array/or_literal_equivalent",
  "positional_line/array/having",
  "positional_line/array/having_and",
  "positional_line/array/having_or",
  "named_line/args/where",
  "named_line/args/and_after",
  "named_line/args/and_before",
  "named_line/args/or",
  "named_line/args/or_reverse",
  "named_line/args/not",
  "named_line/args/not_and",
  "named_line/args/merge",
  "named_line/args/merge_reverse",
  "named_line/args/merge_duplicate",
  "named_line/args/merge_bound_equivalent",
  "named_line/args/merge_literal_equivalent",
  "named_line/args/or_literal_equivalent",
  "named_line/args/having",
  "named_line/args/having_and",
  "named_line/args/having_or",
  "named_line/array/where",
  "named_line/array/and_after",
  "named_line/array/and_before",
  "named_line/array/or",
  "named_line/array/or_reverse",
  "named_line/array/not",
  "named_line/array/not_and",
  "named_line/array/merge",
  "named_line/array/merge_reverse",
  "named_line/array/merge_duplicate",
  "named_line/array/merge_bound_equivalent",
  "named_line/array/merge_literal_equivalent",
  "named_line/array/or_literal_equivalent",
  "named_line/array/having",
  "named_line/array/having_and",
  "named_line/array/having_or",
  "positional_block/args/where",
  "positional_block/args/and_after",
  "positional_block/args/and_before",
  "positional_block/args/or",
  "positional_block/args/or_reverse",
  "positional_block/args/not",
  "positional_block/args/not_and",
  "positional_block/args/merge",
  "positional_block/args/merge_reverse",
  "positional_block/args/merge_duplicate",
  "positional_block/args/merge_bound_equivalent",
  "positional_block/args/merge_literal_equivalent",
  "positional_block/args/or_literal_equivalent",
  "positional_block/args/having",
  "positional_block/args/having_and",
  "positional_block/args/having_or",
  "positional_block/array/where",
  "positional_block/array/and_after",
  "positional_block/array/and_before",
  "positional_block/array/or",
  "positional_block/array/or_reverse",
  "positional_block/array/not",
  "positional_block/array/not_and",
  "positional_block/array/merge",
  "positional_block/array/merge_reverse",
  "positional_block/array/merge_duplicate",
  "positional_block/array/merge_bound_equivalent",
  "positional_block/array/merge_literal_equivalent",
  "positional_block/array/or_literal_equivalent",
  "positional_block/array/having",
  "positional_block/array/having_and",
  "positional_block/array/having_or",
  "named_block/args/where",
  "named_block/args/and_after",
  "named_block/args/and_before",
  "named_block/args/or",
  "named_block/args/or_reverse",
  "named_block/args/not",
  "named_block/args/not_and",
  "named_block/args/merge",
  "named_block/args/merge_reverse",
  "named_block/args/merge_duplicate",
  "named_block/args/merge_bound_equivalent",
  "named_block/args/merge_literal_equivalent",
  "named_block/args/or_literal_equivalent",
  "named_block/args/having",
  "named_block/args/having_and",
  "named_block/args/having_or",
  "named_block/array/where",
  "named_block/array/and_after",
  "named_block/array/and_before",
  "named_block/array/or",
  "named_block/array/or_reverse",
  "named_block/array/not",
  "named_block/array/not_and",
  "named_block/array/merge",
  "named_block/array/merge_reverse",
  "named_block/array/merge_duplicate",
  "named_block/array/merge_bound_equivalent",
  "named_block/array/merge_literal_equivalent",
  "named_block/array/or_literal_equivalent",
  "named_block/array/having",
  "named_block/array/having_and",
  "named_block/array/having_or",
  "comment_question/args/where",
  "comment_question/args/and_after",
  "comment_question/args/and_before",
  "comment_question/args/or",
  "comment_question/args/or_reverse",
  "comment_question/args/not",
  "comment_question/args/not_and",
  "comment_question/args/merge",
  "comment_question/args/merge_reverse",
  "comment_question/args/merge_duplicate",
  "comment_question/args/merge_bound_equivalent",
  "comment_question/args/merge_literal_equivalent",
  "comment_question/args/or_literal_equivalent",
  "comment_question/args/having",
  "comment_question/args/having_and",
  "comment_question/args/having_or",
  "comment_question/array/where",
  "comment_question/array/and_after",
  "comment_question/array/and_before",
  "comment_question/array/or",
  "comment_question/array/or_reverse",
  "comment_question/array/not",
  "comment_question/array/not_and",
  "comment_question/array/merge",
  "comment_question/array/merge_reverse",
  "comment_question/array/merge_duplicate",
  "comment_question/array/merge_bound_equivalent",
  "comment_question/array/merge_literal_equivalent",
  "comment_question/array/or_literal_equivalent",
  "comment_question/array/having",
  "comment_question/array/having_and",
  "comment_question/array/having_or",
  "comment_named/args/where",
  "comment_named/args/and_after",
  "comment_named/args/and_before",
  "comment_named/args/or",
  "comment_named/args/or_reverse",
  "comment_named/args/not",
  "comment_named/args/not_and",
  "comment_named/args/merge",
  "comment_named/args/merge_reverse",
  "comment_named/args/merge_duplicate",
  "comment_named/args/merge_bound_equivalent",
  "comment_named/args/merge_literal_equivalent",
  "comment_named/args/or_literal_equivalent",
  "comment_named/args/having",
  "comment_named/args/having_and",
  "comment_named/args/having_or",
  "comment_named/array/where",
  "comment_named/array/and_after",
  "comment_named/array/and_before",
  "comment_named/array/or",
  "comment_named/array/or_reverse",
  "comment_named/array/not",
  "comment_named/array/not_and",
  "comment_named/array/merge",
  "comment_named/array/merge_reverse",
  "comment_named/array/merge_duplicate",
  "comment_named/array/merge_bound_equivalent",
  "comment_named/array/merge_literal_equivalent",
  "comment_named/array/or_literal_equivalent",
  "comment_named/array/having",
  "comment_named/array/having_and",
  "comment_named/array/having_or",
  "no_values_empty/args/where",
  "no_values_empty/args/and_after",
  "no_values_empty/args/and_before",
  "no_values_empty/args/or",
  "no_values_empty/args/or_reverse",
  "no_values_empty/args/not",
  "no_values_empty/args/not_and",
  "no_values_empty/args/merge",
  "no_values_empty/args/merge_reverse",
  "no_values_empty/args/merge_duplicate",
  "no_values_empty/args/merge_bound_equivalent",
  "no_values_empty/args/merge_literal_equivalent",
  "no_values_empty/args/or_literal_equivalent",
  "no_values_empty/args/having",
  "no_values_empty/args/having_and",
  "no_values_empty/args/having_or",
  "no_values_empty/array/where",
  "no_values_empty/array/and_after",
  "no_values_empty/array/and_before",
  "no_values_empty/array/or",
  "no_values_empty/array/or_reverse",
  "no_values_empty/array/not",
  "no_values_empty/array/not_and",
  "no_values_empty/array/merge",
  "no_values_empty/array/merge_reverse",
  "no_values_empty/array/merge_duplicate",
  "no_values_empty/array/merge_bound_equivalent",
  "no_values_empty/array/merge_literal_equivalent",
  "no_values_empty/array/or_literal_equivalent",
  "no_values_empty/array/having",
  "no_values_empty/array/having_and",
  "no_values_empty/array/having_or",
  "no_values_space/args/where",
  "no_values_space/args/and_after",
  "no_values_space/args/and_before",
  "no_values_space/args/or",
  "no_values_space/args/or_reverse",
  "no_values_space/args/not",
  "no_values_space/args/not_and",
  "no_values_space/args/merge",
  "no_values_space/args/merge_reverse",
  "no_values_space/args/merge_duplicate",
  "no_values_space/args/merge_bound_equivalent",
  "no_values_space/args/merge_literal_equivalent",
  "no_values_space/args/or_literal_equivalent",
  "no_values_space/args/having",
  "no_values_space/args/having_and",
  "no_values_space/args/having_or",
  "no_values_space/array/where",
  "no_values_space/array/and_after",
  "no_values_space/array/and_before",
  "no_values_space/array/or",
  "no_values_space/array/or_reverse",
  "no_values_space/array/not",
  "no_values_space/array/not_and",
  "no_values_space/array/merge",
  "no_values_space/array/merge_reverse",
  "no_values_space/array/merge_duplicate",
  "no_values_space/array/merge_bound_equivalent",
  "no_values_space/array/merge_literal_equivalent",
  "no_values_space/array/or_literal_equivalent",
  "no_values_space/array/having",
  "no_values_space/array/having_and",
  "no_values_space/array/having_or",
  "no_values_literal/args/where",
  "no_values_literal/args/and_after",
  "no_values_literal/args/and_before",
  "no_values_literal/args/or",
  "no_values_literal/args/or_reverse",
  "no_values_literal/args/not",
  "no_values_literal/args/not_and",
  "no_values_literal/args/merge",
  "no_values_literal/args/merge_reverse",
  "no_values_literal/args/merge_duplicate",
  "no_values_literal/args/merge_bound_equivalent",
  "no_values_literal/args/merge_literal_equivalent",
  "no_values_literal/args/or_literal_equivalent",
  "no_values_literal/args/having",
  "no_values_literal/args/having_and",
  "no_values_literal/args/having_or",
  "no_values_literal/array/where",
  "no_values_literal/array/and_after",
  "no_values_literal/array/and_before",
  "no_values_literal/array/or",
  "no_values_literal/array/or_reverse",
  "no_values_literal/array/not",
  "no_values_literal/array/not_and",
  "no_values_literal/array/merge",
  "no_values_literal/array/merge_reverse",
  "no_values_literal/array/merge_duplicate",
  "no_values_literal/array/merge_bound_equivalent",
  "no_values_literal/array/merge_literal_equivalent",
  "no_values_literal/array/or_literal_equivalent",
  "no_values_literal/array/having",
  "no_values_literal/array/having_and",
  "no_values_literal/array/having_or",
  "no_values_or/args/where",
  "no_values_or/args/and_after",
  "no_values_or/args/and_before",
  "no_values_or/args/or",
  "no_values_or/args/or_reverse",
  "no_values_or/args/not",
  "no_values_or/args/not_and",
  "no_values_or/args/merge",
  "no_values_or/args/merge_reverse",
  "no_values_or/args/merge_duplicate",
  "no_values_or/args/merge_bound_equivalent",
  "no_values_or/args/merge_literal_equivalent",
  "no_values_or/args/or_literal_equivalent",
  "no_values_or/args/having",
  "no_values_or/args/having_and",
  "no_values_or/args/having_or",
  "no_values_or/array/where",
  "no_values_or/array/and_after",
  "no_values_or/array/and_before",
  "no_values_or/array/or",
  "no_values_or/array/or_reverse",
  "no_values_or/array/not",
  "no_values_or/array/not_and",
  "no_values_or/array/merge",
  "no_values_or/array/merge_reverse",
  "no_values_or/array/merge_duplicate",
  "no_values_or/array/merge_bound_equivalent",
  "no_values_or/array/merge_literal_equivalent",
  "no_values_or/array/or_literal_equivalent",
  "no_values_or/array/having",
  "no_values_or/array/having_and",
  "no_values_or/array/having_or",
  "no_values_line/args/where",
  "no_values_line/args/and_after",
  "no_values_line/args/and_before",
  "no_values_line/args/or",
  "no_values_line/args/or_reverse",
  "no_values_line/args/not",
  "no_values_line/args/not_and",
  "no_values_line/args/merge",
  "no_values_line/args/merge_reverse",
  "no_values_line/args/merge_duplicate",
  "no_values_line/args/merge_bound_equivalent",
  "no_values_line/args/merge_literal_equivalent",
  "no_values_line/args/or_literal_equivalent",
  "no_values_line/args/having",
  "no_values_line/args/having_and",
  "no_values_line/args/having_or",
  "no_values_line/array/where",
  "no_values_line/array/and_after",
  "no_values_line/array/and_before",
  "no_values_line/array/or",
  "no_values_line/array/or_reverse",
  "no_values_line/array/not",
  "no_values_line/array/not_and",
  "no_values_line/array/merge",
  "no_values_line/array/merge_reverse",
  "no_values_line/array/merge_duplicate",
  "no_values_line/array/merge_bound_equivalent",
  "no_values_line/array/merge_literal_equivalent",
  "no_values_line/array/or_literal_equivalent",
  "no_values_line/array/having",
  "no_values_line/array/having_and",
  "no_values_line/array/having_or",
  "arel_literal/args/where",
  "arel_literal/args/and_after",
  "arel_literal/args/and_before",
  "arel_literal/args/or",
  "arel_literal/args/or_reverse",
  "arel_literal/args/not",
  "arel_literal/args/not_and",
  "arel_literal/args/merge",
  "arel_literal/args/merge_reverse",
  "arel_literal/args/merge_duplicate",
  "arel_literal/args/merge_bound_equivalent",
  "arel_literal/args/merge_literal_equivalent",
  "arel_literal/args/or_literal_equivalent",
  "arel_literal/args/having",
  "arel_literal/args/having_and",
  "arel_literal/args/having_or",
  "arel_literal/array/where",
  "arel_literal/array/and_after",
  "arel_literal/array/and_before",
  "arel_literal/array/or",
  "arel_literal/array/or_reverse",
  "arel_literal/array/not",
  "arel_literal/array/not_and",
  "arel_literal/array/merge",
  "arel_literal/array/merge_reverse",
  "arel_literal/array/merge_duplicate",
  "arel_literal/array/merge_bound_equivalent",
  "arel_literal/array/merge_literal_equivalent",
  "arel_literal/array/or_literal_equivalent",
  "arel_literal/array/having",
  "arel_literal/array/having_and",
  "arel_literal/array/having_or",
  "arel_bound/args/where",
  "arel_bound/args/and_after",
  "arel_bound/args/and_before",
  "arel_bound/args/or",
  "arel_bound/args/or_reverse",
  "arel_bound/args/not",
  "arel_bound/args/not_and",
  "arel_bound/args/merge",
  "arel_bound/args/merge_reverse",
  "arel_bound/args/merge_duplicate",
  "arel_bound/args/merge_bound_equivalent",
  "arel_bound/args/merge_literal_equivalent",
  "arel_bound/args/or_literal_equivalent",
  "arel_bound/args/having",
  "arel_bound/args/having_and",
  "arel_bound/args/having_or",
  "arel_bound/array/where",
  "arel_bound/array/and_after",
  "arel_bound/array/and_before",
  "arel_bound/array/or",
  "arel_bound/array/or_reverse",
  "arel_bound/array/not",
  "arel_bound/array/not_and",
  "arel_bound/array/merge",
  "arel_bound/array/merge_reverse",
  "arel_bound/array/merge_duplicate",
  "arel_bound/array/merge_bound_equivalent",
  "arel_bound/array/merge_literal_equivalent",
  "arel_bound/array/or_literal_equivalent",
  "arel_bound/array/having",
  "arel_bound/array/having_and",
  "arel_bound/array/having_or",
  "arel_bound_extra/args/where",
  "arel_bound_extra/args/and_after",
  "arel_bound_extra/args/and_before",
  "arel_bound_extra/args/or",
  "arel_bound_extra/args/or_reverse",
  "arel_bound_extra/args/not",
  "arel_bound_extra/args/not_and",
  "arel_bound_extra/args/merge",
  "arel_bound_extra/args/merge_reverse",
  "arel_bound_extra/args/merge_duplicate",
  "arel_bound_extra/args/merge_bound_equivalent",
  "arel_bound_extra/args/merge_literal_equivalent",
  "arel_bound_extra/args/or_literal_equivalent",
  "arel_bound_extra/args/having",
  "arel_bound_extra/args/having_and",
  "arel_bound_extra/args/having_or",
  "arel_bound_extra/array/where",
  "arel_bound_extra/array/and_after",
  "arel_bound_extra/array/and_before",
  "arel_bound_extra/array/or",
  "arel_bound_extra/array/or_reverse",
  "arel_bound_extra/array/not",
  "arel_bound_extra/array/not_and",
  "arel_bound_extra/array/merge",
  "arel_bound_extra/array/merge_reverse",
  "arel_bound_extra/array/merge_duplicate",
  "arel_bound_extra/array/merge_bound_equivalent",
  "arel_bound_extra/array/merge_literal_equivalent",
  "arel_bound_extra/array/or_literal_equivalent",
  "arel_bound_extra/array/having",
  "arel_bound_extra/array/having_and",
  "arel_bound_extra/array/having_or",
  "arel_merge_equivalent/args/where",
  "arel_merge_equivalent/args/and_after",
  "arel_merge_equivalent/args/and_before",
  "arel_merge_equivalent/args/or",
  "arel_merge_equivalent/args/or_reverse",
  "arel_merge_equivalent/args/not",
  "arel_merge_equivalent/args/not_and",
  "arel_merge_equivalent/args/merge",
  "arel_merge_equivalent/args/merge_reverse",
  "arel_merge_equivalent/args/merge_duplicate",
  "arel_merge_equivalent/args/merge_bound_equivalent",
  "arel_merge_equivalent/args/merge_literal_equivalent",
  "arel_merge_equivalent/args/or_literal_equivalent",
  "arel_merge_equivalent/args/having",
  "arel_merge_equivalent/args/having_and",
  "arel_merge_equivalent/args/having_or",
  "arel_merge_equivalent/array/where",
  "arel_merge_equivalent/array/and_after",
  "arel_merge_equivalent/array/and_before",
  "arel_merge_equivalent/array/or",
  "arel_merge_equivalent/array/or_reverse",
  "arel_merge_equivalent/array/not",
  "arel_merge_equivalent/array/not_and",
  "arel_merge_equivalent/array/merge",
  "arel_merge_equivalent/array/merge_reverse",
  "arel_merge_equivalent/array/merge_duplicate",
  "arel_merge_equivalent/array/merge_bound_equivalent",
  "arel_merge_equivalent/array/merge_literal_equivalent",
  "arel_merge_equivalent/array/or_literal_equivalent",
  "arel_merge_equivalent/array/having",
  "arel_merge_equivalent/array/having_and",
  "arel_merge_equivalent/array/having_or",
  "arel_node/args/where",
  "arel_node/args/and_after",
  "arel_node/args/and_before",
  "arel_node/args/or",
  "arel_node/args/or_reverse",
  "arel_node/args/not",
  "arel_node/args/not_and",
  "arel_node/args/merge",
  "arel_node/args/merge_reverse",
  "arel_node/args/merge_duplicate",
  "arel_node/args/merge_bound_equivalent",
  "arel_node/args/merge_literal_equivalent",
  "arel_node/args/or_literal_equivalent",
  "arel_node/args/having",
  "arel_node/args/having_and",
  "arel_node/args/having_or",
  "arel_node/array/where",
  "arel_node/array/and_after",
  "arel_node/array/and_before",
  "arel_node/array/or",
  "arel_node/array/or_reverse",
  "arel_node/array/not",
  "arel_node/array/not_and",
  "arel_node/array/merge",
  "arel_node/array/merge_reverse",
  "arel_node/array/merge_duplicate",
  "arel_node/array/merge_bound_equivalent",
  "arel_node/array/merge_literal_equivalent",
  "arel_node/array/or_literal_equivalent",
  "arel_node/array/having",
  "arel_node/array/having_and",
  "arel_node/array/having_or"
]
```
