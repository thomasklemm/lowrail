# A1 Thermos review: changes requested

**Do not propose head `9877a852dd` as exact.** Deferring or skipping `WhereClause#-` changes when custom bind values are serialized, and can select different records with either value of `association_scope_keeps_owner_conditions`. Both independent Thermos rubrics completed; maintainability alone is acceptable, but correctness and publication claims need changes.

Reviewer: `thermos-sol`, 2026-11-18. Exact range: rails/rails `e30c36266b48016e74422e987dd46e85cacbeea8` to thomasklemm/rails `9877a852dd29208d4c15c04d6dea01506fc74982`, +17/−10 in two files. The fork was fetched into a fresh clone of rails/rails. No Rails files were changed in either reviewed tree, no fork push was made, and nothing was posted upstream. The proposal body and kamipo note were reviewed, not rewritten or approved for publication.

## P2: subtraction changes serialization timing and records

Changed sites: `activerecord/lib/active_record/associations/association_scope.rb:130–166` and `activerecord/lib/active_record/reflection.rb:236–240` at the candidate head.

`WhereClause#-` calls `Array#-`. On this Ruby, sufficiently large predicate arrays use hashing. `Arel::Nodes::Binary#hash` reaches `QueryAttribute#hash`, which calls and memoizes `value_for_database`, invoking the application's type serializer. Capturing the same clauses is not enough: computing their difference later changes observable work, even without overriding `==`, `eql?`, or `hash`.

Two independent reproductions are retained here. This thread reran both against the actual base and candidate checkouts on SQLite and PostgreSQL, not method substitutes:

| Reproduction | Base | Candidate | Boundary control |
| --- | --- | --- | --- |
| [composite_serialization.rb](composite_serialization.rb): 17-column key, association scope changes the custom integer serializer's offset | SQL keys 1…17, record `[1]` | SQL keys 101…117, record `[2]` | At 16 columns both select record `[2]` |
| [join_serialization.rb](join_serialization.rb): ordinary scalar owner key, polymorphic `has_many`, 17 target-default-scope predicates, a second joined association changes serializer context | `children.k0 = 1`, record `"k0=1"` | `children.k0 = 101`, record `"k0=101"` | At 16 predicates both select `"k0=101"` |

Every divergent row reproduces with the setting **false and true**, on **both adapters**. Raw SQL/results are in [`raw/composite-*`](raw/) and [`raw/join-*`](raw/). The scoped composite example also gave identical base/base and candidate/candidate repeat outputs in scratch validation. Restoring only `association_scope.rb` to the base in a disposable third tree fixes the composite example but leaves the join example broken: both changed methods need attention.

[key_calls.rb](key_calls.rb) independently counts custom type comparison/hash calls. At 16 columns base and candidate match; at 17, an association without a scope invokes `hash` **94 times on base versus 26 on the candidate**, under both settings. A scoped association invokes 111 in both, but equal totals do not preserve timing. There is no evidence of a security exploit; the verified defect is changed SQL and selected records.

**Smallest safe correction:** restore the original eager subtraction/check path wherever those operations can invoke user-backed hashing/serialization, including the no-association-scope join path; do not postpone the scoped path across callbacks. Restoring the eager code is the immediate safe correction. Keeping a fast path needs a narrower, demonstrated-safe predicate/type boundary and regression tests for these two cases. Do not hard-code 17 as a portable contract: the array implementation/threshold is Ruby-dependent. This pass does not certify an unimplemented guard or a new head.

## P2: the performance prose exceeds its evidence

The five interpreter table rows in [A1.md](../../pr-queue/items/A1.md) match `body/a1/results.json` and its raw Callgrind/object windows. The maintainability reviewer reconstructed all 36 instruction measurements from N=0/N=2,000 pairs and checked all 36 raw object cells. The synthesis also recomputed every JSON delta and A/A. These are instructions, not elapsed time; no new speed measurement was performed for this review. The YJIT columns below are ungated observations, not certified steady-state speed claims.

| Case | Interpreter Δ | Interpreter A/A | YJIT Δ | YJIT A/A |
| --- | ---: | ---: | ---: | ---: |
| `author.posts` | −1.8179% | 0.0145% | −1.7833% | 0.0346% |
| `author.profile` | −2.1960% | 0.0757% | −2.0444% | 0.2540% |
| `comment.post` | −2.2966% | 0.0402% | −1.2311% | 0.0014% |
| through | −1.5828% | 0.0545% | −1.2515% | 0.2195% |
| `joins(:posts)` | −3.0404% | 0.0104% | −4.1251% | 1.1161% |
| scoped control | −0.1448% | 0.0578% | **+0.2786%** | **0.0960%** |

