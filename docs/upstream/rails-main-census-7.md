# Rails-main allocation census 7: after the second merge wave

Census 7 reruns [`script/census`](census.md) on canonical Rails main after the 2026-11-03 merges of 22 of our 29
PRs from this cycle, over census 6's corpus: 23 configurations, 20 apps, 251 workloads, interpreter and YJIT, with
an A/A pair.

**Result.** Since census 6's pin, Rails main allocates **2.2% fewer objects** over all 251 workloads (median
**−135 / −136 objects per workload**, 247 / 248 of 251 moved). The top of the ranking is now required work
(results, Relations, AST, attributes, output) or covered by open PRs (ours: #59557, #59562, #59564, #59569;
others': #59141, #58002, #57999). Two new exact candidates came out of the uncovered top tier, both in
query building that every app runs:

| # | Branch | Per call (interp) | Workloads moved (of 251; A/A 59 / 43) | Median per workload |
| --- | --- | ---: | ---: | ---: |
| C7-1 | [`thomasklemm/order-args-without-copies`](https://github.com/thomasklemm/rails/tree/thomasklemm/order-args-without-copies) [`3fabb64425`](https://github.com/thomasklemm/rails/commit/3fabb644258855352b2e29997c2856b5d6b847f6) | `order(:id)` −6, `order(created_at: :desc)` −13 | 199 / 206 | **−13.6 / −14.3** |
| C7-2 | [`thomasklemm/where-clause-ast-single-predicate`](https://github.com/thomasklemm/rails/tree/thomasklemm/where-clause-ast-single-predicate) [`f903005e49`](https://github.com/thomasklemm/rails/commit/f903005e4902c0c989c52946ac2893aba579c038) | `where(id: 1)` −1 | 187 / 192 | **−4.0 / −3.8** |

Interpreter / YJIT, Ruby 4.0.7. Allocation counts only; no timing is inferred. Both branches are one commit on the
pin, independent of each other and of every open PR of ours (`git merge-tree` clean against #59564, #59569, #59571
and others' #59377, #59413).

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`b084108cf3`](https://github.com/rails/rails/commit/b084108cf37bacb47c269684a7576f7ac2296983) (merge of #59572),
  checked with `gh api repos/rails/rails/commits/main` on 2026-11-03 09:46 UTC. 22 commits after census 6's
  `3bdc579090`, including our #59552, #59556, #59558, #59560, #59561, #59563, #59568 and others' #59550, #59531,
  #59566, #59572.
* **Ruby 4.0.7**, interpreter and `--yjit`; production; disposable orb services (Redis, memcached, MySQL 8.4.10 on
  3307, PostgreSQL 15 with pgvector 0.8.1 and pg_partman on the local socket).
* **Corpus:** all 23 configurations set up fresh on the pin (`script/census setup --rails b084108cf3…`, one copy
  per app, census 6's overlays). One base for all apps, so every label ran in a single `run`.
* **Runs:** `run --label c7 --aa --modes interp,yjit --jobs 6` (labels `c7`, `c72`); `run --label c6p --rails
  rails/rails@3bdc579090…` (census 6's pin on the same copies, for the merge-wave comparison); `--label order` and
  `--label whereast` for the candidates. Compared against `c72`; `c7` is the A/A.
* **Ranking:** `rank --label c72` (≥ 0.5 objects/op reaches a workload; tiers by apps, ≥ 7 first; within a tier by
  mean objects/op over all 251 workloads). Open PRs: `prs --label c72 --top 200 --refresh` (1,242 open rails/rails
  PRs, fetched 2026-11-03 10:24 UTC).
* **Setup notes (this orb):** as census 6, plus: the PostgreSQL cluster's `pg_hba.conf` needed `trust` for local TCP
  (CodeTriage connects to `localhost`); Discourse's `prepare` logs `libvips 8.18 or newer is required` from its
  image worker (the orb has 8.14) without failing a workload; Docuseal's pdfium stub was rebuilt (the real library
  gets SONAME `libpdfium_real.so`, a 9-symbol stub `libpdfium.so` links it). The AR suite's four
  `SqliteStructureDump/LoadTest`s need the `sqlite3` CLI, which the orb lacked.

### A/A

`c72 − c7` over 251 workloads: median +0.0 / +0.0; 59 / 43 moved ≤ −1 and 54 / 62 moved ≥ +1; SQL changed on 1 / 3
workloads. Mastodon is again fully deterministic (0 of 28). Census 6's A/A on the same corpus: 43 / 53 and 55 / 40.

### The merge wave against census 6

`c72` vs `c6p` (census 6's pin measured today on the same copies and databases):

| App | Median per workload | All allocations |
| --- | ---: | ---: |
| sure | −613.8 / −608.1 | −1.18% / −1.17% |
| chatwoot | −440.9 / −445.7 | −3.81% / −3.77% |
| casa | −429.1 / −427.6 | −3.00% / −2.97% |
| mastodon (and -nops) | −412.0 / −412.0 | −1.88% / −1.87% |
| lago (and -nops) | −381.6 / −381.8 | −5.01% / −4.95% |
| discourse | −368.7 / −382.1 | −3.34% / −3.22% |
| flow | −313.9 / −308.1 | −2.79% / −2.75% |
| loomio | −259.3 / −265.8 | −4.66% / −4.61% |
| docuseal | −171.8 / −174.3 | −2.06% / −2.05% |
| hackatime | −140.8 / −139.0 | −1.79% / −1.77% |
| fizzy, fizzy-mysql | −87 to −96 | −0.9% to −1.0% |
| codetriage | −68.3 / −68.9 | −2.32% / −2.33% |
| lobsters | −63.9 / −63.6 | −0.64% / −0.63% |
| pingcrm | −47.6 / −45.8 | −1.64% / −1.52% |
| writebook | −45.7 / −44.8 | −0.79% / −0.78% |
| redprints-cfp, react-starter-kit, campfire, blog, thinkroom | −12 to −17 | −0.3% to −1.6% |
| **All 251 workloads** | **−135.0 / −135.9** (247 / 248 moved) | **−2.17% / −2.15%** |

The PostgreSQL apps gain most: #59558 and #59560 removed the per-result scratch Arrays and per-column type-map keys
(census 6 ranks 3, 112–114). "All allocations" sums each workload's median objects per operation, so large pages
dominate it. The A/A on the same measure is −0.16% / −0.07%.

## Ranking

Top of the interpreter ranking on `c72`, 23 configurations, 20 apps, lines reaching ≥ 7 apps. The YJIT top 80 is
the same set plus `core.rb:481` (the model's base Relation) and `abstract_adapter.rb:1426` (query collectors), both
required, as in census 6. Gone since census 6: `postgresql_adapter.rb:1047` (#59560), `postgresql/database_statements.rb:232/233`
(#59558), `attribute_accessors_per_thread.rb:59` (#59561), `reflection.rb:276` (#59552); `relation.rb:1345` fell
from 30.0 to 5.9 / op (#59556).

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1 | AS `enumerable.rb:317` `index_with` pairs | 20 / 96% | 370.1 | Covered by our open #59557 (Ruby 4.1); required on 4.0. |
| 2, 6 | AR `postgresql/database_statements.rb:256/228` | 12 / 63% | 183.3, 89.2 | Result values and fields. Required. |
| 3, 22, 30, 69–77 | Arel attributes, select statement/core, Equality | 20 / 91–95% | 16–114 | Per-query AST. Required. |
| 4, 13, 17, 33 | AS `output_safety.rb:245/73`, AV `tag_helper.rb:1545/1540` | 19 / 37–49% | 24–102 | Output. Required; open #57999 on attribute strings. |
| 5, 26, 39 | AR `where_clause.rb:32/18`, `query_methods.rb:1989` | 18–20 / 82–94% | 22–96 | Built clauses. Required. |
| 7, 47, 122 | AM `attribute.rb:10/18/14` | 19–20 / 44–86% | 10–79 | Attribute objects. Required. |
| 8, 9, 16 | AR `delegation.rb:140`, `relation.rb:80/101` | 20 / 91–95% | 50–67 | Relations and their values. Required. |
| 10 | AM `type/string.rb:40` | 20 / 94% | 61.8 | Defensive copy. Required. |
| 11, 15, 18, 27, 28, 100 | AM `attribute_set.rb`, `builder.rb:20`, `indexed_row.rb`, AR `result.rb:196` | 18–20 / 39–97% | 11–61 | Covered by open #59141 (tenderlove) and #58002. |
| 12, 31, 32 | AR `predicate_builder.rb:146/129`, `query_methods.rb:1963` | 20 / 92–93% | 25–56 | Predicates, binds, normalized keys. Required. |
| 14, 35 | AR `associations.rb:62/85` | 20 / 90–92% | 52.7, 22.9 | Association objects and caches. Required. |
| 19, 24, 25 | AS `notifications/fanout.rb:379/378/381` | 20 / 97% | 31–40 | Per delivered event; open #58957. Required while subscribed. |
| 20 | AS `deep_dup.rb:18` | 18 / 80% | 39.5 | App payloads. Not Rails' own work. |
| 21, 36, 45, 89, 91, 98, 101, 113 | AR `preloader/branch.rb`, `batch.rb` | 15–17 / 39–45% | 10–32 | Covered by our open #59564 (with C6-2 folded in). |
| 23, 43 | AS `time/calculations.rb:173/168` | 20 / 55–58% | 31.5, 20.7 | Rejected in R2. |
| 29 | AR `persistence.rb:278` | 20 / 97% | 30.4 | Records. Required. |
| 34 | AR `spawn_methods.rb:51` Merger | 20 / 88% | 24.1 | Required. |
| 37 | AR `association_scope.rb:159` | 20 / 84% | 22.6 | `where!(key => value)`: Hash argument and `*rest`. VM lead (census 6). |
| 38, 60 | AR `scoping/default.rb:170/66` | 20 / 91–94% | 22.6, 17.0 | `method(:default_scope).owner`: no exact fix (R6 lead 2). |
| 41 | AR `abstract_adapter.rb:1270` RetryBudget | 20 / 96% | 21.3 | Required. |
| 49, 50 | AP `url.rb:169`, `journey/visitors.rb:38` | 19 / 55% | 18.1 | R2 lead (`path_for` ownership). |
| 51 | AR `query_methods.rb:1284` `where!(*args)` | 19 / 89% | 18.1 | VM lead (named rest). |
| 54 | AR `delegation.rb:81` | 18 / 67% | 17.6 | Scope callees' `*args, **kwargs`; our open #59571 removes them for parameterless lambdas. |
| 57, 58 | AP `rendering.rb:64`, AV `base.rb:317` | 19 / 52% | 17.3, 17.2 | `view_assigns`. Required (R2). |
| 59, 61, 62 | AP `route_set.rb:230/233/318` | 18 / 49% | 17 | R2-3 held; the params Hash. |
| 63 | AS `callbacks.rb:105` | 20 / 97% | 16.8 | Required. |
| **66** | AR `where_clause.rb:194` `predicates_with_wrapped_sql_literals` | 20 / 91% | 16.2 | **C7-2** for single-predicate clauses; several predicates need the Array. |
| 67, 68 | AR `query_cache.rb:320`, `result.rb:165` | 20 / 90% | 16.1 | Query-cache copies. Required. |
| **78, 131** (+ `:2439`, 205) | AR `query_methods.rb:2392` `flattened_args`, `:2460`/`:2439` `column_references` | 19 / 73–78% | 15.9, 9.0, 5.2 | **C7-1**. |
| 86 | AR `querying.rb:84` `"#{name} Load"` | 20 / 96% | 13.7 | Rejected (census 6). |
| 87 | AR `reflection.rb:765` | 20 / 87% | 13.1 | Chain Array. Required. |
| 88 | AR `arel.rb:62` | 19 / 73% | 12.9 | `Arel.sql` rest/kwrest. VM lead. |
| 97 | AR `to_sql.rb:793` | 18 / 67% | 11.5 | Rejected (census 6). |
| 104 | AS `hash_with_indifferent_access.rb:332` `merge(...)` | 20 / 81% | 10.7 | The HWIA copy is the result; the Array is `update(*other_hashes)`'s rest. VM lead. |
| 106 | AR `quoting.rb:219` `type_casted_binds` | 19 / 73% | 10.5 | The cast binds handed to the driver. Required. |
| 108, 123 | AR `result.rb:118`, `querying.rb:99` `column_types.reject` | 20 / 90–92% | 10.4, 9.5 | `Result#column_types` keys every type by name and by index, so the rejected copy is never empty and is read per record. Required. |
| 109, 119 | AR `querying.rb:104/114` | 20 / 96% | 10.1, 9.7 | Instrumentation payload and the records Array. Required. |
| 120 | AS `subscriber.rb:142` | 20 / 92% | 9.6 | Covered by our open #59562. |
| 121 | AR `query_methods.rb:2213` `arel.project(table[Arel.star])` | 20 / 82% | 9.5 | `SelectManager#project(*projections)`'s rest Array. VM lead. |
| 162–164 | AR `association_scope.rb:104/105/107` | 20 / 86% | 7.5 | Covered by our open #59569. |

The full rankings are in the receipts (`rank-c72-interpreter.tsv`, `rank-c72-yjit.tsv`).

## C7-1: check and reference order arguments without copies

Every `order`/`reorder` call runs `preprocess_order_args`. It flattened the arguments for the raw SQL check with a
recursive `flat_map` (`flattened_args`), and collected the tables they reference with `flat_map` plus
`filter_map` (`column_references`). For `order(:id)` or `order(created_at: :desc)` those are Arrays read once, or
Arrays that end up empty.

```diff
       def flattened_args(args)
-        args.flat_map { |e| (e.is_a?(Hash) || e.is_a?(Array)) ? flattened_args(e.to_a) : e }
+        # Symbols, Strings and Arel nodes need no copy.
+        return args unless args.any? { |e| e.is_a?(Hash) || e.respond_to?(:to_ary) }
+
+        flat = []
+        args.each { |arg| flatten_arg(arg, flat) }
+        flat
       end
 ...
       def column_references(order_args)
-        order_args.flat_map do |arg|
+        references = nil
+        order_args.each do |arg|
 ...
-        end.filter_map { |ref| Arel.sql(ref, retryable: true) if ref }
+        references || FROZEN_EMPTY_ARRAY
       end
```

**Why it is exact.** `disallow_raw_sql!` (and `pluck`'s caller in `calculations.rb`) only iterates the flattened
Array, so passing the arguments themselves when nothing needs flattening is invisible. `flatten_arg` visits Hash
keys then values and Array elements recursively, in the order `flat_map(&:to_a)` did, and splices an object that
responds to `to_ary` one level deep, as `flat_map` does (`Array.try_convert`, the same `rb_check_array_type`).
`column_references` appends the same `Arel.sql` literals in the same order; both callers only read the result and
skip it when empty. A randomized comparison against the old methods (20,000 nested inputs each, with `to_ary`
objects, `nil`-returning `to_ary`, Arel attributes and orderings) found no difference.

**Per-call micro** ([`micro_c7.rb`](../../bench/upstream/census7/micro_c7.rb), SQLite in memory):

| Call | Objects, main → C7-1 (interp) | (YJIT) |
| --- | ---: | ---: |
| `Post.order(:id).to_a` | 107 → **101** | 109 → **103** |
| `Post.order(created_at: :desc).to_a` | 122 → **109** | 124 → **111** |
| `Post.order("posts.title").to_a` | 124 → **119** | 126 → **121** |
| `author.posts.order(:id).to_a` | 158 → **152** | 161 → **155** |

Timings were taken while the census ran and are not claimed.

**Census** (`order` vs `c72`, A/A `c7`): **199 / 206** of 251 workloads moved ≤ −1 (A/A 59 / 43), 18 / 14 moved ≥ +1
(A/A 54 / 62); median **−13.6 / −14.3**; −0.47% / −0.42% of all allocations (A/A −0.16% / −0.07%). Moved in 18 of
20 apps (Blog and Campfire order little): Sure −92 / −98, Mastodon −57, Lobsters −33 / −50, CASA −33, Lago −32,
Flow −31 / −28, Discourse −31 / −24, Hackatime −27 / −23, Thinkroom −25 / −27, Writebook −14, Fizzy −13 / −22,
Chatwoot −13 (its conversation list −2,608).

**SQL.** Changed digests: Discourse `GET topic.json` (changes in the A/A too), Flow `GET projects` under YJIT (same
digest in the A/A), and Mastodon interpreter `GET profile`, `GET public timeline`, `GET account statuses`. The
Mastodon digests are byte-identical to those of `c6p`, a label without the change (census 6's pin), measured in the
same window; C7-1's YJIT run, measured later, matches `c72`. Database drift, not the change.

**Behavior control.** [`control_order_where.rb`](../../bench/upstream/census7/control_order_where.rb) prints
`references_values`, `eager_loading?`, the SQL and the loaded ids (or the error) for 27 shapes: Symbol, Hash,
String, other-table String, nested Hash, String-key Hash, Arel attribute and ordering, `Arel.sql`, Arrays with and
without binds, a `to_ary` object, raw SQL at the top level, nested in an Array and in a Hash, a bad direction,
`reorder`, `in_order_of`, `pluck`, and the WHERE shapes for C7-2. **Identical** on main, C7-1 and C7-2, interpreter
and YJIT (50 lines).

**Tests and suites.** One new test: raw SQL nested in an Array and in a Hash among the order arguments still raises
`UnknownAttributeReference` (the recursive path). Active Record `test:sqlite3` with `RAILS_STRICT_WARNINGS=1`,
`SEED=41231`: main 10,258 runs, 36,627 assertions, 0 failures, 0 errors, 52 skips; C7-1 10,259 runs (the new test),
0 failures, 0 errors, 52 skips. RuboCop clean.

**Overlap.** Open #59413 (czj) changes the `disallow_raw_sql!` call two lines below `flattened_args`; it merges
cleanly with C7-1 and is independent (it defers the matcher lookup, C7-1 the argument copies). No open PR touches
`flattened_args` or `column_references`.

### PR draft (short form, not published)

**Check and reference order arguments without copies**

> Every `order`/`reorder` call runs `preprocess_order_args`, which flattens the arguments for the raw SQL check with
> a recursive `flat_map`, and collects the tables they reference with `flat_map` and `filter_map`. For the common
> `order(:id)` or `order(created_at: :desc)` these are Arrays that are read once or end up empty.
>
> This hands Symbol, String and Arel arguments to the check as they are, and flattens nested Arrays and Hashes into
> a single Array (objects with `to_ary` are still spliced, as `flat_map` did). `column_references` appends only actual
> references and returns a frozen empty Array when there are none. Same check, same references, same order.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | `Post.order(:id).to_a` | 107 objects | 101 |
> | `Post.order(created_at: :desc).to_a` | 122 | 109 |
> | `Post.order("posts.title").to_a` | 124 | 119 |
>
> Across 20 open-source apps on Rails main, 199 of 251 request, job and mailer workloads allocate fewer objects
> (median −14 per workload).

## C7-2: compile a single-predicate WHERE clause without a nodes Array

`WhereClause#ast` runs for every query Active Record compiles (not for statement-cached association reads). It
collected the wrapped predicates into a new Array and, when there was exactly one, returned its first element.

```diff
       def ast
-        predicates = predicates_with_wrapped_sql_literals
-        predicates.one? ? predicates.first : Arel::Nodes::And.new(predicates)
+        if predicates.size == 1 && (node = predicates.first) && !node.eql?("")
+          wrap_sql_literal(node)
+        else
+          nodes = predicates_with_wrapped_sql_literals
+          nodes.one? ? nodes.first : Arel::Nodes::And.new(nodes)
+        end
       end
```

**Why it is exact.** For one predicate the old path built `[wrap(node)]` unless the node `eql?("")`, and returned
its first element when `one?` (truthy) held. The new branch takes exactly the cases where the old result was
`wrap(node)`: one predicate, truthy, not `eql?("")`. A `nil`/`false` predicate or an empty String takes the old
path, which still returns `And.new(...)` for them. `wrap_sql_literal` is the extracted `case` from
`predicates_with_wrapped_sql_literals`, used by both paths.

**Per call:** `Post.where(id: 1).to_a` 92 → **91** (YJIT 95 → **94**); `author.posts.order(:id).to_a` 158 → **157**;
`Post.where(id: 1, title: "t")` unchanged (two predicates).

**Census** (`whereast`, measured at `e1e6f9e361`, which differs from `f903005e49` only by the test): **187 / 192** of
251 moved ≤ −1 (A/A 59 / 43), 25 / 18 moved ≥ +1 (A/A 54 / 62); median **−4.0 / −3.8**; −0.04% / −0.06% of all
allocations (within the A/A on that measure, which large pages dominate). 18 of 20 apps: Sure −40 / −43, Flow
−14 / −15, Lobsters −10 / −8, Discourse −8 / −3, Mastodon −7, Lago −6. SQL: the same drift as C7-1 (Discourse
`topic.json`; Flow `projects` YJIT; Mastodon's 17.5-query profile, here on mastodon-nops).

**Tests and suites.** One new test: `ast` of a single node returns that node, a single SQL literal is grouped, and a
single empty String gives `And([])`; removing the `eql?("")` guard fails it. Active Record `test:sqlite3`
(`RAILS_STRICT_WARNINGS=1`, `SEED=41231`): 10,259 runs, 0 failures, 0 errors, 52 skips. Control identical (above).
RuboCop clean. No open PR touches `ast`; #48531 changes `except_predicates` in the same file and merges cleanly.

### PR draft (short form, not published)

**Compile a single-predicate where clause without a nodes Array**

> `WhereClause#ast` runs for every query Active Record compiles. It collects the predicates, wrapping SQL literals,
> into a new Array, and when there is only one predicate it returns that Array's first element. So `where(id: 1)`
> allocates an Array it never uses.
>
> A clause with one predicate that is not an empty String now wraps that predicate directly. Clauses with several
> predicates, or with an empty String, take the existing path, so the AST is unchanged.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | `Post.where(id: 1).to_a` | 92 objects | 91 |
> | `author.posts.order(:id).to_a` | 158 | 157 |
>
> Across 20 open-source apps on Rails main, 187 of 251 request, job and mailer workloads allocate fewer objects
> (median −4 per workload).

## Not built

* **VM leads (ruby/ruby):** named `*rest` parameters allocate even when nothing is passed: `where!(opts, *rest)`
  (ranks 37, 51), `Arel.sql` (88), `HashWithIndifferentAccess#update(*other_hashes)` from `merge` (104),
  `SelectManager#project(*projections)` (121). Same family as census 6; nothing Rails-side is exact.
* **Required:** `column_types.reject` in `_load_from_sql` (108, 123): the Hash keyed by name and index is read per
  record. `type_casted_binds` (106): the cast values. Results, Relations, AST nodes, attributes, output, as before.
* Census 6's leads and rejections are unchanged (`default_scope` owner checks, `path_for`, `"#{name} Load"`,
  `SqlLiteral#to_s`, Time Rationals).

## Limits

* Allocation counts from one process per configuration and mode, judged against the A/A. No timing claims.
* `c6p` is census 6's pin measured on census 7's copies, so the merge-wave comparison shares databases and data;
  it is not census 6's `c62` receipts (those copies are gone).
* Local suites only (SQLite adapter); no hosted CI on the fork branches yet.
* Receipts: [data/rails-main-census-7/receipts.tar.gz](data/rails-main-census-7/receipts.tar.gz): both rankings,
  label metadata, the A/A, merge-wave and candidate comparisons (`--detail`, `--markdown`), the open-PR map, the
  SQL digest diffs, the micro, the control and the suite summaries.
