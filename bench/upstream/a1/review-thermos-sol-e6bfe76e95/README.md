# A1 at e6bfe76e95: approve

Reviewer: `thermos-sol`, 2026-11-18, thread `T-01a1ec9b-362a-7743-b700-c72c8999d286`.
Both Thermos rubrics were loaded and applied by this reviewer here, as requested, without subagents or other
threads. This is a thorough single-reviewer confirm pass, not two independent reviewers.

**No must-fixes found on the narrowed head.** The actual change is one empty-scope-items guard in `join_scope`;
the association reader is unchanged from main. The two former third-answer cases now match main. The original
unscoped join regressions match 8.1. The added adversarial matrix found no result on head matching neither main
nor 8.1. The test is genuinely red/green and now kills the default-scope-drop mutation. Commit, body, note and
changelog no longer have the prior publication defects.

This approves the reviewed correctness patch and current text, not opening/posting it or claiming speed. No
Rails source was edited, no Rails-fork push was made and nothing was posted upstream. The only delivered edits
are these Lowrail receipts and an A1 queue pass. Queue state and separate opening gates are not changed here.

## Pins and actual environment

| Tree | Commit |
| --- | --- |
| 8-1-stable | `aab611acd84b4754e2403a9ab005532ccb0ed374` |
| Merge parent | `f0c9373b05dd151fce6a28ba30d7cc8b376ea35e` |
| Owner-condition configuration merge | `ff53633d52d7f429d08a6250693cd74a0090c24c` |
| Requested main | `e30c36266b48016e74422e987dd46e85cacbeea8` |
| Reviewed fork head | `e6bfe76e9599baed1b51030634566302f90a2151` |

The fork branch was fetched and its remote ref independently checked at the reviewed SHA. The head is exactly
one commit on requested main. Full history was fetched before history inspection. [Pins](raw/pins.txt) include
the merge's actual reflection diff and identical head/main association-reader blobs. [Patch](raw/candidate.diff),
[message/identity](raw/commit.txt), and [sentence audit](claims-audit.md) retain the reviewed material.

Ruby 4.0.9 (`3e93b23afc`), SQLite 3.54.1 / sqlite3 2.10.2, PostgreSQL server 17.12 / pg 1.7.0 / libpq 18.0.6,
minitest 6.1.0 with minitest-mock 5.27.0. Each tree supplies its own Rails sources, not an installed Rails gem.
Databases are disposable local PostgreSQL test databases, not an app database. No MySQL, JRuby, Ruby master,
YJIT/ZJIT or new performance run is claimed.

## Earlier probes rerun, all five trees

[`run_matrix.sh`](run_matrix.sh) executes the previous review's original/follow-up and scoped scripts unchanged.
Both adapters, KEEP 0/1 and WIDTH 16/17 are exercised (the two-predicate `linear_join` ignores WIDTH; the setting
is absent on 8.1). The new matrix runs `range_paths` at both widths as well. The unchanged old probes live in
`../followup-81` and `../review-thermos-sol-80daecf52a`; they have not been replaced with weaker equivalents.

| Probe/result at width 17 | Head | 8.1 | Main |
| --- | --- | --- | --- |
| Original composite-key reader | `[1]` | `[2]` | `[1]` |
| Original polymorphic join | `k0=101` | `k0=101` | `k0=1` |
| Plain/polymorphic built-in out-of-range joins | no rows, SQL `1=0` | same | `ActiveModel::RangeError` |
| Unrestricted eager load / includes.references | one parent, zero children | same | range error |
| Scoped hash/context-dependent reader | record `[35]` | `[44]` | `[35]` |
| No-scope reader with extension | record `[2]` | `[3]` | `[2]` |
| Scoped join removing bad default condition | range error | parent `[1]` | range error |

The head no longer produces former-head records 69 or 4. All four scoped groups (`scoped`, `scoped-order`,
`scoped-effects`, `scoped-hash`) are **byte-identical to main**, independently on both adapters. Every original
matrix section equals either main or 8.1; [comparison](raw/comparison.txt) identifies the parent/merge groups too.
Width-16 controls match the expected old behavior. The two-predicate equality-sensitive join remains a real
behavior change even at WIDTH=16, since that probe has no width dependence.

**Known limitations remain accurately excluded:** readers/preload with out-of-range values and the scoped
out-of-range `unscope` regression are not fixed. An unfiltered eager load is an outer join and retains its
parent; it must not be described as an empty parent result. None of these is introduced by this head.

