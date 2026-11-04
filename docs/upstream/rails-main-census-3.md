# Rails-main allocation census 3

2026-11-02. Third run of the [U census](https://github.com/thomasklemm/lowrail/blob/aeb6f064445db51d418ab22d3f7ef36579307898/docs/upstream/rails-main-census.md)
method, after seven of our Rails PRs merged. It runs the same four apps and twelve routes against
current canonical Rails main. **Three exact allocation reductions qualify.** Each one is a single commit
on its own branch in the `thomasklemm/rails` fork. No PR is open; they are waiting for owner review.
These are object counts, not speed claims. No timing was measured and none is inferred.

## Pins and method

* Rails: canonical `rails/rails` main, fetched fresh at
  [`e77813d4e8`](https://github.com/rails/rails/commit/e77813d4e8d794c65d43956c11b20c733e9dec52)
  (merge of #59523), 417 commits after U's pin. The default branch is confirmed as `main` via the API.
  This is not a fork's main.
* Ruby 4.0.7 (`229531a6cf`), interpreter and `--yjit`, one fresh production-mode process per app and mode.
  Lowrail is absent.
* Apps: retained blog archive, Campfire `af4dd9f`, Fizzy `77eada1`, Writebook `7478e2c`. The only change
  per app is the dependency overlay in [fixtures/corpus/rails-main-census-3](../../fixtures/corpus/rails-main-census-3/),
  which edits the Rails ref in `Gemfile`/`Gemfile.lock`. The gemspec diff between the two Rails pins only renames README files.
  Campfire and Writebook use `redis_cache_store`, so a disposable local Redis ran during profiling. In a
  first pass without Redis, Writebook's socket-connect errors dominated with about 2,000 objects per
  request at `socket.rb:79`. That pass was discarded rather than ranked.
* Runner: U's [`rails_main_census.rb`](../../bench/upstream/rails_main_census.rb),
  [`rails_main_rank.rb`](../../bench/upstream/rails_main_rank.rb) and
  [`script/rails-main-census`](../../script/rails-main-census), with only the pin and paths updated.
  Each route gets 100 warm requests, three GC-enabled 20-request totals, and a 10-request GC-disabled
  ObjectSpace trace attributed by file:line and class. Score is the sum of per-app means over equal-weighted
  routes and modes. The ranking covers Rails, Rack and the Ruby-shipped default gems only.
* Result: 1,246 ranked sites ([sites.tsv](data/rails-main-census-3/sites.tsv)). Raw receipts, the
  A/A rerun and every patched rerun are in [receipts.tar.gz](data/rails-main-census-3/receipts.tar.gz).

GC-enabled objects per request, median of three, base run:

| App | Routes | Interpreter | YJIT |
| --- | --- | ---: | ---: |
| Blog | index / show / edit | 1,908.05 / 1,802.15 / 1,512.65 | 1,923.10 / 1,809.25 / 1,515.85 |
| Campfire | room / sidebar / search | 5,163.55 / 4,994.45 / 5,008.45 | 5,163.80 / 4,995.45 / 5,009.65 |
| Fizzy | board / cards / notifications | 30,828.60 / 15,265.80 / 7,560.80 | 31,108.90 / 15,352.60 / 7,604.70 |
| Writebook | home / book / leaf | 4,069.75 / 5,600.50 / 7,915.85 | 4,087.50 / 5,639.20 / 7,985.00 |

Compared with U's pin, blog requests are 109–165 objects lighter and Fizzy's board about 1,128 lighter
(interpreter). That comes from upstream changes merged in the meantime. They were not attributed individually.

## Results: three qualifying candidates

Every number below comes from a full rerun of all four apps × two modes with only that patch applied to the
bundled Rails checkout. The deltas are medians of GC-enabled 20-request totals (objects per request, after − before),
listed per route. The traced site counts agree exactly. An A/A rerun of unpatched main moves by at most ±1.1
objects per route. Campfire's measured routes don't reach any of the three sites, so they show 0.

| Patch | Mode | Blog | Campfire | Fizzy | Writebook |
| --- | --- | ---: | ---: | ---: | ---: |
| A/A control | interpreter | +0.2 / +0.0 / −0.1 | +0.0 / +0.0 / +0.0 | −0.1 / +0.0 / +0.0 | +0.5 / +0.2 / +0.2 |
| A/A control | YJIT | +1.1 / −0.2 / +0.4 | −0.4 / +0.0 / −0.0 | +0.2 / +0.0 / +0.0 | +0.6 / +0.4 / −0.1 |
| 1 WhereClause#ast | interpreter | −0.3 / +0.3 / −0.8 | +0.7 / +0.0 / +0.0 | **−103.1 / −26.0 / −10.0** | −3.7 / −9.1 / −15.6 |
| 1 WhereClause#ast | YJIT | −0.8 / +0.8 / −0.8 | −0.4 / +0.2 / +0.0 | **−104.1 / −26.0 / −10.0** | −4.7 / −8.1 / −15.9 |
| 2 Arel project/order | interpreter | −3.8 / +0.6 / +0.2 | +1.0 / +0.8 / +0.0 | **−126.1 / −39.0 / −13.0** | −6.3 / −13.4 / −20.6 |
| 2 Arel project/order | YJIT | −3.5 / +1.8 / +0.4 | +0.0 / +1.2 / −0.0 | **−126.6 / −39.0 / −13.0** | −6.9 / −12.8 / −20.6 |
| 3 Empty warnings | interpreter | −2.3 / −1.7 / −1.6 | +0.7 / +0.0 / +0.0 | **−60.1 / −22.0 / −13.0** | −3.4 / −8.4 / −14.1 |
| 3 Empty warnings | YJIT | −1.8 / −1.5 / −2.0 | +0.2 / +0.0 / −0.0 | **−61.1 / −22.0 / −13.0** | −3.9 / −8.2 / −15.8 |
| All three | interpreter | −7.4 / −1.7 / −1.1 | +0.0 / +0.0 / +0.0 | **−290.1 / −87.0 / −36.0** | −14.5 / −29.4 / −51.6 |
| All three | YJIT | −6.6 / −2.0 / −1.8 | −0.2 / +0.0 / −0.0 | **−290.1 / −87.0 / −36.0** | −16.1 / −28.7 / −51.6 |

On Fizzy's board this is about 0.9% of request objects. The combined savings equal the sum of the three patches,
so the patches don't overlap. In patch 1's blog index row, the one-object traced site change falls within A/A noise.

Standalone micro, [`census_3_allocs.rb`](../../bench/upstream/census_3_allocs.rb), SQLite in-memory, objects per
warmed operation. Counts are identical in both modes unless two values are shown:

| Operation | Clean main | 1 | 2 | 3 |
| --- | ---: | ---: | ---: | ---: |
| `WhereClause#ast`, one / two / SQL-string predicate | 2 / 3 / 3 | 1 / 2 / 2 | 2 / 3 / 3 | 2 / 3 / 3 |
| `SelectManager.new.project(x).order(y)` | 18 | 18 | 16 | 18 |
| `Post.where(id: 1).arel` (interpreter / YJIT) | 33 / 35 | 32 / 34 | 32 / 34 | 33 / 35 |
| `select_all("SELECT id FROM posts")` | 38 | 38 | 38 | 37 |
| `Post.find(1)` (statement cache) | 62 | 62 | 62 | 61 |

### Branches

All three are based directly on `e77813d4e8`. Thomas Klemm `<github@tklemm.eu>` is author and committer.
There are no trailers, and the stored messages were checked.

| # | Branch | Commit | Files |
| --- | --- | --- | --- |
| 1 | [`thomasklemm/where-clause-ast-single-pass`](https://github.com/thomasklemm/rails/tree/thomasklemm/where-clause-ast-single-pass) | [`54c9eeb510`](https://github.com/thomasklemm/rails/commit/54c9eeb510e2d98c7bc8f00919cdf5600631f022) | `relation/where_clause.rb` |
| 2 | [`thomasklemm/arel-map-arguments-in-place`](https://github.com/thomasklemm/rails/tree/thomasklemm/arel-map-arguments-in-place) | [`0eef4cbb83`](https://github.com/thomasklemm/rails/commit/0eef4cbb83c8c5fa5ac778017deb9314557477c8) | `arel/select_manager.rb`, `arel/nodes/window.rb` |
| 3 | [`thomasklemm/shared-empty-query-warnings`](https://github.com/thomasklemm/rails/tree/thomasklemm/shared-empty-query-warnings) | [`73986ba835`](https://github.com/thomasklemm/rails/commit/73986ba8350f9f00c41148d4af7a6a22cc01a964) | abstract `database_statements.rb`, PostgreSQL `database_statements.rb`, `abstract_mysql_adapter.rb` |

### Why each one is exact

1. **`WhereClause#ast`.** `predicates - [""]` built a temporary Array and then `map` built the result. The
   new code skips `node.eql?("")` while building the single result Array. For an argument this size, `Array#-`
   uses `rb_eql(element, "")`, which is the same receiver and comparison. Order and duplicates are preserved,
   SQL literals and Strings are still wrapped in `Grouping`, and `ast` still returns a fresh tree. The unused
   private `non_empty_predicates` method and `ARRAY_WITH_EMPTY_STRING` constant are removed. `WhereClause`
   is `:nodoc:`. A first draft used `each_with_object([])`, which saved nothing on the request census (its Array
   moved to another line). It was replaced before commit, and its rerun is retained.
2. **Arel `project`/`order`/`Window#order`/`#partition`.** A rest parameter is always a fresh Array, even for
   `m(*frozen_array)`. This was checked in the interpreter and YJIT: the callee's Array is never the caller's.
   `map!` converts String/Symbol elements in place, `concat` copies the elements, and the rest Array is then dropped.
   Caller arrays and their elements are untouched.
3. **Empty warnings.** The abstract `collect_warnings` returned `[]` for every query. PostgreSQL also swapped in
   a new `[]` even when no notice had arrived. Both now return one frozen empty Array. PostgreSQL still hands
   over and resets the notice Array when it has warnings, and MySQL only uses `super` on its own early-return path.
   All consumers in Rails only read the value: `handle_warnings` uses `&.each`, and the Ractor
   `QueryResponse` checks `nil? || empty?`. **Disclosed boundary:** a third-party adapter override that
   calls `super` and then appends would now get a FrozenError. No such override exists in Rails, which has
   no other `collect_warnings` callers.

### Behavior controls

[`census_3_controls.rb`](../../bench/upstream/census_3_controls.rb) produces 18 snapshots. They cover `ast` for
empty, `""`-only, mixed `Arel.sql("")`, String-subclass `""`, SQL-literal and multi-node clauses; tree freshness;
`where`/`or` SQL; caller arrays after `project`/`order`/`Window`; and empty `project`. The snapshots are
identical between clean main and every branch in both modes. The one intended difference is that on branch 3
an empty `collect_warnings` result is now frozen and shared (`[[], false, false]` → `[[], true, true]`).

### Suites (local, Ruby 4.0.7, seed 41231, serial)

* **Active Record SQLite, full (`rake test:sqlite3`):** clean main and each of the three branches give
  10,247 runs, 0 failures, 0 errors, 52 skips. The assertion total is not stable between runs on clean main
  either (36,542–36,591), so it isn't used as evidence. The first run of each branch had 4 errors because the
  `sqlite3` CLI was missing. After installing it, all runs were clean.
* **PostgreSQL 15 (branch 3 and clean main):** `test/cases/adapters/postgresql/**` plus
  `query_intent_test.rb` give 956 runs / 2,862 assertions / 0 failures / 14 skips on both. Both also have the
  same 4 `ForeignTableTest` errors because postgres_fdw cannot reach its loopback server in this orb.
* **MariaDB 10.11 (branch 3 and clean main):** `abstract_mysql_adapter/**` plus the adapter directory plus
  `query_intent_test.rb`. Trilogy: 267 runs / 677 assertions / 0 failures / 2 skips. mysql2: 248 / 634 / 0 / 3 skips.
  The results are the same on both trees.
* **RuboCop** with Rails' `.rubocop.yml`, run on the six changed framework files plus the controls script:
  7 files, no offenses.

The suites were not run for the full PostgreSQL/MySQL matrices, other components or hosted CI.

## Overlap check

Searched open, closed and merged `rails/rails` PRs for the changed methods (`non_empty_predicates`,
`predicates_with_wrapped_sql_literals`, WhereClause ast/allocation, Arel project/order/map, `collect_warnings`,
db_warnings, `RetryBudget`, QueryIntent allocation) and read the hits:

* #24607 (2016, merged) introduced `non_empty_predicates` with `-` as an improvement over the previous code.
  #39046 (merged) is the single-node `ast`. Neither covers the temporary Array.
* #54946 (open, last updated 2025-04) extracts `Or#or` from WhereClause. Its diff doesn't touch
  `predicates_with_wrapped_sql_literals`.
* #57584 (merged) clears PostgreSQL warnings after each query. Branch 3 keeps that reset.
  #57694 (open) touches the same adapter files for `array_bind`, not warnings.
* Recent Arel commits (`4bff4e9341`, `29121db7ba`, #59404, #59337) share constant nodes or change `ToSql`.
  None touches the rest-argument maps.
* Open PRs in the same area (#59413, #59212, #59377, #59367, #58839, #59484 merged) had their file lists read.
  None changes these hunks.

Negative searches are bounded evidence, not proof that no overlapping work exists.

## Named audit candidates

| Candidate | Disposition |
| --- | --- |
| PostgreSQL type-map tuple dispatch | **Not measured: none of the four corpus apps uses PostgreSQL.** `HashLookupTypeMap#fetch(oid, *args)` builds an `args` Array per column per result and uses it as the key into the per-OID `Concurrent::Map`. On a hit the Array is scratch, but the key equality is what makes the lookup work. Removing it means restructuring the cache into nested maps per fmod/sql_type, which is a design change to a registry that `register_type`/`clear`/`alias_type` keep live. That's not a small exact elision. Our merged #59278 already took the result-fields Array in the same `cast_result`. Revisit only with a PostgreSQL workload (CodeTriage/CASA from U3). |
| Literal inflection plans | Rejected again. Rank 7 (`dasherize`'s `tr`, 306) returns a fresh String by contract (U rank 7). A plan or cache keyed on literal input would cache derived values from mutable inflection rules. `humanize` (rank 199, 23) overlaps open #58752. |
| AttributeSet key unions | Dropped. The `LazyAttributeSet#keys` union lines score ≤ 4 objects per request here (ranks 581/704). The large AttributeSet site is `builder.rb:20` (rank 64, 77), which is the per-record `LazyAttributeSet` plus its own `{}` and is required state. Open #58002 (keys materialization, which adds this union's rewrite in `builder.rb`) and #59141 (Array storage, which rewrites `attribute_set.rb` and `builder.rb`) both overlap. Not touched. |
| Fixed query-shape pools | Boot-plan and cache versions are refused (admission rule). Relation values (`relation.rb:80/101/1345`), Arel cores/statements, `WhereClause.new`, `Merger`, `QueryIntent`, payload and collector objects are per-query mutable ownership. The exact residual pieces of this pool are candidates 1–3 above. |

## Top-ranked Rails sites and dispositions

Rank and score come from [sites.tsv](data/rails-main-census-3/sites.tsv). Non-Rails sites (URI, Rack, JSON) were dispositioned in U/U2 and are unchanged here. "Rejected" means the obvious small elision is rejected, not every possible algorithm.

| Rank | Site | Score | Disposition |
| ---: | --- | ---: | --- |
| 2, 4 | AS `output_safety.rb:245/73`, `html_safe` / SafeBuffer | 693 / 367 | Fresh SafeBuffer is the return value (U ranks 2–3). |
| 3, 24, 27, 28 | AV `tag_helper.rb:1545/1605/1540/1751`, tag output | 422 / 155 / 139 / 136 | Fresh markup. Covered by #59117/#59244/#59458. Open #57999 overlaps. |
| 5 | AP `url.rb:361`, `host_with_port` | 346 | Fresh result String (U rank 5). |
| 6, 94 | AR `where_clause.rb:32/18`, merge / `+` | 308 / 62 | The empty-merge skip was measured YJIT-negative (U rank 6). Main's `50b6efcbb8` already skips the empty case. |
| 7 | AS `inflector/methods.rb:258`, `dasherize` | 306 | See the inflection row above. |
| 8 | AV `tag_helper.rb:1660`, prefix key | 295 | Covered by #59244. |
| 11, 115–117 | AV `tag_helper.rb:1813–1824`, `token_list` | 259 / 43 each | Covered by #59114. The residual tokens are output. |
| 18 | AS `enumerable.rb:87`, `index_with` | 219 | #59108 was reverted by #59203. Not revived. |
| 19, 20, 50, 52–55, 71–74 | AV asset tag/url helpers | 204 … 68 | U/U2 dispositions stand. The `map!` change is merged (#59274). #59520 and #59511 merged href handling. |
| 21–23, 26, 38, 48, 59, 62, 84–92, 98 | AR Relation/Arel construction | 184 … 58 | Per-query mutable state (U2 ranks 21–23, 28, 38, 49, 60). |
| 25 | AR `where_clause.rb:117`, extracted attrs | 154 | Escaping result (U2 rank 25). |
| 29, 60 | AS `hash/keys.rb:13/32` | 135 / 78 | Fresh Hash contract (U2 rank 29). |
| 46, 172 | AV `structured_event_subscriber.rb:72–73` | 123 / 30 | The `sub` semantics were rejected (U2 rank 46). Skipping unconsumed events is open #58957. |
| 47, 57, 58, 67–70 | AS fanout / subscriber | 119 … 70 | Active-event state. Empty groups are covered by #59235. `subscriber.rb:142`'s method-name slice could only be removed by a per-name memo, which isn't a small exact change. |
| 49 | AR `predicate_builder.rb:146`, `flat_map` | 116 | U2 rank 48. |
| 51 | AR `database_statements.rb:871`, intents | 105 | Return-ownership counterexample (U2 rank 51). |
| 56 | AS `array/extract.rb:15` | 84 | Public result (U2 rank 57). |
| 61 | AR `merger.rb:164`, `extending!(*other.extensions)` | 77 | The rest Array from splatting an empty array. A call-site guard was proposed and **explicitly declined** in #57246 (bogdan: “pushes the repo in the wrong direction”), then merged without it. Deliberate design, so not reopened. |
| 64 | AM `attribute_set/builder.rb:20` | 77 | Per-record state. See the AttributeSet row above. |
| 65, 168 | AR `scoping/default.rb:170/66`, `method(:default_scope)` | 74 / 31 | kamipo's `98f39e8` (2026-10-21) deliberately accepted one Method per call to detect private overrides. Any replacement allocates an UnboundMethod or stops checking live owners. Rejected. |
| 66, 83, 158, 162, 251 | AR `structured_event_subscriber.rb` binds | 73 … 17 | Overlaps open #58957. |
| 76, 77, 125 | AV buffers / `capture` | 68 / 68 / 42 | `yield(*, **)` allocates an Array when forwarding arguments. Avoiding it changes `capture`'s forwarding contract. Deferred. |
| 78, 294, 295 | AR `to_sql.rb:826`, placeholder scan | 65 … 12 | MatchData/captures are the output path. #59404 is merged nearby. Not reopened. |
| 79, 127, 183, 188, 206 | AR reflection chains | 64 … 21 | Fresh chain Arrays escape to callers that build on them. A memo would be a cache of reflection state. Refused. |
| 80, 122, 124 | AR sqlite3 `database_statements.rb` | 64 / 43 / 42 | Result rows/types and bind params are required. sqlite3-ruby #758 is merged. |
| 81, 82, 93, 96 | AS `event_reporter.rb` | 64 … 60 | Filter event Hash / subscribers list. Area is under active change (#58957). Deferred. |
| 97, 133–136 | AR collectors | 59 … 39 | One SQL collector per compile is required. |
| 99 | AS `to_query.rb:57` | 57 | Array `to_param` output. |
| **100** | AR `where_clause.rb:207`, `non_empty_predicates` | 56 | **Candidate 1.** |
| 101 | AR `delegation.rb:81`, `scoping { model.#{method}(...) }` | 52 | Forwarding into generated delegates. Live dispatch required. |
| 105, 128 | AR `database_statements.rb:55/52`, `to_sql_and_binds` tuple | 49 / 41 | A multi-value return contract used by adapters. Rejected. |
| 107 | AR `core.rb:481`, `Relation.create(self)` | 47 | **YJIT-only** (Fizzy 70 / Writebook 20 per request under YJIT, 0 in the interpreter). `create(model, ...)` with no extra arguments allocates a forwarding Array only under YJIT. This is a YJIT lead, not a Rails PR. |
| 108–110 | AR query cache dup / key | 46 / 46 / 45 | Ownership copies and cache keys. |
| 118–121 | AR QueryIntent / payload / RetryBudget | 43 each | Per-query state. **Rank 120 (`database_statements.rb:919`) is candidate 3.** |
| 123, 257 | AV `tag_helper.rb:1484/1454`, `define_element` lines | 43 / 16 | Allocation is attributed to the generated method's definition line. The source of the Array wasn't isolated. Untried. |
| **167** | AR `select_manager.rb:148` (and `:189`) | 32 (interpreter only) | **Candidate 2.** Under YJIT these Arrays are attributed to `<internal:array>` lines, so the site score halves. The request deltas are the same in both modes. |

Sites ranked below 130 were not screened beyond the rows named above. They remain an untried pool.

## PR description drafts

These are short, following the merged PRs. The scripts are linked above. The drafts aren't published.

### 1 — Build WhereClause#ast predicates in one pass

> `predicates_with_wrapped_sql_literals` first subtracted `[""]` into a temporary Array, then mapped it.
> This skips empty-string predicates while building the result instead. The comparison
> (`node.eql?("")`) is the one `Array#-` used, and order is unchanged.
>
> One Array fewer per `WhereClause#ast`, i.e. per compiled relation with a where clause.
> On Rails main with Ruby 4.0.7, Fizzy's board/cards/notifications pages allocate 103/26/10 fewer objects
> per request, and Writebook 4–16 fewer. The counts are the same in the interpreter and YJIT.
> Allocation counts only; no timing claim.

### 2 — Map Arel project and order arguments in place

> `SelectManager#project`/`#order` and `Window#order`/`#partition` mapped their rest argument into a
> second Array before concatenating it. The rest Array is always new and local, so convert it in place.
> Callers' arrays are not touched.
>
> One Array fewer per call, which means at least once per compiled SELECT. Fizzy: 126/39/13 fewer objects
> per request. Writebook: 6–21 fewer. The interpreter and YJIT agree. No timing claim.

### 3 — Share an empty warnings Array when a query has none

> Every query Active Record executes collects database warnings afterwards. On SQLite, PostgreSQL with no pending notice,
> and MySQL with no warnings or warnings disabled, that meant a new empty `[]` per query, including `find`,
> `pluck`, `insert`, `update` and association loads. Return a frozen empty Array in those cases.
> Collected warnings are handed over and reset as before.
>
> Per call: one object fewer per executed query (`Post.find(1)` 62 → 61, `select_all` 38 → 37).
> Across the corpus: about 2 fewer objects per request (Blog), 3–16 (Writebook), 13–61 (Fizzy), 1–3 (CodeTriage on PostgreSQL). No timing claim.
>
Not a PR line. The branch was first held back because of the FrozenError boundary (a caller that mutates the returned
warnings Array would now raise); it was then opened with that boundary stated and merged as
[rails/rails#59536](https://github.com/rails/rails/pull/59536) on 2026-11-02
([`4740314734`](https://github.com/rails/rails/commit/4740314734)) (status 2026-11-04).

## Blockers and limits

* No PostgreSQL corpus app was profiled, so the type-map candidate stays unmeasured.
* Suite coverage is local only (see above). The postgres_fdw foreign-table errors are environmental and
  appear on clean main as well.
* The Amp GitHub integration cannot subscribe to `rails/rails`, so CI and review monitoring after PRs
  open will have to be manual.
* The YJIT-only `...` forwarding Array (rank 107) is a lead for ruby/ruby and needs its own ruby-bench evidence
  under DECISIONS' submission bar.

## Follow-up 3b: untried pool and a PostgreSQL app (2026-11-02)

This follow-up screens rank 123/257 and the previously unscreened ranks 130–300, and adds CodeTriage on
PostgreSQL to price the PG type map. **Four more exact candidates qualify.** Each is one commit on its own branch
in the fork. No PR is open.

* Rails base: the fork commits sit on canonical main
  [`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953), which is
  `e77813d4e8` plus merged #59533. The request reruns patch the bundled `e77813d4e8` checkout. None of the four
  changed files differs between the two pins.
* Same method as above: every patch gets a full rerun of all apps × interpreter/YJIT. A fresh A/A rerun
  (`base3`) moves by at most ±1.7 objects per route, except one Campfire YJIT room cell at +4.3. That cell
  appears in the A/A rerun and in three patched reruns that never reach Campfire's code paths, so it is noise.
* CodeTriage [`d1868f8`](https://github.com/codetriage/codetriage/commit/d1868f8634e97a111a7fca49d58cc776d206007e)
  runs on PostgreSQL 15 and memcached. The dependency overlay is
  [codetriage.patch](../../fixtures/corpus/rails-main-census-3/codetriage.patch), made with
  `bundle update rails --conservative`. `config/database.yml` is the app's own `database.example.yml`, and
  fixtures are loaded with the census `prepare` step. The routes are anonymous `/`, `/schneems/get_process_mem`
  and `/rails/rails/subscribers`. Each returns 200 with a non-empty body. Base objects per request:
  interpreter 3,107.8 / 3,149.8 / 2,621.4, YJIT about 3,121 / 3,164.6 / 2,632.2.

### Candidates

Deltas are objects per request (GC-enabled median, after − before) for the routes in the order of the first
table. CodeTriage reaches none of these four paths: all its cells stay within its ±1.2 A/A.

| Patch | Mode | Blog | Campfire | Fizzy | Writebook |
| --- | --- | ---: | ---: | ---: | ---: |
| A/A control | interpreter | −0.1 / +0.4 / −0.7 | +0.0 / +0.0 / +0.0 | −0.6 / +0.0 / +0.0 | +0.9 / +0.6 / +0.0 |
| A/A control | YJIT | +1.7 / −0.2 / −0.8 | +4.3 / +0.1 / −0.0 | −1.1 / +0.0 / +0.0 | −0.1 / +0.2 / −0.4 |
| 4 tag_string order | interpreter | −4.5 / −3.9 / −2.8 | +0.7 / +0.8 / +0.0 | **−183.6 / −131.0 / −27.0** | −2.7 / −8.4 / −9.0 |
| 4 tag_string order | YJIT | −3.9 / −4.0 / −1.4 | +0.0 / +0.0 / +1.0 | **−184.1 / −131.0 / −27.0** | −2.6 / −9.6 / −8.7 |
| 5 HWIA#fetch | interpreter | +0.4 / −0.2 / −0.2 | +0.7 / +0.0 / +0.0 | **−69.6 / −22.0 / −6.0** | +0.5 / −5.4 / −15.7 |
| 5 HWIA#fetch | YJIT | +1.2 / +0.4 / −0.2 | +4.4 / +0.2 / −0.0 | **−70.1 / −22.0 / −6.0** | +0.1 / −5.6 / −17.0 |
| 6 frozen load defaults | interpreter | −1.7 / −0.4 / −0.4 | +0.0 / +0.0 / +0.0 | **−60.1 / −22.0 / −9.0** | −3.2 / −14.4 / −23.0 |
| 6 frozen load defaults | YJIT | −0.2 / −0.9 / +0.0 | −0.4 / +0.1 / −0.0 | **−60.1 / −22.0 / −9.0** | −3.6 / −15.1 / −22.3 |
| 7 join chain `drop` | interpreter | +1.5 / −0.5 / −0.2 | +0.7 / +0.0 / +0.0 | **−47.6 / −10.0 / +0.0** | +1.2 / −0.1 / +0.3 |
| 7 join chain `drop` | YJIT | +1.5 / +1.0 / −0.9 | +4.3 / +0.0 / +0.6 | **−48.1 / −10.0 / +0.0** | +0.7 / +0.4 / +0.3 |

A first full rerun of the same four patches, made before the CodeTriage receipts existed, gave the same Fizzy
values within 2.0 objects; it was overwritten by the second rerun. In CodeTriage, branch 6 saves 1–4 objects
per request. Branch 3 (empty warnings) saves 0.6–3.4 on PostgreSQL routes and branch 2 (Arel) saves 0.4–2.5.
Those are small but consistent with the per-query sites.

Micro ([`census_3b_allocs.rb`](../../bench/upstream/census_3b_allocs.rb), objects per warmed operation,
interpreter / YJIT where they differ):

| Operation | Clean | 4 | 5 | 6 | 7 |
| --- | ---: | ---: | ---: | ---: | ---: |
| `tag.span("x", class: "a")` | 5 | 4 | 5 | 5 | 5 |
| `tag.my_widget("x")` (method_missing) | 9 | 6 | 9 | 9 | 9 |
| `HWIA#fetch(:a)` / `fetch(:z, 0)` | 1 / 1 | 1 / 1 | 0 / 0 | 1 / 1 | 1 / 1 |
| enum `serialize("live")` | 2 | 2 | 1 | 2 | 2 |
| `Post.where(author_id:).load` | 90 / 93 | 90 / 93 | 90 / 93 | 89 / 92 | 90 / 93 |
| `Post.joins(:author).load` | 153 / 155 | 153 / 155 | 153 / 155 | 152 / 154 | 152 / 154 |

| # | Branch | Commit | Change |
| --- | --- | --- | --- |
| 4 | [`thomasklemm/tag-string-trailing-content`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-string-trailing-content) | [`df8bb7f451`](https://github.com/thomasklemm/rails/commit/df8bb7f45159896870b4633b99da9cb157e0d41e) | Private `TagBuilder#tag_string(name, content = nil, options, …)` becomes `(name, options, content = nil, …)`, and its three callers are reordered. |
| 5 | [`thomasklemm/indifferent-fetch-without-rest`](https://github.com/thomasklemm/rails/tree/thomasklemm/indifferent-fetch-without-rest) | [`6a9c90662a`](https://github.com/thomasklemm/rails/commit/6a9c90662a2b19555d2ee876a6d821d5464d146f) | `HashWithIndifferentAccess#fetch(key, *extras)` becomes `fetch(key, default = (no_default = true; nil))`. Amended after review with boundary tests (was `bf0b203829`). |
| 6 | [`thomasklemm/relation-load-frozen-empty-defaults`](https://github.com/thomasklemm/rails/tree/thomasklemm/relation-load-frozen-empty-defaults) | [`c11df3143f`](https://github.com/thomasklemm/rails/commit/c11df3143f14e559007fd4bf3cd566b81cc525cb) | `exec_main_query` passes `FROZEN_EMPTY_ARRAY` as binds to `_query_by_sql`. The `alias_tracker` default `joins = []` becomes `FROZEN_EMPTY_ARRAY`. |
| 7 | [`thomasklemm/join-chain-drop`](https://github.com/thomasklemm/rails/tree/thomasklemm/join-chain-drop) | [`a70709e899`](https://github.com/thomasklemm/rails/commit/a70709e8991d998e6048191c4bbc2a2d65e055e0) | `JoinAssociation#join_constraints` uses `reflection_chain.drop(index)` instead of `reflection_chain[index..]`. |

Author and committer are Thomas Klemm `<github@tklemm.eu>`, with no trailers.

### Why each one is exact, and its boundaries

4. **Rank 123/257 isolated.** The Array attributed to the generated `define_element` lines (1484 `span`, 1454 `li`)
   is the argument shuffle Ruby performs because `tag_string` has an optional parameter before a required one. A
   standalone reproduction shows 4 → 3 objects per call when the optional parameter moves to the end, in both modes.
   The same shuffle explains part of rank 132 (`method_missing`, line 1676). Output, escaping, blocks and self-closing
   behavior are unchanged. For `tag.foo("a", "b")` and `tag.span("a", "b")` the ArgumentError messages are identical
   ("given 4, expected 2..3" / "given 2, expected 0..1"). **Boundary:** `tag_string` is private on a `:nodoc:`
   class, so a third-party subclass that overrides or calls it with the old order breaks. A GitHub code search
   found only vendored copies of Rails and unrelated `tag_string` implementations (hanami-view, derails). #50737
   last reshaped this method's arguments to cut Hash splats. Open #54042 touches `tag_string`'s body, not its
   signature, and would need a trivial rebase.
5. **HWIA `fetch`.** Missing keys (KeyError key/receiver), defaults including explicit `nil`, blocks, block
   precedence and the "block supersedes default value argument" warning all match. The block form now matches
   `Hash#fetch` directly. **Disclosed difference:** calling `fetch()` with no arguments now says
   "expected 1..2" instead of "expected 1+". This is now Hash#fetch's own message. Enum `serialize` and
   `serializable?` call `mapping.fetch(value, value)` on an HWIA, which is where most of the request saving comes from.
   No overlapping PR was found (#46942 is `fetch_values`). The merged #59293 and #59294 by sampokuokkanen removed
   the neighboring rest Arrays the same way.
6. **Frozen load defaults.** Neither Array is read for content or mutated: the arel path replaces binds in
   `compile_arel!`, and `AliasTracker.create` only checks `joins.empty?`. **Disclosed boundary (observable):** with
   `prepared_statements: false` (the default for MySQL), `sql.active_record` `payload[:binds]` for relation loads
   is now the shared frozen empty Array instead of a fresh empty one. This was verified directly: `[false, false]`
   becomes `[true, true]`. A subscriber that appends to `payload[:binds]` would raise. Rails' own subscribers only
   read it. If the binds half is unwanted, the `alias_tracker` half stands alone.
7. **Join chain `drop`.** `index` is always less than the chain size inside `each_with_index`, so `[index..]` never
   returns nil, and both forms return a new Array of the same elements. This saves one endless Range per chain element
   when building joins (rank 142).

### Behavior controls and suites

[`census_3b_controls.rb`](../../bench/upstream/census_3b_controls.rb) records 34 snapshots: tag builder content,
blocks, nil, escaping, void, SVG self-closing and content forms, custom tags with 0, 1 and 2 arguments, and
`content_tag`; HWIA fetch shapes and errors; through and nested joins, `left_joins`, `eager_load`, through readers,
enum queries; and the size and class of `sql.active_record` binds. The snapshots are identical between clean main and
every branch in the interpreter and YJIT.

Local suites (Ruby 4.0.7, seed 41231, serial):

* **Action View, full:** clean `b5be036` and branch 4 each give 2,913 / 6,939; 251 / 342; 177 / 344, with 0 failures,
  errors or skips.
* **Active Support, full:** clean and branch 5 each give 6,865 runs / 29,875 assertions / 0 failures / 0 errors /
  60 skips. A first parallel attempt failed 30 and 25 `MemCacheStoreTest` cases on clean and branch alike,
  because both runs shared one memcached server. That attempt was discarded and both were rerun serially.
  After the Thermos review nit, branch 5 was amended (`6a9c90662a`) with three tests in
  `hash_with_indifferent_access_test.rb`: `nil`/`false` defaults, KeyError `key`/`receiver` for a missing key,
  and block-only and block-plus-default (block wins, "block supersedes default value argument" warning). They pass
  on the branch and on clean main. They catch a mutant that treats falsy defaults as "no default"
  (1 error). Full Active Support on the amended commit: 6,868 runs / 29,885 assertions / 0 failures /
  0 errors / 60 skips. RuboCop: no offenses.
* **Active Record SQLite, full:** branches 5, 6 and 7 each give 10,247 runs, 0 failures, 0 errors, 52 skips,
  the same as clean main above.
* **Branch 6 on other adapters:** PostgreSQL adapter tests plus `relations`, `finder` and `associations/join_model`
  give 1,678 / 5,180 / 0 / 0 / 15 skips, identical to clean main. (The socket symlink now makes postgres_fdw work,
  so the earlier 4 ForeignTable errors are gone on both trees.) MariaDB trilogy gives 888 / 2,574 / 0 / 0 and mysql2
  869 / 2,531 / 0 / 0, identical to clean main. Both use `prepared_statements: false`, which is the frozen-binds path.
* **RuboCop:** six files (four framework sources and two scripts), no offenses.

### PostgreSQL pools (CodeTriage)

[`census_3b_pg_sites.rb`](../../bench/upstream/census_3b_pg_sites.rb) lists PG-specific sites. Values are objects
per request averaged over three routes and both modes:

| Site | Objects/request | Disposition |
| --- | ---: | --- |
| `postgresql_adapter.rb:1047`, `type_map.fetch(oid, fmod, sql_type)` → `HashLookupTypeMap#fetch(lookup_key, *args)` | **25.3** (≈0.8% of request objects) | **Priced. Rejected as a small exact change.** One `[fmod, sql_type]` Array per column per result. That Array *is* the `Concurrent::Map` key (`@cache[oid].fetch_or_store(args)`), so the hit probe needs an equal key. Removing it means a nested per-fmod/per-sql_type cache, a different key encoding, or a specialized two-argument path. That is a cache restructure: `register_type`/`alias_type`/`clear` invalidation and third-party `register_type` blocks receiving `*args` would all need preserving. A design proposal at best, not an elision. |
| `postgresql/database_statements.rb:228`, `result.fields` | 25.3 | Field-name Strings created by the pg gem, used as the Result's columns. Required. #59278 already reuses this Array. |
| `postgresql/database_statements.rb:258`, `result.values` / Result | 10.7 + 5.0 + 4.0 + 1.3 | Row values (Strings and Time casts), the Result object and its rows. Required data. |
| `postgresql/database_statements.rb:231–233` | 1.3 each | `types`, `field_types` and `missing_oids` per result. Each is required or escapes, except `missing_oids`, an always-new Array that is usually empty. 1.3 objects per request is below the bar. Not submitted. |
| `postgresql/database_statements.rb:276`, warnings swap | 1.3 | Covered by held-back branch 3: CodeTriage −0.6…−3.4. |
| `postgresql_adapter.rb:1124`, `"#{schema_search_path}-#{sql}"` | 1.0 | Statement-pool key. Required. |

No other PG-only pool reaches 1 object per request. CodeTriage's largest framework sites (SafeBuffer, template paths,
structured-event root stripping, fanout) match the SQLite apps and keep the dispositions recorded above.

### Ranks 130–300: dispositions

The ranks named below correspond to the earlier table and [sites.tsv](data/rails-main-census-3/sites.tsv).
"Rejected" means the obvious small change is rejected, not every possible algorithm.

| Ranks | Sites | Disposition |
| --- | --- | --- |
| 123, 132, 257 | AV `tag_helper.rb:1484/1676/1454` | **Candidate 4.** |
| 131, 212 | AV `tag_helper.rb:1598` capture, `output_safety_helper.rb:41` `safe_join` | `capture(self, &block)` forwards with `yield(*, **)`. Covered by the deferred `capture` row above. `safe_join`'s `flatten` and `map!` are its output path. |
| 133–136, 207, 114 | AR collectors and `to_sql.rb:793` | One collector per compile. Required. |
| 137, 198, 215, 222, 231, 234, 265, 277, 281, 300, 301, 307–309 | AR preloader branch/batch | `flat_map`/`reject`/`partition`/`group_by` results escape into the next iteration of the preloading loop. No exact elision without restructuring the loop. Untried beyond that. |
| 138 | AS `erb/util.rb:16` | Escaped output String. Required. |
| 139 | AR `persistence.rb:278` (records) | Model instances. Required data. |
| 140, 217, 238, 296 | AP CSP header, `request_forgery_protection.rb:582–584` | Header output, or work already shortened by merged #59375 and #59500 (open). Not reopened. |
| 141, 147, 169, 173–175, 247, 276, 299, 318 | AV renderer objects | Per-render state. #59258, #59265 and #59290 are merged nearby. |
| **142** | AR `join_association.rb:30` | **Candidate 7** (Range half). The Array half is the yielded chain tail. Required. |
| 143, 178, 182, 223–230, 241, 250 | AR join dependency nodes and buckets | Per-query Arel AST and join state. |
| 145, 148, 190, 210, 272–275, 285–287, 291–293, 310, 316, 322 | AR query_methods rest/flat_map Arrays | Rest arguments of public query methods (`where`, `order`, …) and their per-call results. Changing public signatures is out. `flattened_args` (145) builds the result it returns. |
| 146, 149, 150, 209, 244 | AM attribute / IndexedRow / binary Data | Per-record attribute state. |
| 151–154, 163, 164, 166, 211, 263, 329 | AP URL/route building, AV template paths, AS thread_mattr keys | Fresh output Strings or Hashes; `script_name.to_s.chomp` and Journey buffers are covered in U2. The `thread_mattr` key String (`"attr_#{sym}_#{object_id}"`) could be cached per class, but that adds a memo on a generated accessor. Refused. |
| 155, 181, 303 | AR `where_clause.rb:184/22` | `except_predicates` and `-` results are the new clause's predicates. Required. |
| 156, 200, 242, 249, 252, 261, 267, 270, 282, 288, 289 | AS/AR String results (`String#at`, `cache_key`, `upcase`, `downcase`, key generator join, `StringInquirer`) | Fresh return values. Earlier "fresh result" rejections apply. |
| 157, 194 | AR `querying.rb:83/84` | **Candidate 6** for the binds default (83). The `"#{name} Load"` String (84) is the notification name. Caching it per model would be a memo of `name`. Refused. |
| 158–162, 251 | AR/AS structured event subscriber, `deep_dup`, fanout | Overlaps open #58957. `deep_dup` copies are its contract. |
| 165, 253, 254 | AR association scope/extensions | `merge!` rest and `|` results. `|` returns a new Array by contract. Related #57246 decision. |
| 167 | Arel `select_manager.rb:148` | Candidate 2 (#59534). |
| 170, 171, 177, 204, 232, 233 | AR predicate builder dup, merger `public_send` rest, `values.except`, reflection scope building | Per-query state. 171's `*value` splat into `#{name}!` uses the bang methods' public rest signatures. |
| 176, 239, 240 | AR `@association_cache`, CollectionAssociation target/Set | Per-record or per-association state. |
| 179, 196, 269, 313, 314 | AV form tag sanitize/options | Fresh id Strings and option Hashes. #59269 merged nearby. |
| 183, 188, 189, 206, 218–220, 279 | AR reflection scope/chain Arrays, `AssociationScope#get_chain` | Covered by the reflection-chain row above. |
| 184, 186, 187 | AR `Result#column_types` Hash, `_load_from_sql` reject and payload | Per-result Hash. A `reject` on an empty Hash still returns a new Hash; skipping it when `attribute_types` covers everything would change identity only for a local. Small (26/request). Untried. |
| 185, 195, 221 | AR AliasTracker | **Candidate 6** for the `joins = []` default (221). AliasTracker and its Hash are required state. |
| **205, 237** | AR `enum.rb:231/227` `mapping.fetch(value, value)` | **Candidate 5.** The Array was HWIA's `*extras`. |
| 193 | AM `type/string.rb:40` | Defensive copy of a mutable String. Required. |
| 197, 260 | AR `references_values |=`, predicate_builder references | New Arrays by `|` contract and per-query state. |
| 199 | AS `inflector/methods.rb:163` (`humanize`) | Overlaps open #58752. |
| 201, 208, 266 | Arel Limit/And/Count nodes | Per-query AST. |
| 202 | AR `quoting.rb:219` `binds.map` | `type_casted_binds` result. Required. |
| 203, 324 | AS MessageVerifier / CSRF HMAC `dup` | Fresh HMAC state per digest. #59430 merged nearby. |
| 213 | AM `attribute_registration.rb:125` `name.to_s` | The #59357/#59366 Symbol#name series covers sibling sites. This one converts String-or-Symbol to a new String the caller keeps. Not proven disposable. Untried. |
| 214 | AR preloader `scope.where(key => keys)` | Public `where` with a Hash argument. Required. |
| 216, 283, 304 | AS time calculations, `TimeWithZone.new` | Rational/Time results. #59397 and #59402 merged nearby. |
| 235, 271, 280 | AR `references_eager_loaded_tables?` | `build_joins([])` plus the `map!`/`-` chain. The `[]` literal argument is a new Array passed into `build_joins`, which may use it as an accumulator. Not proven disposable. Untried. |
| 245, 255, 256 | AS `inquiry`, AR `default_scopes` `[]`, `compact_blank` | 255's `return []` escapes to `default_extensions` callers and is unioned with `|`; returning a frozen Array would be exact for Rails' callers, but it is ≤16/request on one app. Below the bar. |
| 248 | AV `navigation_helper.rb:311` Proc | `&block` capture. Required. |
| 258, 306, 315, 317, 319–321, 323, 325, 328, 330 | Remaining (≤16/request) | Below the bar for this screen. Untried. |

Ranks 301–330 appear only where a row above names them. Everything below rank 300 that isn't named stays untried.

### PR description drafts (not published)

Rewritten after the Thermos reviews (2026-11-02) to lead with the common Rails pattern that reaches each path and the
cost per call. App numbers stay as one supporting line. Per-call counts come from standalone micros on the fork
branches (SQLite in memory, Ruby 4.0.7, identical in the interpreter and YJIT unless noted).

**4 — Take tag_string options before the optional content**

> Every `tag.div`, `tag.span`, `tag.li`… call goes through the private `TagBuilder#tag_string(name, content = nil, options, …)`.
> It has an optional parameter before a required one, so Ruby allocates an Array on each call to shuffle the arguments.
> Custom elements through `method_missing` (`tag.my_widget`) pay this three times. Reorder the private method's
> parameters and its three callers. Output, escaping, blocks and arity errors are unchanged.
>
> Per call: `tag.span("x", class: "a")` 5 → 4 objects, `tag.my_widget("x")` 9 → 6.
> Across corpus pages that use `tag.*`: 1–5 fewer objects per request (Blog), 3–10 (Writebook), 27–184 (Fizzy). Allocation counts only; no timing claim.

**5 — Avoid a rest Array in HashWithIndifferentAccess#fetch**

> `HashWithIndifferentAccess#fetch(key, *extras)` allocated an Array on every call, including `fetch(key)` with no default.
> HWIA backs `params`, so `params.fetch(:user)` and `params.fetch(:page, nil)` pay for it. So do enum casts: every enum
> value in a `where`, an assignment or a validation goes through `mapping.fetch(value, value)`. Take the default as an
> optional positional parameter instead. Missing keys (KeyError key and receiver), `nil`/`false` defaults, blocks, and
> "block supersedes default value argument" behave as before. New tests cover these cases.
> The only visible difference is the arity message for `fetch()` with no arguments, which now matches `Hash#fetch` ("1..2" instead of "1+").
>
> Per call: `params.fetch(:q)` 3 → 2 objects, `hwia.fetch(:a)` 1 → 0, `Post.where(status: :live).to_a` 77 → 74.
> Across the corpus: 5–17 fewer objects per request (Writebook), 6–70 (Fizzy). No timing claim.

**6 — Pass frozen empty defaults when loading a relation**

> Every `Relation#load` that runs a query (`to_a`, `each`, `first`, association readers…) allocated an empty binds Array
> in `exec_main_query`. Every association scope (`post.author`, `author.posts`) allocated another for `alias_tracker`'s
> default `joins`. Neither Array is read for content or mutated, so pass the existing `FROZEN_EMPTY_ARRAY`.
> With `prepared_statements: false` (the MySQL default), the `sql.active_record` payload's `binds` for these loads is now that frozen Array.
>
> Per call: 1 object fewer per relation load, 2 per association load (`post.author` 231 → 229).
> Across the corpus: 3–23 fewer objects per request (Writebook), 9–60 (Fizzy), 1–4 (CodeTriage on PostgreSQL). No timing claim.

**7 — Use drop instead of an endless Range for the join chain tail**

> Building SQL for `joins`, `left_joins` or `eager_load` (including `includes` that turns into a JOIN) walks each
> association's reflection chain. It allocated an endless Range per chain element for `reflection_chain[index..]`.
> `drop(index)` returns the same new Array without the Range.
>
> Per call: one object fewer per joined reflection (`Post.joins(:author).load` 153 → 152, through associations more).
> Across the corpus: 10–48 fewer objects per request on Fizzy's joined pages; the other apps' routes are within noise. No timing claim.

### Ranking and limits

By breadth of the pattern: 6 and 3 (every relation load or executed query), 5 (every HWIA/`params` `fetch` and enum cast), 4 (every `tag.*` element), 7 (joined queries only). Candidates 4 and 6 carry the disclosed boundaries above. 5 and 7 have only the error-message difference
(5) or no observable difference found (7). Local suites only, no hosted CI. The two-open-PR limit means at most
these two can follow once #59533 and #59534 resolve.
