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

> The abstract adapter returned a new `[]` from `collect_warnings` for every query. PostgreSQL swapped
> in a new Array even when no notice had arrived. Return a frozen empty Array in those cases.
> Collected warnings are handed over and reset as before.
>
> One Array fewer per query on SQLite and PostgreSQL, and on MySQL when no warnings are pending or
> warnings are disabled. Fizzy: 60/22/13 fewer objects per request. Blog: 2 fewer. The interpreter and
> YJIT agree. No timing claim.

## Blockers and limits

* No PostgreSQL corpus app was profiled, so the type-map candidate stays unmeasured.
* Suite coverage is local only (see above). The postgres_fdw foreign-table errors are environmental and
  appear on clean main as well.
* The Amp GitHub integration cannot subscribe to `rails/rails`, so CI and review monitoring after PRs
  open will have to be manual.
* The YJIT-only `...` forwarding Array (rank 107) is a lead for ruby/ruby and needs its own ruby-bench evidence
  under DECISIONS' submission bar.