## Added adversarial join matrix

[`adversarial_joins.rb`](adversarial_joins.rb) and [`run_adversarial.sh`](run_adversarial.sh) exercise:

- Plain `has_many`, polymorphic `as:`, STI targets, 16/17-column composite keys, association extensions,
  through, extended through, scoped through, STI through and nested through.
- `joins`, `left_joins`, `eager_load`, `includes.references` and `where.associated`.
- Ordinary finite defaults, an out-of-range integer default, and a context-dependent custom integer serializer
  whose phase is changed by a later joined association scope.
- Scoped `all`, scoped `unscope(:where)` and polymorphic-type replacement controls, KEEP 0/1, both widths and
  both adapters, on each of the five pinned revisions.

There are 13 association shapes × 5 operations × 2 flags = 130 observations per mode/width/adapter/revision;
**1,560 head observations, 7,800 across all five trees**. Output records actual parent IDs (including duplicate
join rows), eagerly loaded child labels, extension hook count, or actual exception class/message. Seed data
includes another owner, another polymorphic type, a base versus STI child, an out-of-default child, and distinct
`k0=1`/`101` rows. Thus merely dropping conditions or conflating outer/inner joins does not pass unnoticed.

| Mode | Width | Head observations per adapter | Different from main | Neither main nor 8.1 |
| --- | ---: | ---: | ---: | ---: |
| Finite | 16 | 130 | 0 | 0 |
| Finite | 17 | 130 | 0 | 0 |
| Range | 16 | 130 | 20 | 0 |
| Range | 17 | 130 | 90 | 0 |
| Phase-dependent | 16 | 130 | 0 | 0 |
| Phase-dependent | 17 | 130 | 12 | 0 |

Both adapters have this same summary. The extra width-16 range fixes are STI cases: its extra discriminator
predicate crosses the relevant comparison boundary even with 16 default predicates. Do not generalize the
plain-association width control into a universal 17-column Rails contract. Only expected `ActiveModel::RangeError`
exceptions occur in the matrix, not load errors or broken harness cases. Finite and phase cases have no errors.

[`compare.py`](compare.py) checks the original grouping and scoped identity, then lists all added cases whose
head answer matches neither reference; there are none. This is finite evidence, not proof that arbitrary
effectful custom types across all Rails features now have universal 8.1 semantics.

The original ordinary warning-sensitive and composite/disable-joins probes also reran unchanged on SQLite:
`ordinary-head-0.txt` is identical to main (334 lines, 14 deprecation warnings), `ordinary-head-1.txt` identical
(320 lines, none), and `cpk-head.txt` identical. This additionally checks warnings, original SQL and writes, not
just the new probe's loaded records. Those older scripts hard-code SQLite; the new matrix and full suites test
PostgreSQL rather than falsely claiming that setting ADAPTER changes the older scripts.

## Added test and conventions

[`targeted_test.rb`](targeted_test.rb) extracts the exact added class, loads each tree's test helpers and applies
KEEP explicitly when that setting exists. [`run_targeted.sh`](run_targeted.sh) retains every adapter/setting log.

| Tree | Each adapter and setting |
| --- | --- |
| Main | 1 test, 1 error: expected `ActiveModel::RangeError` |
| 8.1 | 1 test, 4 assertions, pass |
| Head | 1 test, 4 assertions, pass |
| Head, default scope removed | 1 test, 1 failure: joined parent returned |

The matching child row is now seeded. Removing the entire default scope therefore cannot pass merely because
the child table is empty. Both original assertions stay in the tested class. The filtered eager-load assertion
is allowed to return no parents because it rejects null child IDs; this is not an assertion about unrestricted
outer joins. `assert_empty` exercises the relation's public empty?/exists? contract, not necessarily full loading;
the added matrix separately forces `to_a` and inspects loaded collections.

Anonymous classes/`anonymous_class`, isolated table names, nontransactional DDL with teardown, descriptive test
name and existing has-many test location match surrounding Rails practice. The single added threshold comment
explains otherwise surprising test width and is justified; no implementation comments were added to public APIs.
The test and implementation files were already over 1,000 lines (3,713 → 3,751 and 1,628 → 1,630), so no new
decomposition threshold was crossed. The CHANGELOG is correctly at the top and correctly formatted/credited.

## Full head suites, warnings enabled