**Must fix:** “An association with a scope is unchanged” is not supported. Allocations are unchanged (169 interpreter / 172 YJIT), but the YJIT candidate's 373,261 instructions exceed both base runs (372,045 / 372,403). The +0.3% is not inside 0.10% A/A; one A/A pair is not a confidence interval. The record's attribution to the flag and extra locals is a hypothesis, not an isolated causal measurement.

Suggested qualified wording if the observation is retained: **“Scoped allocations are unchanged; the YJIT instruction count was +0.3% (A/A 0.10%, diagnostic; JIT flatness was not recorded).”** For an upstream body, omitting ungated YJIT claims until certified is simpler.

**Must fix:** `script/upstream-bench` performs 3,000 fixed warmup calls but records no compilation/invalidation counters. Its raw workers and results therefore cannot establish the repository's mandatory JIT-flat gate for the body cohort. Remove the unqualified “With YJIT … 1.2% to 4.1% fewer instructions” speed claim or mark the numbers diagnostic pending a properly gated cohort. The separate census micro does record compilation, but is another cohort and its `has_many` window is explicitly not flat. No rejected cohort was rerun until green. Ruby master × ZJIT is still missing and remains a separate opening gate, not something this review ran.

## Body and kamipo-note sentence audit

* **Title and causal introduction:** supported for the ordinary `AssociationScope` path. The upstream changes intentionally preserve the owner key/type, or warn under the old setting. Both upstream PRs were read with `gh` before this thread's audit; the correctness reviewer independently audited before reading discussion. The discussion does not resolve the serialization issue above.
* **“Five … and joins one” / note “two for every join”: must fix.** [difference_count.rb](difference_count.rb) instruments the real body fixture: base performs five subtractions per ordinary association-scope build and **three per simple `join_scope` call** (one fixed subtraction plus both removed-key/type subtractions); the candidate skips all of these without a scope. The scoped control retains all five. The reader count includes the helper, so the join count must too. Measured total savings remain ten objects per reader and eight per simple join; three differences alone explain six objects, not all eight.
* **“Keeps the clauses and computes differences only when a scope was merged”:** a fair high-level account of `add_constraints`; in `join_scope` the fixed difference still precedes the merges, inside the new nonempty-items guard.
* **“SQL, records and deprecation warnings stay the same,” both settings:** false as a universal claim at this head; see the two executed counterexamples. Ordinary owner-removal checks still fire identically in the cases exercised below. Do not publish the universal statement until corrected code is re-reviewed.
* **Ruby 4.0.9 / no-JIT table heading and all five rows:** verified against metadata and raw data. Objects main→candidate: 121→111, 101→91, 101→91, 158→148, 107→99. Instruction values and one-decimal changes match every row.
* **YJIT range and scoped-control sentence:** numerically audited, but require the corrections above.
* **Note's 107 main / 96 before the owner-condition work:** supported by the older census micro's 107.04 / 96.04 object cells, not by the body harness's 121-object setup. This review did not rerun historical commits or certify the note's incomplete class-only snippet as a standalone allocation reproduction. Say “in this fixture” and link/provide its setup if keeping these numbers.
* **Note's branch head and +17/−10:** verified against the fetched commit and stored patch.
* **Note's record/A/A references:** they point to the retained record; per-cell A/A exists. “Follows the approved style” needs qualification: the cited unsolicited-comment policy says no unasked-for numbers, while this draft includes numbers. Posting still needs Thomas's approval of the exact text; this review grants none.

## Ordinary behavior and warnings match in the exercised cases

The original `census10/a1_diff_probe.rb` reran byte-identically: 334 lines with the setting false, 320 true; its 14/0 warning lines and four instance-dependent eager-load errors agree. Its actual contract is normalized SQL, sorted record identities, unique warning text, and truncated exception messages—not all record attributes/order or every warning occurrence. The existing CPK/`disable_joins` probe also reran identically.

[extended_probe.rb](extended_probe.rb) adds **118 cases**, retaining attributes in returned order, callback events in order, and all warning occurrences (only call-site suffixes normalized). It covers `unscope(:where)`, `or`, `merge`, `none`, `extending`, target default scopes, target STI, explicit `inverse_of`, strict-loading success/error paths, scoped through and nested through, `disable_joins`, and polymorphic type replacement. Each association goes through load, SQL, preload, includes, eager_load, joins, left_joins, and where.associated. The original prefix also covers instance-dependent scopes, `rewhere`, STI owners, polymorphic `belongs_to`, creation/deletion, and counts.

