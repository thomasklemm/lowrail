# Rails-main allocation census 6: after the merge wave, on a 16-app corpus

Census 6 reruns [`script/census`](census.md) on canonical Rails main after the 2026-11-03 merges (#59551, #59553,
#59554, #59555 since census 5's pin) over the larger corpus: census 5's nine apps plus the seven PostgreSQL apps of the
[PG census](pg-census.md) with its two `-nops` configurations. 19 configurations, 16 apps, 206 workloads, interpreter
and YJIT, with an A/A pair.

**Result.** The merge wave saved a median 9 / 8 objects per workload on census 5's nine apps. With the bigger corpus,
the broadest new uncovered area is **Active Record's preloader bookkeeping**: `Preloader::Batch#call` rebuilds each
branch's future classes and runnable loaders on every pass, copying Arrays that are read once. It is in 14 of 16
apps. One exact candidate, **C6-1 (`thomasklemm/preloader-batch-arrays-in-place`)**, builds those Arrays in place:
−9 to −40 objects per `preload` call, 98 / 95 of 206 workloads moved (A/A 30 / 36), and a median −71 objects on the
97 workloads that preload. Every other top site is required work, covered by an open PR (ours or others'), or a
lead; see [Ranking](#ranking).

| # | Branch | Per call | Workloads moved (of 206; A/A 30 / 36) | Median, workloads that preload (97) |
| --- | --- | ---: | ---: | ---: |
| C6-1 | [`thomasklemm/preloader-batch-arrays-in-place`](https://github.com/thomasklemm/rails/tree/thomasklemm/preloader-batch-arrays-in-place) [`2b53fa5cbe`](https://github.com/thomasklemm/rails/commit/2b53fa5cbe88de7d80615bc75f5e325566781a00) | −9 / −22 / −40 objects per preload of 1 / 2 / 4 associations | 98 / 95 | −71 / −72 |

Interpreter / YJIT, Ruby 4.0.7. Allocation counts only; no timing is inferred.

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`3bdc579090`](https://github.com/rails/rails/commit/3bdc57909066eb17dee70fea0b6266edaffa9ffc) (merge of #59555),
  checked with `gh api repos/rails/rails/commits/main` on 2026-11-03 02:40 UTC. Eight commits after census 5's
  `5810776eec`: #59551, #59553, #59554, #59555. The candidate is one commit on it.
* **Ruby 4.0.7**, interpreter and `--yjit`; production; services as disposable orb services (Redis, memcached,
  MySQL 8.4 on 3307, PostgreSQL 15 on the local socket).
* **Runs:** `script/census run --label c6 --aa --rails rails/rails@3bdc579090… --modes interp,yjit` (labels `c6`
  and `c62`), then `--label preload --rails thomasklemm/rails@thomasklemm/preloader-batch-arrays-in-place`. Census 5's
  ten copies stay on their setup base (`5810776eec`) and are measured at the pin through the variant Gemfile; the PG
  copies were set up on the pin. `run` refuses one run across copies with different setup bases, so each label ran in
  two groups (census 5's ten configurations, then the nine PG configurations). Compared with `c62`; `compare --aa c6`
  is the noise floor.
* **Corpus (19 configurations, 16 apps):** blog, campfire, writebook, fizzy, fizzy-mysql, codetriage, pingcrm,
  redprints-cfp, react-starter-kit, lobsters; docuseal, mastodon, mastodon-nops, lago, lago-nops, discourse, loomio,
  sure, casa. **Not yet included:** L6's Chatwoot, Flow, Hackatime and Thinkroom
  ([T-01a19f0e](https://ampcode.com/threads/T-01a19f0e-9c5f-75be-8474-3cf9e9efa623)) were not on Lowrail main or a
  pushed branch when this round ran (their overlays and `script/census` rows were uncommitted in L6's orb). Add them
  with `script/census setup` and a `c6`/`c62`/`preload` run of those apps when they land.
* **Ranking:** `script/census rank --label c62` (a line reaches a workload at ≥ 0.5 objects per operation; tiers by
  apps reached, ≥ 7 first; within a tier by mean objects per operation over all 206 workloads). Open PRs from
  `script/census prs --label c62 --top 130` (1,240 open rails/rails PRs fetched 2026-11-03 02:54 UTC).
* **Setup notes (this orb):** the PG apps needed system packages that the orb image lacks: pgvector 0.8.1 built from
  source and `postgresql-15-partman` (Discourse, Lago), `libidn11-dev` (Mastodon's `idn-ruby`), `liblept5` and
  pdfium (Docuseal; the bblanchon `chromium/8125` build, with a 9-symbol stub library for the functions Docuseal
  binds that this build lacks, as in the PG census). Docuseal's `config/initializers/migrate.rb` migrates at boot in
  production, which created `census_docuseal` before setup's `db:create` (which then refused it as another copy's);
  its `script/census` row now sets `RUN_MIGRATIONS=false` (setup loads the schema; the initializer only runs at boot).

### A/A and the merge wave

`c62 − c6` over 206 workloads: median +0.0 / +0.0; 30 / 36 moved ≤ −1 and 38 / 27 moved ≥ +1; SQL changed on 13 / 7
workloads. Mastodon is fully deterministic (0 of 28 moved). On census 5's ten configurations alone the A/A moved
20 / 21 (census 5: 26 / 27).

Merge wave, `c62` vs census 5's R2 baseline `base2` (5810776eec) on those ten configurations: median −9.0 / −8.0
objects per workload, 76 / 74 of 97 moved (Fizzy −41 / −30 median, Lobsters −23 / −29, Writebook −11 / −14,
Campfire −8).

## Ranking

Top of the interpreter ranking on `c62`, 19 configurations, 16 apps. Every line below reaches ≥ 7 apps; the YJIT top
80 is the same set except `core.rb:481` (the model's base Relation, 40 / op, required) and
`abstract_adapter.rb:1426` (query collectors, required), which rank higher under YJIT.

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1 | AS `enumerable.rb:317` `index_with` pair Arrays | 16 / 96% | 371.3 | Covered by our open #59557 (Ruby 4.1). On 4.0 the pairs are what #59555 restored after #59203's revert; required. |
| 2, 8 | AR `postgresql/database_statements.rb:258/228` `result.values`, `fields` | 9 / 60% | 178.8, 75.6 | Result Strings and Times. Required. |
| 3 | AR `postgresql_adapter.rb:1047` type map key | 9 / 60% | 156.1 | Covered by our open #59560. |
| 112–114 | AR `postgresql/database_statements.rb:231–233` scratch Arrays | 9 / 60% | 10.2 each | Covered by our open #59558. |
| 4, 22, 32, 68–77 | Arel attributes, select statement/core, Equality | 16 / 90–95% | 15–123 | Per-query AST. Required. |
| 5, 10, 17, 26 | AS `output_safety.rb:245/73`, AV `tag_helper.rb:1545/1540` | 15 / 40–53% | 29–121 | Output. Required; open #57999 works on attribute strings. |
| 6, 25, 59 | AR `where_clause.rb:32/18`, `query_methods.rb:1989` | 14–16 / 80–93% | 19–89 | The built clauses. Required. |
| 7, 57, 105 | AM `attribute.rb:10/18/14` | 15–16 / 50–84% | 11–80 | Attribute objects. Required. |
| 9, 11, 18 | AR `delegation.rb:140`, `relation.rb:80/101` | 16 / 90–94% | 49–66 | Relation objects and their copies. Required. |
| 12, 13, 19, 28, 29, 95, 101 | AM `attribute_set.rb:225/322`, `builder.rb:20`, `indexed_row.rb`, AR `result.rb:196` | 14–16 / 39–97% | 12–58 | Covered by open #59141 (tenderlove) and #58002. |
| 14 | AM `type/string.rb:40` | 16 / 94% | 53.4 | Defensive copy. Required. |
| 15, 38, 37 | AR `predicate_builder.rb:146/129`, `query_methods.rb:1963` | 16 / 91–92% | 24–53 | Predicates, binds, normalized keys. Required. |
| 16, 47 | AR `associations.rb:62/85` | 16 / 89–91% | 52.1, 20.7 | Association objects and each record's association cache. Required. |
| 20, 23, 24 | AS `notifications/fanout.rb:379/378/381` | 16 / 97% | 30–37 | Per delivered event; trimmed by #59095/#59238; open #58957 skips structured handlers nobody consumes. Required while subscribed. |
| **21, 34**, 39, 83, 87, 94 | AR `preloader/branch.rb:28/77/157/33/156/148` | 13–14 / 41–47% | 13–37 | **C6-1** for `branch.rb:28` (future classes) and `:77` (runnable loaders); the rest are the branch tree and grouping (required). |
| 102, 103, 162 | AR `preloader/batch.rb:31/21/33` | 13 / 41% | 7.6–11.4 | **C6-1** for `:22` (future tables) and `:33` (next branches); `:31` partition and `:21` per-branch differences are required. |
| 43, 60, 88, 117 | AR `preloader/association.rb:179/220/146/54` | 10–13 / 33–40% | 10–21 | Owner and record grouping. Required. |
| 27 | AR `relation.rb:1345` `values` copy | 16 / 88% | 28.9 | Covered by our open #59556. |
| 30 | AS `deep_dup.rb:18` | 14 / 76% | 28.4 | App payloads (Sentry breadcrumbs, serializers). Not Rails' own work. |
| 31 | AR `persistence.rb:278` records | 16 / 97% | 28.3 | Model instances. Required. |
| 33, 64 | AS `time/calculations.rb:173/168` Rationals | 16 / 56–60% | 25.8, 16.8 | Rejected in R2 (an exact one-Rational fraction saves 1 of 15 objects). |
| 35, 36 | AS `inflector/methods.rb:258` `dasherize`, AV `tag_helper.rb:1660` data/aria keys | 8 / 24% | 25.0, 24.0 | `prefix_tag_option` is rewritten by open #57999. Excluded. |
| 40, 65 | AR `scoping/default.rb:170/66` `method(:default_scope).owner` | 16 / 90–94% | 22.8, 16.3 | A `Method` per check. Census-5 lead: no allocation-free owner query; tracking definitions would be a cache. |
| 41 | AR `spawn_methods.rb:51` Merger | 16 / 86% | 22.3 | Required. |
| 42 | AR `abstract_adapter.rb:1270` RetryBudget | 16 / 96% | 21.7 | Per-query state. Required (open #59411 touches the line for retries). |
| 44, 45 | AP `url.rb:169`, `journey/visitors.rb:38` | 15 / 59% | 21.3 each | The `path_for` copy: R2 lead (needs an ownership contract on public `URL.path_for`). |
| 46 | AR `reflection.rb:765` `[self]` | 16 / 86% | 20.9 | The chain Array. Required after #59552. |
| 48, 119 | AS `hash/keys.rb:13/32` | 15–16 / 44–73% | 9.9, 20.4 | Asset-tag option copies, mutated afterwards (census 4/R2). Required. |
| 49 | AR `quoting.rb:86` `value.to_s` | 10 / 43% | 20.1 | Quoted Numeric literals (unprepared queries). Required output. |
| 50, 53, 54 | AP `route_set.rb:230/233/318` | 14 / 51% | 19.8–20.0 | R2-3 (held: harness-set `default_url_options`) and the params Hash. |
| 51, 52 | AP `rendering.rb:64`, AV `base.rb:317` | 15 / 52% | 20.0, 19.9 | `view_assigns` keys and `"@#{key}"`. Required (R2: the `include?` variant is slower). |
| 55 | AR `association_scope.rb:159` `where!(key => value)` | 16 / 82% | 19.6 | The Hash is the argument; the Array is `where!`'s `*rest`. VM lead (see below). |
| 56 | AS `zones.rb:38` TimeWithZone | 16 / 83% | 19.0 | Required. |
| 58 | AR `delegation.rb:81` generated relation delegators | 14 / 66% | 18.8 | `scoping { model.m(...) }`: forwarding `...` into a block materializes an Array and a Hash per call even without arguments. **Lead**, see below. |
| 61 | AS `callbacks.rb:105` `Filters::Environment` | 16 / 97% | 17.8 | Required. |
| 62 | AR `query_methods.rb:1284` `spawn.where!(*args)` | 15 / 87% | 17.7 (YJIT 25.5) | `where!(opts, *rest)`'s rest Array. VM lead. |
| 63, 66, 84, 86 | AR `abstract/database_statements.rb:55/832/79/52` | 16 / 91–96% | 13.7–17.0 | Query intent, binds and payload. Required. |
| 78, 79 | AR `query_cache.rb:320`, `result.rb:165` | 16 / 88% | 15.2 | Query-cache result copies. Required. |
| 80, 81 | AR `collection_association.rb:85/86` | 16 / 77% | 14.4 each | Each collection association's target Array and Set. Required. |
| 85 | AV `capture_helper.rb:59` | 13 / 32% | 13.8 | R2-4: held until ruby/ruby#19655. |
| 91 | AR `querying.rb:84` `"#{name} Load"` | 16 / 96% | 13.0 | Memoizing it per class would be a cache of `name` (anonymous classes are renamed when assigned). Rejected. |
| 100 | AR `arel.rb:62` `Arel.sql` rest and kwrest | 15 / 72% | 11.7 | Empty `*positional_binds`/`**named_binds` per call. VM lead. |
| 104 | AR `to_sql.rb:793` `o.to_s` | 14 / 65% | 10.9 | `SqlLiteral#to_s` copies; appending the literal itself would alias a mutable String into collectors and statement caches. Rejected. |
| 106, 107 | AP `url.rb:205/213` host and protocol `dup` | 12 / 35% | 10.8 each | Mutated afterwards (`<<`); #59316 already trimmed this path. Required. |
| 110 | AS `string/access.rb:57` `String#from` | 14 / 46% | 10.3 | The result String. Required. |
| 118 | AR `query_cache.rb:302` `[sql, binds]` | 14 / 63% | 10.0 | The cache key. Required. |

The full rankings are in the receipts (`rank-c62-interpreter.tsv`, `rank-c62-yjit.tsv`).

## C6-1: build the preloader's working Arrays in place

`Preloader::Batch#call` loops until every branch is done. Each pass asks every branch for its future classes and
runnable loaders, to decide which loaders to defer. `Branch#future_classes` built `children.flat_map(...)`, then
`immediate + that`, then a `uniq` copy, per branch, recursively; `Branch#runnable_loaders` copied the `flat_map`
result with `reject`; the batch mapped and `uniq`-copied its future tables, and concatenated the next branches with
`+`. All of these Arrays are built in the same method and read once.

```diff
         def future_classes
-          (immediate_future_classes + children.flat_map(&:future_classes)).uniq
+          classes = immediate_future_classes
+          children.each { |child| classes.concat(child.future_classes) }
+          classes.uniq!
+          classes
         end
 ...
-          loaders.flat_map(&:runnable_loaders).reject(&:run?)
+          loaders.flat_map(&:runnable_loaders).delete_if(&:run?)
 ...
               future_tables = branches.flat_map do |branch|
                 branch.future_classes - branch.runnable_loaders.map(&:klass)
-              end.map(&:table_name).uniq
+              end
+              future_tables.map!(&:table_name).uniq!
 ...
-            branches = in_progress + finished.flat_map(&:children)
+            branches = in_progress.concat(finished.flat_map(&:children))
```

**Why it is exact.** `immediate_future_classes` returns a new Array on every path (`uniq` results), so appending to
it touches nothing a caller holds; children's results are only read. `concat` + `uniq!` gives the same elements in
the same order as `+` + `uniq`. `delete_if` on the fresh `flat_map` result keeps the same loaders in the same order
as `reject`. `future_tables` and `in_progress` are fresh (`flat_map`, `partition`). `ThroughAssociation` and
`Association` are unchanged. No cache, no new state.

**Per-call micro** ([`micro_preload.rb`](../../bench/upstream/census6/micro_preload.rb), SQLite in memory, three
authors, six posts):

| Call | Objects, main → branch (interp) | Objects, main → branch (YJIT) |
| --- | ---: | ---: |
| `Post.preload(:author).to_a` | 287 → **278** | 294 → **285** |
| `Author.preload(posts: :comments).to_a` | 577 → **555** | 589 → **567** |
| `Post.preload(:author, :tags, comments: :author).to_a` | 1,029 → **989** | 1,051 → **1,011** |

Timings are within run-to-run noise (±5%) and are not claimed.

**Census** (`preload` vs `c62`, A/A `c6`): 98 / 95 of 206 workloads moved ≤ −1 (A/A 30 / 36), 22 / 22 moved ≥ +1
(A/A 38 / 27); median −0.6 / −0.3 over all workloads. The 97 workloads that reach the preloader (17 configurations,
14 apps) move a median **−71 / −72**, 81 of 97 by ≤ −1. SQL changed on 8 / 7 workloads (A/A 13 / 7).

| App | A/A | C6-1 |
| --- | ---: | ---: |
| sure | −1.0 / +0.3 | −136.1 / −132.5 |
| docuseal | +0.9 / +0.1 | −19.3 / −24.1 |
| lago (and -nops) | +0.0 / −0.1 | −18.5 / −18.0 |
| loomio | +0.0 / +0.0 | −16.1 / −10.1 |
| discourse | +0.0 / +0.0 | −13.5 / −14.4 |
| casa | +0.7 / +0.0 | −5.8 / −9.5 |
| mastodon, fizzy, lobsters, blog, codetriage | medians 0 to +1.3 | single pages −679 (Mastodon), −491 (Fizzy), −118 (Lobsters), −163 (Blog YJIT), −18 (CodeTriage) |
| campfire, pingcrm, redprints-cfp, react-starter-kit, writebook | ±0.9 | within the A/A (little or no preloading) |

**Behavior controls.** [`control_preload.rb`](../../bench/upstream/census6/control_preload.rb) prints every SQL
statement in order and the loaded graph for nested, through, nested-through, polymorphic, polymorphic-nested,
instance-dependent, `includes` + `references`, STI and already-loaded preloads: **identical on main and the branch**
(87 lines). The query-grouping tests pin the deferral logic: dropping the children's classes from
`future_classes` fails `PreloaderTest#test_preload_can_group_separate_levels` and
`#test_preload_can_group_multi_level_ping_pong_through`.

**Suites.** Active Record `rake test:sqlite3` with `RAILS_STRICT_WARNINGS=1`, `SEED=41231`: main `3bdc579090`
10,247 runs, 36,561 assertions, 0 failures, 0 errors, 52 skips; branch identical. RuboCop on both files: no offenses.

**Overlap.** No open PR changes these lines' allocations. Open #42010 (`batched_method`, 2021) edits
`Branch#runnable_loaders`'s line for a feature; open #58120 and #53454/#53548 touch nearby preloader lines for
behavior. Merged history of these files has no allocation work.

### PR draft (short form, not published)

**Build the preloader's working Arrays in place**

> `Preloader::Batch#call` loops until every branch is loaded, and on each pass asks every branch for its future
> classes and runnable loaders to decide which loaders to defer. Those answers are rebuilt from copies:
> `Branch#future_classes` concatenates and `uniq`s a new Array per branch, recursively, and the batch copies the
> runnable loaders, its future tables and its next branches once more. Every `preload`/`includes` pays this.
>
> All of these Arrays are built in the same method and read once, so this builds them in place (`concat`,
> `uniq!`, `delete_if`, `map!`). Order and contents are unchanged, and no Array that a caller or another branch
> holds is mutated.
>
> | Per call | Before | After |
> | --- | ---: | ---: |
> | `Post.preload(:author)` | 287 objects | 278 |
> | `Author.preload(posts: :comments)` | 577 | 555 |
> | `Post.preload(:author, :tags, comments: :author)` | 1,029 | 989 |
>
> Across 14 open-source apps on Rails main, requests and jobs that preload allocate a median 71 fewer objects.

## Rejected, excluded and leads

* **Covered by open PRs:** `index_with` (#59557, ours), PG type map key (#59560, ours), PG cast scratch Arrays
  (#59558, ours), merge values copy (#59556, ours), attribute sets and indexed rows (#59141, #58002), tag attribute
  strings and data/aria keys (#57999), structured-event subscribers (#58957).
* **Rejected:** `"#{name} Load"` memo (a cache of a mutable class name); `SqlLiteral#to_s` in `to_sql.rb:793`
  (aliasing a mutable String into collectors); Time Rationals (R2: 1 of 15 objects); `view_assigns` (R2: slower).
* **VM leads (ruby/ruby, not Rails):** named and anonymous rest/kwrest parameters allocate even when empty — under
  YJIT also for anonymous ones until ruby/ruby#19655 — which accounts for `where!(opts, *rest)` (ranks 55, 62),
  `Arel.sql(*positional_binds, **named_binds)` (100) and `OutputBuffer#capture` (85).
* **Lead: generated relation delegators** (`delegation.rb:81`, 14 apps, 18.8 / op). `def m(...) = scoping {
  model.m(...) }` forwards `...` from inside a block, which materializes an Array and a Hash on every call, even
  with no arguments (`relation.published` → 2 objects). Avoiding it means not forwarding `...` through `scoping`'s
  block, i.e. inlining `_scoping`'s registry save/restore into the generated method, which would bypass an
  overridden `Relation#scoping`. Not exact as is; also a VM question (block-captured `...`).
* **Lead: `has_default_scope?`/`build_default_scope`** `method(:default_scope).owner` (16 apps, 39 / op combined):
  unchanged from census 5.
* **Not yet measured:** L6's four apps (above).

## Limits

* Allocation counts from one process per configuration and mode, judged against the A/A. No timing claims.
* Census 5's ten copies are measured at the pin from their 5810776eec setup through the variant Gemfile (the lock
  control in `meta.json` passed); the PG copies were set up on the pin.
* Local suites only (no hosted CI on the fork branch yet). Only the SQLite adapter suite was run for C6-1; the
  preloader is adapter-independent.
* Receipts: [data/rails-main-census-6/receipts.tar.gz](data/rails-main-census-6/receipts.tar.gz) holds both rankings,
  the label metadata, the A/A, merge-wave and candidate comparisons (`--detail`), the open-PR map, the micro, control
  and suite outputs.