[`run_suites.sh`](run_suites.sh) records the exact command over every requested association, reflection,
relation/relations and scoping test file. Both final commands exit 0:

| Adapter | Runs | Assertions | Failures | Errors | Skips |
| --- | ---: | ---: | ---: | ---: | ---: |
| SQLite | 3,271 | 10,741 | 0 | 0 | 1 |
| PostgreSQL | 3,276 | 10,754 | 0 | 0 | 0 |

[SQLite log](raw/tests-head-sqlite3.txt), [PostgreSQL log](raw/tests-head-postgresql.txt).
The one SQLite skip is `ActiveRecord::WhereTest#test_with_tuple_syntax_and_large_values_list`, explicitly guarded
for SQLite's expression-tree limit; [isolated verbose run](raw/sqlite-skip.txt).

The first full run on each adapter hit missing optional test dependency `builder` in `RelationTest#test_to_xml`:
those actual failures are retained as `tests-head-*-missing-builder.txt`. Installed builder 3.3.0 and reran both
complete suites, without suppressing or editing tests. The earlier test harness also needed minitest-mock, which
was installed before these full runs. No application behavior was patched to make the environment pass.

## Maintainability / cold read

“Build the class/default and route constraints. If there are association scope items, compare and merge them
exactly as before; otherwise there is nothing to compare. Then add the route key equalities.” One existing
block gains one direct empty-items guard. No new helper, cached state, copied method, fallback mode or scattered
special case is introduced. The guard is at the source of the unnecessary/effectful operation, not a wrapper.
Moving it into the existing `keep_owner_conditions` helper would be too late to skip the first difference.
There is no demonstrated shorter structure that preserves this boundary and scoped order.

Metrics on the extracted same method, flog 4.9.4 and RuboCop 1.92.3 (metric maxima deliberately zero to print the
values, not normal style failures): flog 31.1 → 33.6; ABC 26.91 → 27.89; cyclomatic 3 → 4; perceived 3 → 4.
[Main](raw/metrics-main.txt), [head](raw/metrics-head.txt). The small increase is the explicit, necessary branch
separating the two semantic cases; another abstraction would obscure rather than simplify it. No whole-project
RuboCop pass or claim of style-check success is made.

## Text audit and remaining gates

[Sentence-by-sentence audit](claims-audit.md) covers the sole commit, queue title/body and note, plus the main
README's historical caveats and CHANGELOG follow-through. The correctness body contains no performance numbers,
suite metadata or process footer; the note has no unsolicited cost paragraph. Numeric reproducer inputs are
necessary to trigger the bug, not unasked measurements. No must-fix from either Thermos rubric or text audit.

The historical micro and request numbers were not rerun or recertified for this head. Reader savings are gone;
this review makes no speed claim. Ruby-master/JIT evidence and a separate decision to publish remain outside
this pass. No upstream comment was posted; Thomas must still approve the exact note if it is used.

## Reproduction

From Lowrail root, with the five Rails trees and Ruby dependencies installed and disposable PostgreSQL databases
`a1_review_probe`, `activerecord_unittest` and `activerecord_unittest2` available:

```sh
bash bench/upstream/a1/review-thermos-sol-e6bfe76e95/run_matrix.sh \
  stable="$PWD/.amp/in/orb-backup/rails-stable" parent="$PWD/.amp/in/orb-backup/rails-parent" \
  merge="$PWD/.amp/in/orb-backup/rails-merge" main="$PWD/.amp/in/orb-backup/rails-main" head="$PWD/.amp/in/orb-backup/rails"
# Same arguments for run_adversarial.sh.
bash bench/upstream/a1/review-thermos-sol-e6bfe76e95/run_targeted.sh \
  stable="$PWD/.amp/in/orb-backup/rails-stable" main="$PWD/.amp/in/orb-backup/rails-main" head="$PWD/.amp/in/orb-backup/rails"
MUTATION=drop_default_scope bash bench/upstream/a1/review-thermos-sol-e6bfe76e95/run_targeted.sh \
  mutation="$PWD/.amp/in/orb-backup/rails"
bash bench/upstream/a1/review-thermos-sol-e6bfe76e95/run_suites.sh "$PWD/.amp/in/orb-backup/rails"
python3 bench/upstream/a1/review-thermos-sol-e6bfe76e95/compare.py
```

Keep test suites on shared PostgreSQL test database names sequential. The normal probes create/drop only their
own test tables. No setup here requires writing to the fork or a production database.