Extended base/candidate output is byte-identical for both settings: **806 / 792 lines**, SHA-256 respectively `f253f93e8161a0a5d33207c7ca9d8f993cdba8aa1fbc00f90d5e44a4c1d82e77` and `8aae9efe9f659b808117294501fdfb0c4403fbeb7e4260629af2a585f6de137b`. In particular, false still warns on removed owner keys/types; true still re-adds conditions without those warnings. The added warning lists are not deduplicated. These finite passing cases do not override the demonstrated failures.

The supporting README's premises need correction: predicate arrays are not generally frozen, and Arel nodes hold user types/values. Its “no user-supplied object reaches the changed lines” and universal call-order argument are false. `disable_joins` is unchanged, but it still computes its type difference and final check unconditionally; saying it already computes all differences “only when needed” is inaccurate. The census's “every difference is empty” should say the *removed* clauses are empty; the owner key clause is not.

## Suites ran on both exact trees

| Adapter | Base | Candidate |
| --- | --- | --- |
| SQLite 3.54.1 / sqlite3 gem 2.10.2 | 3,270 runs, 10,737 assertions, 0 failures, 0 errors, 1 skip | Same |
| PostgreSQL 17.12 / pg gem 1.7.0 | 3,275 runs, 10,750 assertions, 0 failures, 0 errors, 0 skips | Same |

Ruby 4.0.9, minitest 6.0.0, with `-w`. Raw full output is in `raw/tests-{base,head}-{sqlite3,postgresql}.txt`. The SQLite skip is the existing `WhereTest#test_with_tuple_syntax_and_large_values_list` at `relation/where_test.rb:207`, intentionally skipped because SQLite's expression-tree depth is 1,000; a separate verbose rerun confirmed its identity. Suite setup enables the new setting; the upstream owner-condition tests exercise explicit old-setting blocks as well. The probes separately set false and true in fresh processes.

From each tree's `activerecord` directory, with the selected adapter in `ARCONN`:

```sh
ruby -w -I../railties/lib -I../activesupport/lib -I../activemodel/lib -Ilib -Itest \
  -e 'ARGV.each { |f| require File.expand_path(f) }' \
  test/cases/associations/*_test.rb test/cases/associations_test.rb \
  test/cases/reflection_test.rb test/cases/relation_test.rb test/cases/relations_test.rb \
  test/cases/relation/*_test.rb test/cases/scoping/*_test.rb
```

Environment-only startup issues were resolved before the passing runs: installed `builder`; loaded Rails' minitest plugin via `railties/lib`; ran the base PostgreSQL suite after the candidate released its database slot, avoiding a missing-locale error while trying to create a second slot. No tests were excluded to obtain the green results. MySQL was not run.

## Reproduce the counterexamples

Use Ruby 4.0.9 and set `RAILS` to either exact checkout. From the Lowrail root:

```sh
RAILS=/absolute/path/to/rails KEEP=0 WIDTH=17 \
  ruby bench/upstream/a1/review-thermos-sol/composite_serialization.rb
RAILS=/absolute/path/to/rails WIDTH=17 \
  ruby bench/upstream/a1/review-thermos-sol/join_serialization.rb
```

Repeat the first with `KEEP=1`, and both with `WIDTH=16` for the controls. The join script tests both setting values itself. For PostgreSQL, add `ADAPTER=postgresql DATABASE=a1_thermos_probe` after creating that **disposable** database. The scripts replace only their own named tables there; never point them at an application database. Extended probes and difference counts additionally take `LOWRAIL_ROOT=/absolute/path/to/lowrail`.

## Maintainability and limits

Keep the direct local form if a correct narrowed optimization survives. The snapshot names and Boolean fit the existing traversal; `unless scope_chain_items.empty?` is idiomatic Rails. A helper, `flat_map`, or a second `chain.any? { ...constraints... }` traversal adds allocations/work or risks observing changed reflection state; no shorter, equally clear and proven-equivalent form was found. Reflection's large file size predates this patch and is not a reason to restructure it here.

Independent correctness review and independent maintainability/claims review ran concurrently as read-only subagents, loading `thermo-nuclear-review` and `thermo-nuclear-code-quality-review` respectively. Their findings were reconciled against direct executions above. No nested reviewers or other threads were created. The review is scoped to the pinned head, not future revisions. It does not certify universal behavior, MySQL, a new speed cohort, Ruby master/ZJIT, or an upstream posting decision.
