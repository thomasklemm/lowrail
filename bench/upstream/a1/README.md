# A1: check the owner conditions only when an association scope was merged

Census 10's lead A1 ([rails-main-census-10](../../../docs/upstream/rails-main-census-10.md#lead-a1-owner-condition-bookkeeping-on-every-association-scope)),
built on rails/rails main `e30c36266b` (2026-11-18) as `thomasklemm/association-owner-conditions-unscoped`. The
head is [`80daecf52a`](https://github.com/thomasklemm/rails/commit/80daecf52a): the fix
[`9877a852dd`](https://github.com/thomasklemm/rails/commit/9877a852dd) (+17/−10) plus regression tests (+57/−0)
([patch](A1.patch)). Queue item [A1](../pr-queue/items/A1.md). Not opened.

**Review, 2026-11-18: changes requested.** The [Thermos review](review-thermos-sol/README.md) found that
`WhereClause#-` can hash predicates and so serialize bind values; computing the differences later than main
changes SQL and records in two repros.

**Follow-up, same day** ([followup-81](followup-81/README.md)): on Rails 8.1 both repros, and five more probes, give
the branch's answer. Main's answers first appear at #59836's merge. On main, a join whose target default scope has
17 conditions, one of them an out-of-range plain integer, raises `ActiveModel::RangeError`; 8.1 and the branch return
no rows. So the counterexamples are a regression of main against 8.1, and A1 restores 8.1 there. It is not exact
against main, and no exact fast path against main exists: user code is reachable with two predicates, and with
built-in types. The head adds two regression tests, which fail on main and pass on 8.1 and the head.

The sections below are from the first build. Where they say "same as main" for user-code calls, or "no user-supplied
object reaches the changed lines", the review and the follow-up supersede them. The YJIT columns are diagnostic: the
body cohort recorded no JIT-flat counters.

## The change

Since #59825 and #59836 (kamipo, merged 2026-11-17), `AssociationScope#add_constraints` and
`AbstractReflection#join_scope` build `WhereClause` differences before and after merging the association's own
scope, so `keep_owner_conditions` can tell whether the scope removed the key or polymorphic type conditions. They
build them for every association, also one without a scope, where nothing can be removed: five `WhereClause#-`
(ten objects) and an Array per load, three per `join_scope`.

The branch keeps the where clauses (no allocation; `WhereClause` is never changed in place, `+=` and `-` build new
ones) and computes the same differences after the loop only if a scope item was merged. `join_scope` skips them when
`join_scopes` is empty. `last_chain_scope` returns its where clause after the key conditions instead of the
difference. The preloader (`preloader/association.rb`) and `disable_joins` are unchanged. `disable_joins` still
computes its type difference and final check unconditionally.

## Exactness (DECISIONS checklist)

* **Output.** [`a1_diff_probe.rb`](../census10/a1_diff_probe.rb): 12 associations (plain, scoped, `unscope(where:)`,
  `rewhere`, an instance-dependent `unscope` + `where`, `as:` and `as:` with `unscope(where: :imageable_type)`,
  through, scoped through, nested through, `has_one` with order) on a plain and an STI owner, each loaded, as SQL and
  chained; then `preload`, `includes`, `eager_load`, `joins`, `left_joins` and `where.associated` of each, plus
  `belongs_to`, polymorphic `belongs_to`, STI joins, build, create, `delete_all` and `count`. SQL, records and every
  deprecation warning are byte-identical on main and the branch with `association_scope_keeps_owner_conditions`
  false (334 lines, 14 warnings) and true (320 lines) ([raw](raw/)). The probe is sensitive: false and true differ
  in records and warnings. The four `ArgumentError`s (eager loading an instance-dependent scope) are the same on both.
* **Composite keys and `disable_joins`:** [`a1_cpk_probe.rb`](../census10/a1_cpk_probe.rb) identical.
* **Calls into user code (item 4).** A custom key type counting `==`, `eql?` and `hash` sees the same calls on both
  trees in every case (none during scope building; one `hash` in the preloader's grouping, unchanged). The skipped
  `Array#-` compared Rails' own Arel nodes. Positive control: subtracting two separately built `where(author_id: 1)`
  calls `==` once.
* **Order.** With a scope item the differences are now computed after the scope lambdas run instead of before;
  they read clauses captured at the same points, so the result is the same. A scope lambda cannot change those
  clause objects (frozen predicate Arrays are only replaced, never mutated, except in `WhereClause#or` on a fresh
  clause).
* Items 1–3 and 5–8 (singletons, subclasses, conversions, adopted results, frozen receivers, load order) do not
  apply: no user-supplied object reaches the changed lines.

## Tests

[`ar_tests.sh`](ar_tests.sh): `test/cases/associations/**`, `associations_test`, `reflection_test`,
`relation_test`, `relations_test`, `relation/*`, `scoping/*`, with `-w`:

* SQLite: 3,270 runs, 0 failures, 0 errors, 1 skip ([summary](raw/ar-a1-sqlite2-summary.txt)).
* PostgreSQL 17: 3,275 runs, 0 failures, 0 errors ([summary](raw/ar-a1-pg-summary.txt)).
* MySQL: not installed in this orb; not run.
* `-w` caught an unused local left in `last_chain_scope`; removed before the commit.

The first build added no test. Head `80daecf52a` adds `HasManyOwnerConditionsSerializationTest`, which covers the
out-of-range join and the scope-changes-serializer repro; see [followup-81](followup-81/README.md#tests). The
existing owner-condition tests from #59825/#59836 cover the scoped path that still checks. On the head: SQLite 3,272
runs, PostgreSQL 3,277, 0 failures.

## Numbers

Census 10's micro ([`assoc_micro.rb`](../census10/assoc_micro.rb)), Callgrind Ir / objects per call, main
`e30c36266b` against a second checkout (A/A) and the branch ([raw](raw/)):

| Case | main | A/A | branch | interp | YJIT |
| --- | ---: | ---: | ---: | ---: | ---: |
| `author.posts` | 667,253 / 107 | −0.0% | 654,187 / 97 | **−2.0%** | −1.9% (not flat) |
| `author.profile` | 534,774 / 86 | −0.0% | 521,712 / 76 | **−2.4%** | −2.3% |
| `comment.post` | 512,617 / 86 | −0.0% | 499,783 / 76 | **−2.5%** | −2.5% |
| `author.pictures` (`as:`) | 707,703 / 113 | −0.0% | 688,657 / 103 | **−2.7%** | −3.3% |
| `author.comments` (through) | 822,617 / 158 | +0.0% | 809,774 / 148 | **−1.6%** | −1.5% |
| `Author.joins(:posts).to_sql` | 359,761 / 107 | +0.0% | 349,144 / 99 | **−3.0%** | −3.3% |
| `Author.joins(:comments).to_sql` | 571,600 / 151 | +0.0% | 548,752 / 135 | **−4.0%** | −4.9% |
| scoped, `where`, preload, `count` | | ≤ 0.1% | | ±0.1% | ±0.2% |

Per request ([`census-per-request.txt`](census-per-request.txt), `script/cpu-census` label `c10a1` on casa,
writebook and hackatime against census 10's `c10m`/`c10m2`): median −0.19% over 29 workloads, casa case edit
−0.89% (−697 objects), supervisors −0.57%, `PATCH casa case.json` −0.42%, writebook `GET leaf.md` −0.40%; objects
lower in 28 of 29. Hackatime's two higher cells (`GET dashboard` +0.21%, `GET leaderboards` +0.34%) are
`Rack::Test::Cookie#valid?` in the harness (+197k Ir), not Rails.

Body numbers: [`body/a1`](body/a1/table.md) (`script/upstream-bench`, [`a1_body.rb`](a1_body.rb), 2,000 calls per
window, A/A per cell): interpreter `author.posts` −1.8%, `author.profile` −2.2%, `comment.post` −2.3%, through
−1.6%, `joins(:posts)` −3.0% (A/A ≤ 0.08%); YJIT −1.8%, −2.0%, −1.2%, −1.3%, −4.1% (A/A ≤ 1.12%, the joins cell);
10 fewer objects per load, 8 per join. The YJIT numbers are diagnostic: `script/upstream-bench` recorded no
JIT-flat counters. The scoped control `author.published_posts` is −0.1% interpreted, and its allocations are
unchanged. Its YJIT instruction count was +0.3% (A/A 0.10%, diagnostic), and the cause was not isolated.

Not measured yet: Ruby master × ZJIT (DECISIONS requires it before opening).

## Not folded in

Census 9's lead 8 (`table_name_qualified_unscope_values` builds an Array per scope item and merge, #59709): a
different site and author, and the small version (return `unscope_values` when empty) hands an internal Array to
callers, while `unscope!(*[])` still assigns `unscope_values`; it needs its own proof. Left as a held idea.

## Alternative

[`kamipo-note.md`](kamipo-note.md): a short heads-up on #59836 with the repro and the branch, if Thomas prefers
handing it over. Not posted.
