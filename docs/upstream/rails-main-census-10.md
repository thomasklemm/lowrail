# Rails-main census 10: main against 8-1-stable and census 9, after kamipo's association fixes

Census 10 compares Rails main [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff)
(2026-11-17) with 8-1-stable [`aab611acd8`](https://github.com/rails/rails/commit/aab611acd84b4754e2403a9ab005532ccb0ed374)
and with census 9's main [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b)
(2026-11-14), on Ruby 4.0.9, census 9's 8 apps and its method. Nothing was built or posted: rails/rails is at
our 15 open-PR cap. Ranking follows tonight's PR retrospective: unreleased regressions against 8.1 first, then
changes that move a whole request on their own.

**A1 update, 2026-11-18.** The census numbers below describe those historical pins, not today's main or the
effect of the open A1 PR. Its broad reader prototype was rejected; the current head changes only unscoped
`join_scope`. [The exact-head confirm](#a1-confirm-on-current-main-2026-11-18) approves that correctness fix
against current main, with no performance claim. The PR remains draft.

**Result.** Main is still faster than 8.1 in 67 of 70 workloads (median −5.95% of interpreted instructions, A/A median
0.12%; census 9 had −6.48%), and allocates a median 553 fewer objects per request. But **main is now slower than
census 9's main**: median +0.42%, 12 workloads slower beyond 1% (casa +1.14% median, up to +1.91%; writebook
+0.82%), against −1.78% for census 9 over census 8. Of main's +0.53% of all instructions, 0.26 points are lead A1 and
0.09 points lead C, both merged by kamipo on 2026-11-16 and 11-17.

Since census 9, main merged 22 first-parent commits ([list](data/rails-main-census-10/main-since-c9.txt)), nine of
them kamipo's Active Record merges of 2026-11-16 and 11-17. Two of them make every association load and every
association join more expensive, one adds to every through load and one to every `where` key: an association reader now builds five `WhereClause` differences and one Array to
check that its own scope did not remove the owner conditions, and a through association builds a second
`AliasTracker`. **That is new main regression against 8.1** in the interpreter: `author.posts` +3.6%, `has_one`
+5.3%, a polymorphic `as:` has_many +5.0%, `joins(:posts)` +5.6%, `joins` through +7.8% (A/A ≤ 0.1%). Under YJIT
main stays faster than 8.1, but these paths are +2.9% to +5.4% against census 9 in the JIT-flat cells. `WhereClause#-` is now the
largest allocation that main adds over 8.1: 56 of 70 workloads in all 8 apps, a median 0.56% of a request's objects
and up to 2.76% (casa's case edit page, +661 objects). The broad ceiling prototype recovered 70% of the extra
instructions and 10 of the 11 objects in the association micro, but was not exact; these are not savings of
the narrowed A1 PR. 8-1-stable moved by two backports that change no library code.

Every number is Callgrind instructions (Ir) per call or per request with census 8's patched Valgrind, a fixed heap
and an A/A twin. YJIT numbers count only where every measured window compiled nothing.

## Ranked leads

"8.1" is 8-1-stable `aab611acd8`, "c9" census 9's main `50c54eed06`. Shares are of all interpreted instructions or
objects per request in the workloads named. A/A is main against a second checkout of itself.

| # | Lead | Main file:line | Reach | Magnitude (A/A) | Against 8.1 | Existing PR / owner | Exact? | Next step |
| ---: | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **A1: owner-condition bookkeeping on every association scope** (#59825, #59836): five `WhereClause#-` and an Array per load, also on every `joins(:assoc)` | AR `association_scope.rb:62/68/131/162`, `reflection.rb:236–256` | Historical census reach, not PR savings: 8/8 apps, 56 of 70 workloads; `WhereClause#-`, `#empty?` and `keep_owner_conditions` +0.258% of all Ir vs c9 (max +0.87% per request); objects median 0.56%, max 2.76% (casa case edit, +661) | `author.posts` +2.7%, has_one +3.4%, `as:` +3.9%, `joins` +3.4% / +4.7%, +11 objects each vs c9 (A/A ≤ 0.1%); rejected ceiling recovered 70% of the extra instructions and 10 of 11 objects | **Historical regression:** has_many +3.6%, has_one +5.3%, `as:` +5.0%, `joins` +5.6%, `joins` through +7.8% (interp); YJIT still below 8.1 | kamipo, merged 2026-11-17; current PR #59851 | Broad prototype: no, effectful binds disprove exactness. Current PR: unscoped join correctness only | [Confirm approved on exact head](#a1-confirm-on-current-main-2026-11-18); no current performance claim, stays draft |
| 2 | **A2: a second `AliasTracker` per through load** (#59823) | AR `through_association.rb:39–51` | 5/8 apps, 19 workloads (`AliasTracker.create` +4.2 objects); +0.017% of all Ir | `author.comments` +3.6%, +6 objects at #59823 | No (main still −10.6% vs 8.1) | Our open #59569 removes the same tracker cost elsewhere | Probably (unaliased chain: `aliased_table_for` returns `arel_table`); not proved | After A1; or fold into #59569's follow-up |
| 3 | **C: block forwarding in `type_caster`/`type_for_attribute`** (#59816) | AR `arel/attributes/attribute.rb:12`, `arel/table.rb:112`, `type_caster/map.rb:15` | Every `where` key (2–3 calls); +0.094% of all Ir vs c9 (max +0.28%) | `where(title:)` +1.1%, three keys +1.8%, `group.count` +0.8% and +5 objects (interp); YJIT flat except `group_count` | Not alone (where still −0.8% to −7.9% vs 8.1) | kamipo, merged 2026-11-16; our #59607 removed a block here before | Yes | Low; mention with A1 |
| 4 | **Lead 8 (census 9): `table_name_qualified_unscope_values` per merge** (#59709) | AR `query_methods.rb:1066` | 8/8 apps, 56 workloads, +13.4 objects | Small | Yes, small | None | Yes (early return) | Fold into A1 |

Not leads, or already taken:

* **`pluck` +5.8% against 8.1** (400k → 424k Ir, 99 → 83 objects; YJIT −6.7%). The growth is about 150 more calls
  per `pluck`, all of them `QueryIntent`, the schema-context chain and the Ractor-safe class attributes
  ([calls, 8.1](data/rails-main-census-10/pluck-calls-s81.txt), [c9](data/rails-main-census-10/pluck-calls-c9.txt)),
  which [rails-82-impact](rails-82-impact.md) and [main-regressions](main-regressions.md) judged deliberate. #59816
  adds +4.6k on top (lead C).
* Census 9's leads that are queued, open or parked: K1 (#59800, open), K6 (#59804, open), L3 (reviewed), L6 (built,
  waits for K1), lead 4 (by-name access after #59141, tenderlove plans index-based generated methods), lead 5
  (partial-select reads), lead 7 (closed). `attribute_set.rb` and `indexed_row.rb` are unchanged since census 9, so
  their numbers stand.
* `bound_sql_literal_for(opts.to_s, rest)` (#59829) replaces one line of our CW1 (#59642); `String#to_s` returns the
  receiver, so it adds one call and no object.

## Lead A1: owner-condition bookkeeping on every association scope

**Site.** #59825 (`f620da3544`, kamipo, merged 2026-11-17 01:07 UTC) and #59836 (`ebf746c795`, kamipo, merged
2026-11-17 12:38 UTC). Every association scope build on main now does this ([main
`association_scope.rb:62/68/131/162`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/associations/association_scope.rb#L62),
[`reflection.rb:236–256`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/reflection.rb#L236-L256)):

* `last_chain_scope` computes `key_clause = scope.where_clause - where_clause` and returns `[scope, key_clause]`;
* `add_constraints` computes `fixed_clause = scope.where_clause - where_clause - key_clause` before it merges the
  association's own scope, then calls `keep_owner_conditions(scope, key_clause, fixed_clause)`;
* `keep_owner_conditions` computes `key_clause - scope.where_clause` and `type_clause - scope.where_clause` and
  returns when both are empty;
* `join_scope` (every `joins(:assoc)`, `eager_load`, `where.associated`) computes `fixed_clause` and calls
  `keep_owner_conditions` with an empty key clause.

`WhereClause#-` is `WhereClause.new(predicates - other.predicates)`, two objects each. An association reader
therefore allocates 11 more objects than on census 9: five differences and the pair. The check exists for
association scopes that `unscope` or `rewhere` the owner key. When the reflection chain has no scope at all, nothing
can remove a condition, and every difference is empty by construction.

**Share per request.** 56 of 70 workloads, all 8 apps. `keep_owner_conditions` and `WhereClause#-` self are 0.137%
of all interpreted instructions, median 0.114% per workload, up to 0.484% (casa `GET casa case edit`), 0.345%
(writebook `GET leaf.md`), 0.330% (casa `GET supervisors`), 0.310% (casa `PATCH casa case`) and 0.300% (hackatime
`GET statusbar today`) ([per workload](data/rails-main-census-10/share-A1.tsv)). Objects: `WhereClause#-` is the
largest allocation main adds over 8.1 and over census 9 (+51.8 objects in the 56 workloads where it grew;
[8.1](data/rails-main-census-10/alloc-method-81-main.txt), [c9](data/rails-main-census-10/alloc-method-c9-main.txt)),
median 0.56% of a request's objects, up to 2.76% (casa case edit +661, casa `GET supervisors` +192, casa
`GET casa case` +275; [per workload](data/rails-main-census-10/reach-A1.txt)). Against census 9, A1's methods (`WhereClause#-`, `#empty?`, `#initialize`, `QueryMethods#where_clause`,
`keep_owner_conditions`, `add_constraints`, `last_chain_scope`) grew by +0.258% of all instructions, median +0.21%
per workload, up to +0.87% (casa case edit; [per workload](data/rails-main-census-10/attrib-c9-main.tsv),
[script](../../bench/upstream/census10/attrib.rb); the same split on main's A/A is ±0.002%). In casa that is a third
to a half of each slower page's growth (case edit +1.54% total, +0.87% A1; `PATCH casa case.json` +1.91%, +0.58%);
self instructions only, so the callees' share (`Array#-`, `Struct#==`) comes on top.

**Repro** ([`assoc_micro.rb`](../../bench/upstream/census10/assoc_micro.rb); `author.posts.reset; author.posts.to_a`
with three rows and no association scope), Ir / objects per call, interpreter:

| Case | 8.1 | c9 | main (A/A) | main vs 8.1 | main vs c9 | ceiling | ceiling vs c9 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `author.posts` | 644,108 / 148 | 649,466 / 96 | 667,130 / 107 (667,036) | **+3.6%** | +2.7% | 654,774 / 97 | +0.8% |
| `author.profile` (has_one) | 507,939 / 120 | 517,086 / 75 | 534,667 / 86 (534,569) | **+5.3%** | +3.4% | 522,286 / 76 | +1.0% |
| `comment.post` (belongs_to) | 523,779 / 121 | 494,836 / 75 | 512,684 / 86 (512,596) | −2.1% | +3.6% | 500,337 / 76 | +1.1% |
| `author.pictures` (`as:`) | 674,724 / 160 | 681,686 / 102 | 708,302 / 113 (707,658) | **+5.0%** | +3.9% | 689,218 / 103 | +1.1% |
| `author.comments` (through) | 920,052 / 217 | 776,229 / 141 | 822,711 / 158 (822,622) | −10.6% | +6.0% | 810,295 / 148 | +4.4% (lead A2) |
| `Author.joins(:posts).to_sql` | 340,709 / 127 | 347,937 / 101 | 359,753 / 107 (359,790) | **+5.6%** | +3.4% | 349,003 / 99 | +0.3% |
| `Author.joins(:comments).to_sql` | 530,195 / 182 | 545,914 / 139 | 571,605 / 151 (571,678) | **+7.8%** | +4.7% | 548,540 / 135 | +0.5% |
| `author.published_posts` (scoped) | 863,393 / 223 | 830,987 / 143 | 851,275 / 154 (851,026) | −1.4% | +2.4% | 851,764 / 154 | +2.5% (keeps the check) |
| `preload(:posts)`, `posts.count`, `posts.where(...)` | | | | −1.7% / +1.0% / −5.2% | ±0.1% | | unchanged |

YJIT, flat cells only ([raw](data/rails-main-census-10/raw/assoc/)): main is still faster than 8.1 everywhere, but
against census 9 `has_one` +2.9%, `as:` +4.0%, through +5.4%, `joins` +3.1% and +4.0%; the ceiling is within +0.7%
of census 9 on each. `association_scope_keeps_owner_conditions = true` (the 8.2 default for new apps) costs the same
as `false` (±0.1%, `main-keep` in the raw files): the work is the check, not the re-add.

Bisect over the first-parent merges ([req micro](data/rails-main-census-10/raw/req/)): `author.posts` 650,710 →
652,868 at #59816 (lead C), → 662,697 / +5 objects at #59825, → 668,702 / +6 objects at #59836; through
additionally 773,749 → 801,251 / +6 objects at #59823 (lead A2). Nothing else between census 9 and main moves these
cases.

**Exact change?** Not the broad ceiling ([diff](data/rails-main-census-10/A1-ceiling.diff)). The initial
[ordinary SQL/records probe](../../bench/upstream/census10/a1_cpk_probe.rb) and
[call-count probe](../../bench/upstream/census10/a1_calls_probe.rb) missed effectful bind serialization.
The earlier assertions that the skipped comparisons cannot call user code and that moving them past scope
lambdas is unobservable are withdrawn: `QueryAttribute#hash` and `#==` serialize values. The
[first review](../../bench/upstream/a1/review-thermos-sol/README.md) and
[second review](../../bench/upstream/a1/review-thermos-sol-80daecf52a/README.md) demonstrate different records,
including reader answers matching neither 8.1 nor main. [A1 was narrowed](../../bench/upstream/a1/narrow/README.md)
to unscoped `join_scope`, with a seeded regression test and a CHANGELOG entry. It restores the demonstrated
unscoped join results, not all 8.1 behavior; readers and scoped comparisons remain main's.

**Prior work.** None on the cost. #59825 and #59836 have no reviews or comments on performance (kamipo merged both
himself); #59836's description says the check exists for the `unscope(where: :user_id)` pattern. Our open #59569
(build the alias tracker only for through chains) touches `association_scope.rb` in `get_chain` and still merges
cleanly with main. **Collision risk is high:** kamipo made six commits to associations, reflection and
relations on 2026-11-16 and 11-17. None of his eight open PRs touches `association_scope.rb` or `reflection.rb`
(#58814 touches `alias_tracker.rb`, #58815 the preloader, #39863 `predicate_builder.rb`); wtn's #59826 touches the
through preloader.

### A1 confirm on current main (2026-11-18)

**Verdict: approve; no must-fixes.** Reviewer `thermos-sol`, thread
`T-01a1f0e1-7fe7-77ba-871a-795ff75f861d`. Both Thermos rubrics were loaded and applied here by the same
reviewer, without other reviewers, subagents or threads. This is a single-reviewer confirm, not two independent
passes. The [queue pass](../../bench/upstream/pr-queue/items/A1.md) covers exact head
[`5660fa833ded644617a0900fd8f8ab6d39408182`](https://github.com/thomasklemm/rails/commit/5660fa833ded644617a0900fd8f8ab6d39408182)
against freshly fetched rails/rails main
[`78f4f0df59866e8951646183c1f275e186916ba7`](https://github.com/rails/rails/commit/78f4f0df59866e8951646183c1f275e186916ba7),
also the final remote-ref recheck. Reference 8-1-stable:
[`aab611acd84b4754e2403a9ab005532ccb0ed374`](https://github.com/rails/rails/commit/aab611acd84b4754e2403a9ab005532ccb0ed374).

The fork branch and live PR GET both matched the requested head and draft state. The current main merge is
clean. Its `reflection.rb`, `association_scope.rb` and has-many test file are unchanged since the head's parent
`8e097e9d81`. The A1 reflection/reader blobs are identical to previously approved `e6bfe76e95`; the test changes
since then only move DDL to `test/schema/schema.rb` and restore transactional fixtures. The CHANGELOG entry is
unchanged, merely moved above newer main entries. This confirms those changes rather than carrying an old pass.

**Executed regression and suites.** Ruby 4.0.9 (`3e93b23afc`), SQLite 3.54.1 / sqlite3 2.10.2, minitest 6.1.0.
Each checkout supplied its own framework sources. No installed Rails gem or production database was used.
The exact added class was extracted by the existing
[`targeted_test.rb`](../../bench/upstream/a1/review-thermos-sol-e6bfe76e95/targeted_test.rb); only its schema
addition was transplanted to current main for the negative control, not the library fix.

| Scenario | Result under each owner-condition setting |
| --- | --- |
| New test on current main | 1 run, 1 error: `ActiveModel::RangeError`; stack reaches `QueryAttribute#hash` from `reflection.rb:236` |
| New test on exact head | 1 run, 4 assertions, pass |
| New test on exact head, `ARCONN=sqlite3_ractor` | 1 run, 4 assertions, pass; this is the self-proxy test mode, not the full Ractor suite |
| Exact head, test's default scope removed in memory | 1 failure: seeded joined parent returned; dropping the conditions is not a passing fix |

The full command below ran with `ARCONN=sqlite3` from each tree's `activerecord/`, with warnings enabled:

```sh
ruby -w -I../railties/lib -I../activesupport/lib -I../activemodel/lib -Ilib -Itest \
  -e 'ARGV.each { |f| require File.expand_path(f) }' \
  test/cases/associations/*_test.rb test/cases/associations_test.rb \
  test/cases/reflection_test.rb test/cases/relation_test.rb test/cases/relations_test.rb \
  test/cases/relation/*_test.rb test/cases/scoping/*_test.rb
```

| Tree | Runs | Assertions | Failures / errors | Skips |
| --- | ---: | ---: | --- | ---: |
| Exact head | 3,271 | 10,741 | 0 / 0 | 1 |
| Unchanged current main | 3,271 | 10,738 | 0 / 0 | 1 |
| Current main + unchanged A1 library/test delta | 3,272 | 10,742 | 0 / 0 | 1 |

These include inner/outer joins, eager loading, through and nested associations, reflections, relations and
scoping. Each command exited 0. The existing skip is
`ActiveRecord::WhereTest#test_with_tuple_syntax_and_large_values_list`, confirmed in isolation; its SQLite
expression-tree-limit guard is unchanged. Initial runs on both trees stopped at missing `bcrypt`; installed
it and reran both complete commands, without changing tests. The extra main test comes from its unrelated
single-predicate OR fix; equal totals do not mean identical test inventories. No PostgreSQL/MySQL, full Ractor
suite, Ruby master, JIT or performance rerun is claimed by this pass.

**Differential confirm.** Reran the existing
[`adversarial_joins.rb`](../../bench/upstream/a1/review-thermos-sol-e6bfe76e95/adversarial_joins.rb) unchanged
on main/head/8.1, SQLite, finite/range/context-dependent modes and widths 16/17. Each cell contains 130
observations: both settings × 13 association shapes × five operations. Each tree has 780 observations, 2,340
total. Seeded records distinguish owners, polymorphic types, STI, defaults and serializer phases.

| Mode / width | Head differs from main | Head matches neither main nor 8.1 |
| --- | ---: | ---: |
| Finite / 16, 17 | 0, 0 | 0, 0 |
| Out-of-range / 16, 17 | 20, 90 | 0, 0 |
| Context-dependent / 16, 17 | 0, 12 | 0, 0 |

STI adds a predicate, so 17 is the reproducer's threshold, not a universal Rails contract. Scoped range
failures remain; no new exception kind occurred. The
[`linear_join`](../../bench/upstream/a1/followup-81/linear_join.rb) probe also confirms equality can serialize
with only two predicates: main selects `Parent`, head and 8.1 select `ParentX`. Both widths of
[`scoped_hash_phase`](../../bench/upstream/a1/review-thermos-sol-80daecf52a/scoped_hash_phase.rb),
[`scoped_extension`](../../bench/upstream/a1/review-thermos-sol-80daecf52a/scoped_extension.rb) and
[`scoped_join_removed`](../../bench/upstream/a1/review-thermos-sol-80daecf52a/scoped_join_removed.rb)
match main byte for byte; the former third-answer reader cases still select records 35 and 2, not 69 or 4.
The ordinary probe is byte-identical (334 lines / 14 warnings with KEEP=0, 320 / no warnings with KEEP=1),
as is the CPK/`disable_joins` probe. `range_paths` confirms unfiltered outer joins retain the parent with zero
children; readers/preload and scoped joins removing the bad condition are not repaired. These are retained
boundaries, not new defects. Scripts and raw logs from this confirm are under `.amp/in/orb-backup/a1-confirm/`.

**Body, CHANGELOG and commit audit.** The queue body matched the live PR body exactly. No body edit is needed.
Each factual sentence was checked, not carried over from the prior review:

* Title and final “nothing can have removed a condition” sentence: the sole production change guards the
  original comparison/merge block on `scope_chain_items.empty?`; default/STI/route predicates and key joins stay.
* “Since #59836” and “also when there are no scope items”: inspected `ff53633d52^1..ff53633d52`'s reflection diff
  and current main. It introduces the initial difference and the two helper differences, unconditionally.
* “Comparing predicates can call into their bind values”: read `WhereClause#-` and `QueryAttribute#hash`/`#==`;
  the failing stack and range/context/two-predicate probes execute the mechanism.
* “So joining ... raises ... instead of matching no records” and the Ruby snippet: extracted the exact body
  model definitions into an in-memory SQLite schema with the 17 integer columns and a seeded matching owner/
  child. Current main raises under both settings; exact head and 8.1 return `[]`. This is an inner-join example,
  not a promise about all scoped joins or outer-join parents.
* CHANGELOG heading and paragraph describe that same concrete failure and narrow fix. Top placement,
  indentation and Thomas credit match Rails guidance. No broadened 8.1-restoration or performance claim.
* Commit subject and each explanatory sentence make the same checked claims as the body. One fix commit,
  author/committer Thomas Klemm, no trailers; no rewrite needed. PR discussion was read after the audit:
  comments, inline comments and reviews were all empty.

**Claims retired, not recertified.** The body and CHANGELOG contain **zero performance sentences**, so there
is nothing to cut there. The earlier census summary's “An exact fast path ... recovers 70% ... and 10 of the
11 objects” is replaced above: that was a rejected broad prototype, not this PR. The ranked row now labels
its 8/8-app reach and ceiling numbers historical, not PR savings. The old “Exact change? Yes” and “order is not
observable” reasoning is withdrawn above. The method/limits below no longer call the ceiling exact.
Removed the queue impact sentence “Internal cost note: Author.joins(:posts) about -3% instructions (body/a1 join
cell); reader savings dropped with the narrowing” and the triage's “Intern etwa −3% Join-Micro” clause: neither
is a new current-main measurement. Historical pinned tables remain history, not a present-day speed claim.

**Maintainability, guards and comments.** Cold read: build the class/default and fixed route conditions; if
association scope items exist, perform the same comparisons and merges as before; then add key equalities.
The sole surviving guard is idiomatic `unless scope_chain_items.empty?`: an empty Rails-owned Array means no
scope merge could have removed an owner condition. It is the correctness boundary, not arbitrary-object
defense. Checking only `scope` would miss through/source-type items; moving the guard to the helper would
leave the first effectful subtraction in place. No smaller equivalent structure is apparent.

The only added comment is the one line explaining why the test needs more than 16 predicates; without it a
reader could reduce the width and lose the regression. No production/API comment, helper, cache, sentinel,
copied method or ad-hoc user-object guard was added. Files were already above 1,000 lines (reflection
1,628 → 1,630; has-many tests 3,713 → 3,734); no threshold crossing. Fresh extracted-method metrics, flog 4.9.4 /
RuboCop 1.92.3: flog 31.1 → 33.6, ABC 26.91 → 27.89, cyclomatic/perceived 3 → 4. The one branch expresses the
real empty/nonempty distinction; abstraction would obscure it. Metrics maxima were zero to print values,
not a claim that the complete Rails RuboCop suite passed.

Checklist scope: custom type subclasses, effectful equality/hash/serialization and extension callbacks were
executed; no user-returned accumulator is adopted. Construction/load order and the nonempty branch are
unchanged. Rails' internal scope-item Array contract needs no singleton/subclass/conversion fallback guards;
no claim is made to have exhausted arbitrary overrides, frozen-value or fiber schedules. The tested behavioral
differences are intentional unscoped-join repairs, not exact equivalence to all of main or all of 8.1.

Only Lowrail records were edited. No fork push, GitHub PATCH, ready action, comment or CI rerun was performed.

## Lead A2: a second `AliasTracker` per through-association load

**Site.** #59823 (`5828589f4f`, kamipo, merged 2026-11-16): `ThroughAssociation#target_scope`
([main `through_association.rb:39–51`](https://github.com/rails/rails/blob/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff/activerecord/lib/active_record/associations/through_association.rb#L39-L51))
now calls `scope.alias_tracker` and, per through link, `aliased_table_for` and `klass_join_scope(table)` instead of
`klass.scope_for_association`. `Relation#alias_tracker` checks a connection out of the pool to read
`table_alias_length`, the cost our #59569 removes from direct associations.

**Share.** `AliasTracker.create` grew in 19 workloads of 5 apps (+4.2 objects, [c9](data/rails-main-census-10/alloc-method-c9-main.txt)).
In the CPU census `AliasTracker.create`, `aliased_table_for`, `klass_join_scope` and `target_scope` grew by +0.017%
of all instructions against census 9; the census apps load few through associations.

**Repro.** `author.comments` (has_many through posts): 773,749 → 801,251 Ir (+3.6%), 141 → 147 objects at #59823;
+100 Ruby and C calls per load, including the pool lease (`with_connection`, `LeaseRegistry#lease`) and the alias
counting. Main is still 10.6% below 8.1 here, so this is a regression against census 9 only.

**Exact change?** Probably, not designed yet. Only aliased chains need a tracker; when no table repeats in the chain,
`aliased_table_for` returns the model's own `arel_table`, and `klass_join_scope(arel_table)` builds the same scope
as `scope_for_association`. Proving that equivalence (STI type condition, default scopes, predicate builder) is the
work. **Prior work:** our #59569 (same tracker cost, other call site); kamipo's #59823 thread has no comments.

## Lead C: `type_for_attribute` forwards a block on every predicate

**Site.** #59816 (`c84a19e192`, kamipo, merged 2026-11-16): `Arel::Attributes::Attribute#type_caster(&block)`,
`Arel::Table#type_for_attribute(name, &block)`, `TableAlias#type_for_attribute` and
`TypeCaster::Map#type_for_attribute(name, &block)` now take and pass a block, so a calculation can fall back to the
result's column type. `PredicateBuilder` calls `type_caster` two or three times per `where` key, with no block.

**Repro** ([`rel_micro.rb`](../../bench/upstream/census10/rel_micro.rb)), interpreter, #59816's parent → merge:
`Post.where(title:).to_sql` 195,296 → 197,392 (+1.1%), three keys 348,811 → 355,129 (+1.8%), `pluck` 418,646 →
423,224, `group(:author_id).count` 488,419 → 492,467 and 135 → 140 objects (the `proc` per group column); calls
and objects otherwise identical. A pure-Ruby probe on 4.0.9 puts a nil `&block` hop at about 360 Ir more than a
plain call. **YJIT: no cost** (`where_hash3` +0.1%, flat), except `group_count` +4.4k Ir and +5 objects.

**Share.** +0.094% of all instructions against census 9, median +0.07% per workload, up to +0.28% (casa case edit,
supervisors; writebook's `Turbo::Streams::BroadcastJob` +0.27%). Since YJIT is the production reference and the interpreted cost is about 0.3–0.5 µs per `where`
key, this ranks low.

**Exact change?** Yes: forward the block only when one is given (`block ? relation.type_for_attribute(name, &block) :
relation.type_for_attribute(name)` still has a block parameter; `yield`/`block_given?` keeps the method simple), or
let the two calculation call sites pass the fallback themselves. **Prior work:** our #59607 (merged 2026-11-04)
replaced a block in this chain with a `fetch` default; kamipo's #59816 has no comments.

## Carried over from census 9

* **Lead 8, `table_name_qualified_unscope_values` on every merge** (#59709): still +13.4 objects per workload in 56
  of 70 workloads against 8.1. `AssociationScope#add_constraints` calls it per scope item and `Merger#merge` per
  merge. An early return for empty `unscope_values` is exact. Not queued; below the bar alone, natural to fold into
  A1 if kamipo takes that.
* **Hot sites on main** ([rank](data/rails-main-census-10/rank-c10m-method.txt)): `TagBuilder#append_tag_option`
  0.92%, `String#blank?` 0.74%, `IsolatedExecutionState.[]` 0.73%, `TagBuilder#tag_options` 0.69%,
  `Merger#merge` 0.55% of all interpreted instructions: all ranked and judged in censuses 8 and 9, none new.


## Main against 8-1-stable and census 9 in the census

**CPU against 8.1** (`c10s` against `c10m`/`c10m2`, interpreter, 70 workloads, all JIT-flat;
[cells](data/rails-main-census-10/cpu-81-main-cells.txt), [methods](data/rails-main-census-10/cpu-81-main-method.txt),
[net by method](data/rails-main-census-10/cpu-net-81-main-method.txt)):

| App | Workloads | Median main vs 8.1 | Range | A/A median \|Δ\| |
| --- | ---: | ---: | --- | ---: |
| blog | 10 | -12.01% | -24.86% … -5.30% | 0.07% |
| casa | 10 | -7.76% | -24.44% … -0.12% | 0.10% |
| codetriage | 7 | -3.20% | -12.73% … +5.04% | 0.12% |
| hackatime | 11 | -5.40% | -9.42% … -2.23% | 0.07% |
| pingcrm | 8 | -5.48% | -6.49% … -1.77% | 0.11% |
| react-starter-kit | 8 | -5.92% | -8.40% … -4.75% | 0.21% |
| redprints-cfp | 8 | -5.99% | -9.46% … -1.64% | 0.57% |
| writebook | 8 | -6.50% | -9.22% … -2.71% | 0.05% |

All 70 workloads: median -5.95%; 67 faster and 2 slower beyond 1%; A/A median |Δ| 0.12%

The two slower workloads are codetriage `perform SendSingleTriageEmailJob` (+5.04%, the debug-logged event reporter,
judged deliberate in [main-regressions](main-regressions.md); +4.03% in census 9) and codetriage `PATCH repo
subscription` (+1.09%, A/A 0.00%). The methods that grew against 8.1 are census 9's list (#59141's attribute set,
`append_tag_option`, `QueryIntent`, `WeakKeyMap`, `association_route`, schema context) plus two new rows from lead
A1: `WhereClause#empty?` +0.111% and `WhereClause#-` +0.107% of all 8.1 instructions, 8 apps each. `PG::Connection#get_result`
(+0.585%, 3 apps) is work that moved out of `perform_query` (−0.48% in the same apps), not new cost.

**CPU against census 9** (`c10c9`; [cells](data/rails-main-census-10/cpu-c9-main-cells.txt),
[net by method](data/rails-main-census-10/cpu-net-c9-main-method.txt), [by file](data/rails-main-census-10/cpu-net-c9-main-file.txt)):

| App | Workloads | Median main vs c9 | Range | A/A median \|Δ\| |
| --- | ---: | ---: | --- | ---: |
| blog | 10 | -0.04% | -0.41% … +0.76% | 0.07% |
| casa | 10 | +1.14% | +0.01% … +1.91% | 0.10% |
| codetriage | 7 | +0.58% | -0.03% … +0.99% | 0.12% |
| hackatime | 11 | +0.28% | -1.22% … +0.65% | 0.07% |
| pingcrm | 8 | +0.21% | -0.46% … +0.53% | 0.11% |
| react-starter-kit | 8 | +0.34% | +0.04% … +2.71% | 0.21% |
| redprints-cfp | 8 | +0.74% | -0.25% … +1.73% | 0.57% |
| writebook | 8 | +0.82% | +0.64% … +1.37% | 0.05% |

All 70 workloads: median +0.42%; 1 faster and 12 slower beyond 1%; A/A median |Δ| 0.12%

The two outliers in react-starter-kit and redprints-cfp `GET home` (+2.71%, +1.73%) carry the same size of A/A
(−2.74%, −1.22%) and are noise. Every other slower workload loads associations; the net method list is led by
`WhereClause#-` (+0.116%), `QueryMethods#where_clause` (+0.050%), `Attribute#type_caster` (+0.041%) and
`Table#type_for_attribute` (+0.039%).

**Allocations** (`script/census`, [8.1](data/rails-main-census-10/alloc-81-main.txt),
[c9](data/rails-main-census-10/alloc-c9-main.txt)): A/A median −0.1 / −0.1 objects (interpreter / YJIT). Main
against 8.1: median −553 / −583 objects, all 70 workloads lower, 11 SQL digests changed (12 in census 9). Main
against census 9: median −17.7 / −19.2 objects, 59 lower and 5 higher. The growth is lead A1: `WhereClause#-` and
`last_chain_scope` are the only methods that grew in more than 5 apps; what shrank was not attributed ([methods](data/rails-main-census-10/alloc-method-c9-main.txt)).

### Our merged changes

[`ours_survive.rb`](../../bench/upstream/census9/ours_survive.rb) against main ([output](data/rails-main-census-10/ours-survive.txt)):
#59809 (merged 2026-11-15, "query"/"queries" in the request log line) keeps its line. #59642 (CW1) keeps 1 of 2
lines: #59829 changed `bound_sql_literal_for(opts, rest)` to `opts.to_s` (no cost). #59634 keeps 23 of 26 lines
after kamipo's and Hartley McGuire's edits. Everything census 9 listed as kept still is.

## Method and pins

* **Rails:** main [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff)
  (merge of #59845, fetched 2026-11-17 22:30 UTC). 8-1-stable [`aab611acd8`](https://github.com/rails/rails/commit/aab611acd84b4754e2403a9ab005532ccb0ed374)
  (#59839; census 9's `71e963ed1b` plus two backports with no `lib/` change). Census 9's main
  [`50c54eed06`](https://github.com/rails/rails/commit/50c54eed065b8bfb1b0bbb5fa770c859baa98f9b). First-parent points
  for the attribution: `e9c26763e2`, `78039119db`, `d0eec80537`, `23cac06228` (#59816), `ed17c90871`, `667831f578`
  (#59821), `3d4914e1b2`, `a5203b3d4d` (#59823), `a58ae65dd0` (#59825), `04988cc35d`, `4f00fbc946`, `f0c9373b05`,
  `ff53633d52` (#59836).
* **Ruby** 4.0.9 (`3e93b23afc`), interpreter and `--yjit`. ZJIT was not run (nothing was built).
* **Corpus:** census 9's 8 apps (blog, writebook, codetriage, pingcrm, redprints-cfp, react-starter-kit, casa,
  hackatime) with census 7's overlays ([`setup.sh`](data/rails-main-census-10/setup.sh)). 70 workloads: hackatime's
  `perform DashboardRollupRefreshJob` listed at setup but recorded no measurement in any label, so every comparison
  leaves it out (census 9 had 71).
* **Census runs** ([`run_census.sh`](data/rails-main-census-10/run_census.sh), [`heap.sh`](data/rails-main-census-10/heap.sh)):
  allocations `a10m`/`a10m2`, `a10s`/`a10s2`, `a10c9` (interpreter and YJIT, `--jobs 2`); CPU `c10m`/`c10m2`, `c10s`,
  `c10c9` (interpreter, `--jobs 2`). As in census 9, the CPU comparison uses main's A/A for both sides of every cell.
  On this orb (2 cores, 4 GB) the allocation labels took 25 minutes and each CPU label about 40.
* **Comparison:** `script/census compare`, `bench/upstream/main_regressions/method_diff.rb alloc`, census 9's
  [`cpu_regress.rb`](../../bench/upstream/census9/cpu_regress.rb) and [`cpu_net.rb`](../../bench/upstream/census9/cpu_net.rb),
  and [`site_reach.rb`](../../bench/upstream/census10/site_reach.rb) for the objects at given lines.
* **Micros:** [`assoc_micro.rb`](../../bench/upstream/census10/assoc_micro.rb), [`rel_micro.rb`](../../bench/upstream/census10/rel_micro.rb)
  and census 9's [`req_micro.rb`](../../bench/upstream/census9/req_micro.rb), run by
  [`sweep.sh`](../../bench/upstream/census10/sweep.sh) and tabulated by [`table.rb`](../../bench/upstream/census10/table.rb).
  100 calls after 100 warmup calls; `IrCount` reads the exact Ir under census 8's patched Callgrind
  (`--instr-atstart=no`); objects from `GC.stat` with GC off in the window; under YJIT, warmup until three windows in a
  row compile nothing (at most 30), and a cell whose measured window compiled anything is "not flat" and not used.
  Each tree runs in its own process; main and `main2` are the A/A. `KEEP=1` sets
  `association_scope_keeps_owner_conditions = true`, the 8.2 default for new apps.
* **Fixed heap:** `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000` for every run.
* **Ceiling prototype** for lead A1: a local patch on main ([diff](data/rails-main-census-10/A1-ceiling.diff)), not
  a branch; a historical cost ceiling, subsequently rejected for effectful-bind behavior. It does not price
  the narrowed correctness PR.
* **Receipts:** [data/rails-main-census-10](data/rails-main-census-10/) (micro raw output in `raw/`). Orb scripts
  and notes in `.amp/in/orb-backup/`.

## Limits

* No ZJIT and no YJIT CPU census; YJIT claims come from the micros.
* The 8 apps include no MySQL app and none on `load_defaults "8.2"`, so the census runs
  `association_scope_keeps_owner_conditions = false`; the micro shows `true` costs the same.
* Lead A1's initial broad exactness argument was disproved. The current join-only fix, CPK/`disable_joins`
  controls and remaining boundaries are in the [confirm](#a1-confirm-on-current-main-2026-11-18).
