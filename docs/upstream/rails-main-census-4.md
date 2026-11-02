# Rails-main allocation census 4: broad patterns across apps

Census 4 looks for framework sites that many apps hit through ordinary, idiomatic Rails code. Earlier censuses
ranked by objects saved on a few routes; this one ranks by **breadth first**. It counts how many apps, and what share
of 97 workloads, reach a Rails source line, and only then how many objects that line costs per operation.

**Four new exact candidates qualify**, each one commit on its own branch of the fork, based on canonical main. No PR
is open for any of them.

| # | Branch | Commit | Idiomatic pattern | Per call | Workloads moved (A/A) | Median per workload |
| --- | --- | --- | --- | ---: | ---: | ---: |
| 8 | [`thomasklemm/where-except-predicates-early`](https://github.com/thomasklemm/rails/tree/thomasklemm/where-except-predicates-early) | [`ae7f1c190e`](https://github.com/thomasklemm/rails/commit/ae7f1c190e69227cdae9b82a225fd41b7fefa39d) | every association read (`post.author`, `author.posts`), every `merge` into a relation without conditions | −7 to −8 | 82 / 81 of 97 (26 / 20) | −18.7 / −18.5 |
| 11 | [`thomasklemm/checkin-skip-empty-intents`](https://github.com/thomasklemm/rails/tree/thomasklemm/checkin-skip-empty-intents) | [`2e89cf912f`](https://github.com/thomasklemm/rails/commit/2e89cf912fdaead4612b46dc0bb442f5c3d9b4bd) | every connection checkin: each query run without a held lease, and the end of every request and job | −1 per checkin | 82 / 84 (26 / 20) | −7.0 / −7.1 |
| 9 | [`thomasklemm/spawn-except-without-values-copy`](https://github.com/thomasklemm/rails/tree/thomasklemm/spawn-except-without-values-copy) | [`0945b590f1`](https://github.com/thomasklemm/rails/commit/0945b590f1e0bf615a7d78da1260d108b979f2af) | every `except`/`only`, so every `exists?`, `count` on a scope, and through/association scope building | −1 | 62 / 61 (26 / 20) | −2.0 / −2.1 |
| 10 | [`thomasklemm/array-handler-ranges-on-demand`](https://github.com/thomasklemm/rails/tree/thomasklemm/array-handler-ranges-on-demand) | [`38a06fd8fa`](https://github.com/thomasklemm/rails/commit/38a06fd8faf3ab58866aac3c9cde469be21d8585) | every `where(column: array)`, so every `includes`/`preload` batch | −1 per Array condition | 60 / 56 (26 / 20) | −1.6 / −2.0 |

Interpreter / YJIT. "Workloads moved" counts workloads whose median objects per operation fell by at least one object,
against the A/A control in parentheses. Allocation counts only; no timing is inferred from them.

## Pins and method

* **Rails:** canonical `rails/rails` main [`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953),
  checked with `git ls-remote https://github.com/rails/rails refs/heads/main` on 2026-11-02 (main after #59533).
  Every app bundles it as a `github:` ref. The fork branches are based on the same commit.
* **Ruby 4.0.7**, interpreter and `--yjit` (no ZJIT), production environment, `RAILS_LOG_LEVEL=fatal`.
* **Harness:** [`rails_main_census_4.rb`](../../bench/upstream/rails_main_census_4.rb) and
  [`census_4_workloads.rb`](../../bench/upstream/census_4_workloads.rb). Requests go through
  `Rack::Test::Session` with cookies over `https://localhost`. Each response status is checked (200, 201, 302/303 or
  422, as the workload expects) and GET bodies must be non-empty. Every workload gets 50 warmup operations, then three
  GC-enabled windows of 20 operations (the median is the reported value), then 10 traced operations with GC disabled,
  attributed by allocation file and line.
* **Shared external controls, identical for every app:** jobs go to the `:test` adapter and are captured, mail uses
  the `:test` delivery method, `config.hosts` is cleared, and URL options default to `https://localhost` when the app
  reads its host from deployment settings. No app source is edited; overlays are dependency-only
  ([fixtures/corpus/rails-main-census-4](../../fixtures/corpus/rails-main-census-4)).
* **Workload kinds** (97 per mode): 38 HTML GET pages, 18 JSON (Jbuilder, `render json:`, Inertia JSON visits, bot
  APIs), 15 form POST/PATCH/PUT with validations and redirects (including 422s and Inertia error redirects), 7 Turbo
  Stream responses, 14 Active Job `perform`s (captured from real requests and executed through
  `ActiveJob::Base.execute`), and 5 mailer `deliver_now`s.
* **A/A:** two full unpatched runs (`base`, `base2`). Across 97 workloads per mode the median delta is +0.0, with 26/20
  workloads moving ≤ −1 and 20/31 moving ≥ +1. Single write workloads occasionally move by 10 to 140 objects in either
  direction (cache, timestamp and job-payload effects), so candidates are judged by the shift of the whole
  distribution, not by single cells. A first base run drifted by thousands of objects because rows accumulated across
  runs (blog comments, react-starter-kit sessions, Lobsters comments) and Lobsters only sometimes enqueued a page-cache
  job. Each workload now resets its own rows at setup, `CachePageJob` is excluded, and all numbers here come from the
  rerun.

### Apps

| App | Source pin | Database | Workloads | Notes |
| --- | --- | --- | ---: | --- |
| Blog | [rubys/roundhouse `bb90df2`](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9) `fixtures/real-blog` | SQLite | 10 | scaffold HTML/JSON, PATCH/POST with validations, Turbo broadcast job |
| Campfire | [basecamp/once-campfire `af4dd9f`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | SQLite | 9 | Turbo Stream message POST, bot JSON API, push/broadcast jobs |
| Writebook | [basecamp/writebook `7478e2c`](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84) | SQLite | 8 | Turbo Stream page edits, search POST, Markdown format |
| Fizzy | [basecamp/fizzy `77eada1`](https://github.com/basecamp/fizzy/commit/77eada1c8ead75c39f7fda5c80f322bcf5a9adb5) | SQLite **and MySQL 8.4.10** (trilogy) | 14 + 14 | comments (Turbo, JSON 201), Jbuilder JSON, magic-link mailer, four jobs |
| CodeTriage | [codetriage `d1868f8`](https://github.com/codetriage/codetriage/commit/d1868f8634e97a111a7fca49d58cc776d206007e) | PostgreSQL 15 | 7 | Devise remember-me, `render json:`, subscription PATCH, triage job |
| PingCRM | [ledermann/pingcrm `22464f8`](https://github.com/ledermann/pingcrm/commit/22464f822dcf59c4425993dd623780ad44497fda) | PostgreSQL 15 | 8 | Inertia (Vue) + Jbuilder props, Devise, CanCanCan, PUT/POST with errors |
| Redprints CFP | [evilmartians/redprints-cfp `6080fc2`](https://github.com/evilmartians/redprints-cfp/commit/6080fc24fbf0015f7e5a5ae932e903731502c65a) | SQLite | 8 | Inertia, form objects, Action Policy, parameterized mailer |
| React starter kit | [inertia-rails/react-starter-kit `f808193`](https://github.com/inertia-rails/react-starter-kit/commit/f8081935e9bda68f8ef1ec53dc7eed19c819ee68) | SQLite | 8 | Rails authentication generator style, Inertia, `UserMailer.with` |
| Lobsters | [lobsters `366e211`](https://github.com/lobsters/lobsters/commit/366e21167521eccd4c10a125cff45142c237275d) (main, 2026-11-01) | SQLite | 11 | real `POST /login`, story/tag pages, JSON feeds, votes, XHR comments, reply mailer |

Nine apps, ten runs per mode (Fizzy runs on two adapters and counts as one app for breadth).

Data: Fizzy's test fixtures (with its UUID fixture helper), CodeTriage, Campfire and Writebook test fixtures, the Blog's seeds, PingCRM's
seeds with `Faker::Config.random = Random.new(42)`, Lobsters' `FakeDataGenerator` with `srand(42)`. Redprints and
the starter kit seed only admins, so the workload creates one ordinary user (and for Redprints a speaker profile and a
submitted proposal) at setup.

Dependency changes beyond the Rails pin, all recorded in the overlays:

* **Redprints:** `view_component` 4.12.0 → 4.20.0. 4.12 calls `ActionView::Template.template_handler_extensions`,
  which main removed in [`cd416503e8`](https://github.com/rails/rails/commit/cd416503e86239f2365d0973f045caca8ac2a764)
  (Ractor-shareable handler registry). ViewComponent fixed it upstream (ViewComponent#2662).
* **Fizzy on MySQL:** MariaDB 10.11 rejects the schema's `utf8mb4_0900_ai_ci` collation and its JSON CHECK
  constraints refuse Fizzy's fixtures, so the MySQL run uses MySQL Community 8.4.10 (`--initialize-insecure`, local
  socket, port 3307).
* **Ruby pins:** Redprints (3.4.3), the starter kit (4.0.1) and Lobsters (4.0.9) move to 4.0.7.
* **Lobsters:** `config/database.yml` is the repository's own `database.yml.sample` (SQLite), as `bin/setup` does.

Not run, with reasons:

* **CASA:** does not resolve on main. `caxlsx ~> 4.5` needs `marcel ~> 1.0`, while main's Active Storage needs
  `marcel ~> 2.0`.
* **CodeTriage mailer:** maildown 3.3.1 (last release 2022-07) calls `ActionView::Template.registered_template_handler`,
  also removed in `cd416503e8`, so CodeTriage's Markdown mail cannot render on main. Its job workload still runs;
  only the mailer workload is missing.
* **Wikino:** bundles on main (Ruby and Rails pins moved), but it has no seeds or fixtures (factories only) and a
  route-per-controller design with typed services. Wiring a workload was deferred; it is not in the counts.
* **Mastodon:** not attempted in this census because of setup cost (Redis, Sidekiq, a Node build). Lobsters stands
  in as the public community app.

## Ranking

[`rails_main_census_4_rank.rb`](../../bench/upstream/rails_main_census_4_rank.rb) groups traced allocations by Rails
source line. A line *reaches* a workload when it allocates at least 0.5 objects per operation there. Lines are tiered
by the number of apps they reach (≥ 7, 5–6, 3–4, 2, 1). Within a tier, lines are ranked by the mean objects per
operation across all 97 workloads, which is objects per call times how often an ordinary operation gets there.
Single-app sites go to the bottom whatever their size. The full ranking is in the receipts (`rank-base2-*.tsv`).

Of 2,066 Rails lines, the 40 largest all reach all nine apps (except 25, which reaches seven). Top of the interpreter
ranking on unpatched main (`base2`), with dispositions:

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1 | AS `output_safety.rb:245` `String#html_safe` | 9 / 60% | 75.3 | Output SafeBuffers. Required. |
| 2 | AS `enumerable.rb:87` `index_with` → `to_h` pairs | 9 / 93% | 70.9 | **Rejected, deliberate design.** #59108 removed the pair Arrays; it was reverted in #59203 at byroot's request because an incrementally filled Hash spills to the C heap on Ruby 4.1 (ruby/ruby#18345). Callers are `IndexedRow.build_indexes`, `attributes_with_values`, `serializable_hash`. Revisit only with `Hash.new(capacity:)` (ruby/ruby#19537) and that team. |
| 3, 10 | AR `where_clause.rb:32/117` `merge` | 9 / 81% | 60.0, 30.1 | **Candidate 8** for the extraction Arrays. The `|` result is the merged clause. Required. |
| 4, 21, 40 | AV `tag_helper.rb:1545/1540/1751` | 9 / 55% | 45.4 | Element output Strings. Required. #59537 (open) covers the argument Array. |
| 5 | AS `output_safety.rb:73` SafeBuffer | 9 / 60% | 37.3 | Required. |
| 6 | AR `delegation.rb:140` `Relation.create` | 9 / 89% | 37.3 | Relation objects. Required. |
| 7, 15 | AS `time/calculations.rb:173/168` Rationals in `Time#change` | 9 / 54% | 36.7, 24.8 | From `TimeWithZone#change(nsec:)` in `apply_seconds_precision` (every timestamp write with precision 6) and `Time#advance`. A non-Rational path would change how sub-second values are built across zones and DST. Not a small exact change. Untried; recorded as a lead for the time-calculation work (#59397, #59402 merged nearby). |
| 8, 17, 19 | AR `relation.rb:80/101/1345` values Hashes | 9 / 89% | 34.7, 23.3, 21.8 | Per-relation state and copies. `values` (1345) has one avoidable copy in `except`/`only`: **candidate 9**. The Merger's `other.values` copy is read-only too but escapes through `Merger#values` (an attr_reader). Untried. |
| 9 | Arel `table.rb:91` Attribute | 9 / 90% | 31.7 | Per-query AST. Caching would be a memo on a mutable Table. Refused. |
| 11, 22, 23 | AS notifications fanout | 9 / 98% | 29.3 | Instrumentation groups and handles, one per instrumented event. Required while a subscriber listens; open #58957 reduces the structured-event share. |
| 12 | AM `attribute_set/builder.rb:20` | 9 / 96% | 27.7 | Overlaps open #59141 (tenderlove, Array-backed attributes). |
| 13 | AR `predicate_builder.rb:146` `expand_from_hash` | 9 / 86% | 27.2 | `flat_map` result is the predicates. Required. |
| 14 | AP `url.rb:361` | 9 / 45% | 25.3 | URL output. Required. |
| 16 | AM `type/string.rb:40` | 9 / 91% | 24.0 | Defensive copy of a mutable String. Required. |
| 18 | AR `associations.rb:62` association objects | 9 / 86% | 22.0 | Required. |
| 20 | AR `result.rb:196` IndexedRow | 9 / 93% | 21.2 | Overlaps #59141. |
| 24 | AS `hash/keys.rb:13` `stringify_keys` | 9 / 81% | 18.1 | Mostly `stylesheet_link_tag` (260 of 471 calls in Fizzy) and `link_to` data options. Public option normalization; the result is mutated. Required. |
| 25 | AV `asset_tag_helper.rb:723` preload links | 7 / 33% | 17.8 | Link header output. Required. |
| 26, 28, 31 | Arel select statement, Equality, WhereClause nodes | 9 / 79–87% | 15–17 | Per-query AST. |
| 27 | AS `array/extract.rb:15` `extract!` | 9 / 86% | 16.7 | Callers are `except_predicates` (two per merge) and `ArrayHandler`. **Candidates 8 and 10.** |
| 29 | AR `database_statements.rb:871` `@unfinalized_intents = []` | 9 / 97% | 15.6 | **Candidate 11.** `finalize_remaining_intents` runs on every connection checkin and swapped in a new empty Array even when none was pending. |
| 32, 33 | AR `merger.rb:164`, `spawn_methods.rb:51` | 9 / 81% | 15.0 | `extending!(*other.extensions)` rest Array through a public bang signature, and the Merger itself. Rejected (public signature / required object). |
| 34, 35 | AM `indexed_row.rb` | 9 / 93% | 14.2 | Overlaps #59141. |
| 36 | AR `association_scope.rb:159` | 9 / 75% | 14.0 | Per-association scope state. |
| 37 | AR `abstract_adapter.rb:1270` RetryBudget | 9 / 93% | 14.0 | One per query; carries per-query deadline state. Required. |
| 38 | AR `persistence.rb:278` records | 9 / 96% | 13.8 | Model instances. Required. |
| 39 | AS `subscriber.rb:142` `event.name[0, index]` | 9 / 97% | 13.8 | Method name per event for `send`, mostly from structured event subscribers. A per-name memo would be a cache on the subscriber, and open #58957 (skip structured events no log subscriber would log) removes many of these calls. Not attempted. |

Further down (ranks 41–160, still ≥ 7 apps), the ranking is dominated by the same families: Arel select cores and
collectors (one per compile), `QueryIntent`, Result arrays, reflection chains, AliasTracker (`alias_tracker`'s
`joins = []` is open #59538), `querying.rb:83/84` (binds default in #59538; the `"#{name} Load"` String is the
notification name), CSRF HMAC objects, render and template objects, and `thread_mattr` key Strings (a per-class memo
was refused in census 3b). These keep the census-3/3b dispositions.

**Already covered:** applying the six open PRs (#59534–#59539) together moves 88/89 of 97 workloads, with a median of
−18.9 / −15.0 objects per workload. The candidates below are measured against unpatched main and do not touch those
PRs' lines.

## Candidates

All four are exact. They keep live method dispatch (no memo, no boot certificate, no cache of mutable state), keep
every observable return value, and each is one commit on [`b5be03636e`](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953)
by Thomas Klemm `<github@tklemm.eu>` (author and committer), with no trailers.

### Per-call micro

[`census_4_allocs.rb`](../../bench/upstream/census_4_allocs.rb), SQLite in memory, objects per warmed call,
interpreter / YJIT:

| Pattern | Clean main | 8 (merge) | 9 (except) | 10 (ranges) |
| --- | ---: | ---: | ---: | ---: |
| `post.author` (belongs_to reader) | 235 / 239 | **228 / 232** | 235 / 239 | 235 / 239 |
| `author.posts.to_a` (has_many reader) | 252 / 258 | **245 / 251** | 252 / 258 | 252 / 258 |
| `author.published_posts.to_a` (scoped has_many) | 319 / 328 | **311 / 320** | 319 / 328 | 319 / 328 |
| `author.posts.exists?` | 255 / 260 | **248 / 253** | **254 / 259** | 255 / 260 |
| `Post.where(author_id: 1).merge(Post.published).to_a` | 128 / 133 | **126 / 131** | 128 / 133 | 128 / 133 |
| `Post.where(author_id: 1).exists?` | 94 / 97 | 94 / 97 | **93 / 96** | 94 / 97 |
| `Post.order(:id).except(:order).to_a` | 131 / 133 | 131 / 133 | **130 / 132** | 131 / 133 |
| `Post.where(author_id: 1).only(:where).to_a` | 106 / 109 | 106 / 109 | **105 / 108** | 106 / 109 |
| `Post.where(id: ids).to_a` | 172 / 174 | 172 / 174 | 172 / 174 | **171 / 173** |
| `Post.where(id: [id, nil]).to_a` | 101 / 103 | 101 / 103 | 101 / 103 | **100 / 102** |
| `Post.where(id: [1..2, 5]).to_a` (has a Range) | 125 / 128 | 125 / 128 | 125 / 128 | 125 / 128 |
| `Author.includes(:posts).to_a` | 413 / 423 | 413 / 423 | 413 / 423 | **412 / 422** |
| `Post.preload(:author, :comments).to_a` | 691 / 704 | 691 / 704 | 691 / 704 | **689 / 702** |

Candidate 11, interpreter / YJIT (same in both modes): `Post.first` with no lease held, which checks the connection in
after the query, 118 → 117 (120 → 119). A bare lease and release (`connection` then `release_connection`) 1 → 0. Every
other row above is unchanged on branch 11.

### Request deltas

[`census_4_compare.rb`](../../bench/upstream/census_4_compare.rb), median per workload (patched − `base2`), per app,
interpreter / YJIT:

| App | A/A | 8 merge | 9 except/only | 10 ranges | 11 checkin |
| --- | ---: | ---: | ---: | ---: | ---: |
| Blog | +0.0 / +0.0 | +0.0 / +0.9 | +0.0 / +0.0 | +0.0 / +0.7 | −1.0 / −1.7 |
| Campfire | +0.0 / +0.0 | **−21.0 / −21.0** | −1.0 / −1.8 | −0.8 / −0.5 | −5.0 / −5.0 |
| Writebook | +0.4 / +0.0 | **−43.0 / −40.0** | −0.1 / −0.8 | −3.0 / −2.0 | −13.4 / −14.0 |
| Fizzy (SQLite) | +0.0 / +0.1 | **−65.1 / −77.1** | −4.0 / −4.1 | −3.0 / −5.0 | −23.4 / −23.5 |
| Fizzy (MySQL) | +0.0 / +0.0 | **−90.0 / −93.0** | −5.6 / −8.0 | −3.0 / −5.0 | −20.0 / −22.0 |
| CodeTriage (PG) | −0.8 / +0.3 | **−9.0 / −9.4** | −2.0 / −2.0 | −2.2 / −6.3 | −3.3 / −7.0 |
| PingCRM (PG) | +1.0 / +1.6 | **−9.1 / −5.1** | −1.3 / −2.8 | −0.2 / +1.9 | −3.7 / +0.1 |
| Redprints | −0.6 / −1.3 | **−5.9 / −8.7** | −0.5 / −0.5 | +0.0 / −0.1 | −1.8 / −1.5 |
| React starter kit | +0.4 / +0.0 | **−8.8 / −5.7** | −0.3 / +0.8 | +0.4 / +0.6 | −3.5 / −2.8 |
| Lobsters | −2.0 / +0.0 | **−24.3 / −29.5** | −3.8 / −5.9 | −7.0 / −10.7 | −16.3 / −20.7 |
| **All 97 workloads** | **+0.0 / +0.0** | **−18.7 / −18.5** | **−2.0 / −2.1** | **−1.6 / −2.0** | **−7.0 / −7.1** |
| Moved ≤ −1 / ≥ +1 | 26 / 20 · 20 / 31 | 82 / 4 · 81 / 4 | 62 / 11 · 61 / 6 | 60 / 15 · 56 / 17 | 82 / 8 · 84 / 5 |

(A/A column: per-app medians of `base2 − base`.) Largest single-workload savings for 8 (interpreter): Fizzy board page −370 and card page −211,
Writebook leaf page −106, Lobsters story page −102, Campfire bot message POST −88. Candidate 8 reaches every app; the
blog's only association reads are on the article page (−17) and comment POST (−43), so its median stays at 0.

### Why each one is exact, and its boundaries

8. **Merge into an empty WhereClause.** `merge` extracted `other`'s attributes into an Array, and `except_predicates`
   then partitioned it with two `extract!` calls into two more Arrays, only to `reject` over zero predicates. Every
   `Relation#merge` merges both the where and the having clause through this method (traced: 129 calls each on
   Lobsters' workloads), and association reads merge their scopes into relations without conditions; the having clause
   is almost always empty on both sides.
   Now `merge` returns `self.predicates | other.predicates` directly when the receiver is empty, `except_predicates`
   returns early when there are no predicates, and the second `extract!` is skipped when every column was an
   attribute. The `|` result is a new Array as before. `columns` is a fresh Array in both callers (`extract_attributes`
   and `except(*columns)`), so skipping `extract!`'s mutation of it is unobservable. **Boundary:** none observable
   found. `WhereClause` is `:nodoc:`.
9. **`except`/`only` without a values copy.** `values` returns `@values.dup`, and `except`/`slice` then build another
   Hash from the copy. Reading `@values` builds the same new Hash. `Relation#values` is `:nodoc:` and not overridden
   anywhere in Rails. **Boundary:** a subclass of `Relation` that overrides `values` would no longer affect
   `except`/`only`. No class in Rails overrides it; third-party code was not searched.
10. **Ranges only when present.** `ArrayHandler#call` (every `where(column: array)`, including the `IN` query each
    preloaded association runs) always called `values.extract! { Range }`, allocating an empty Array in the common
    case. It now extracts only if `values.any? { |v| v.is_a?(Range) }`, which uses the same `is_a?` dispatch per value
    and allocates nothing. **Boundary:** none. `ranges` is local, and `nil` replaces the empty Array test.
    Open #57694 (`Arel.array_bind`) edits the same file on other lines; a rebase is trivial.
11. **Checkin without pending intents.** `AbstractAdapter#expire` calls `finalize_remaining_intents` on every checkin
    (added in [`635454d310`](https://github.com/rails/rails/commit/635454d310) "Finalize unfinished intent logs on
    checkin"). It swapped `@unfinalized_intents` for a new `[]` before iterating, even when empty. With Rails' default
    per-block leasing, each query that runs without a held lease checks the connection in afterwards, so this runs per
    query in many apps, plus once at the end of each request and job. Returning early when the Array is empty leaves
    the same empty Array in place; the ivar is private to the adapter and every reader (`<<`, `delete`) reads it
    afresh. The non-empty path is unchanged and covered by `connection_pool_test.rb`'s finalization tests.
    **Boundary:** none observable found. No open PR touches the method.

### Behavior controls and suites

[`census_4_controls.rb`](../../bench/upstream/census_4_controls.rb) records 30 SQL-and-result snapshots: IN lists
with nils, only nil, empty, single values, Ranges (bounded, endless, mixed with nils), records, `where.not`, `merge`
(overriding, into empty, of empty, SQL strings, Arel function nodes), `rewhere`, `unscope`, `or`, plain, scoped and
SQL-scoped `has_many`, `belongs_to`, `includes`/`eager_load`, `except(:order)`, `except(:where)` on an association,
`only(:where)` and `only()`, each with `exists?`. They are identical between clean main and every branch, in both
modes.

Local suites, Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, seed 41231, serial:

* **Active Record SQLite, full:** branches 8, 9, 10 (after their final amends) and 11 each give 10,247 runs,
  0 failures, 0 errors, 52 skips, the same count as clean main in census 3b.
* **Active Record PostgreSQL 15, full, branch 8:** 11,166 runs, 0 failures, 0 errors, 31 skips. Clean main: 11,166 runs, 0 failures, 0 errors,
  31 skips, identical.
* **RuboCop:** each branch's changed file, no offenses.
* **Controls:** identical on branch 11 as well, in both modes.

### PR description drafts (not published)

**8 — Skip unneeded Arrays when merging into an empty WhereClause**

> Every association read (`post.author`, `author.posts`, scoped `has_many`) merges the association's conditions into a
> relation that has none yet. `WhereClause#merge` still extracted the other clause's attributes into an Array and
> `except_predicates` split it into two more, only to filter zero predicates. Skip that work when the receiver has no
> predicates, and skip the second split when every column was an attribute. The merged clause is the same.
>
> Per call: `post.author` 235 → 228 objects, `author.posts.to_a` 252 → 245, a scoped `has_many` 319 → 311 (YJIT the
> same −7/−8). Across nine apps on Rails main (SQLite, PostgreSQL, MySQL), 82 of 97 request, job and mailer workloads
> allocate fewer objects; the median workload saves 19. Allocation counts only; no timing claim.

**9 — Avoid copying relation values in except and only**

> `Relation#except` and `#only` took `values` (a dup of the values Hash) and then built another Hash with
> `except`/`slice`. Read `@values` directly. `exists?`, `count` on a scope, and association scope building go through
> `except`, so ordinary reads hit it.
>
> Per call: one Hash fewer (`Post.where(...).exists?` 94 → 93, `author.posts.exists?` 255 → 254). Across nine apps,
> 62 of 97 workloads allocate fewer objects (median −2). No timing claim.

**11 — Skip finalizing intents on checkin when none are pending**

> Every connection checkin (the end of each request and job, and after each query that runs without a held lease,
> which is the default per-block leasing) replaced the pending-intents Array with a new empty one, even when it was
> already empty. Return early instead; pending intents are still finalized as before.
>
> Per call: one Array fewer per checkin (`Post.first` without a held lease 118 → 117). Across nine apps, 82 of 97
> workloads allocate fewer objects (median −7). No timing claim.

**10 — Only extract Ranges in ArrayHandler when there are any**

> Every `where(column: array)` (including the `IN` query each `includes`/`preload` batch runs) extracted Range values
> into a new Array that is empty unless the list holds a Range. Check first with the same `is_a?` test and skip the
> extraction otherwise.
>
> Per call: one Array fewer (`Post.where(id: ids).to_a` 172 → 171, `Post.preload(:author, :comments)` 691 → 689).
> Across nine apps, 60 of 97 workloads allocate fewer objects (median −1.6). No timing claim.

## Rejected and deferred, with reasons

Beyond the ranking table:

* **`index_with` pair Arrays (rank 2):** a deliberate design choice, reverted upstream (#59203). Not reopened.
* **Rationals in `Time#change` (7, 15):** exact alternatives touch zone/DST construction. Not small. Lead only.
* **`Merger#initialize` `other.values` copy:** read-only in `merge`, but exposed through the `values` attr_reader.
  Untried; it would need confirmation that no caller mutates `Merger#values`.
* **`Subscriber#call` method-name String (39):** a memo per event name would be a cache. Overlaps #58957.
* **`stringify_keys`/`symbolize_keys` in `stylesheet_link_tag` (24):** the options Hash is mutated afterwards
  (`delete`, `merge!`). Avoiding the copy changes caller-visible ownership. Rejected.
* **`thread_mattr` keys, `"#{name} Load"`, Arel attribute caching:** memos. Refused, as in census 3b.
* **Single-app sites** (Fizzy filters helper, Lobsters' own helpers, CodeTriage's maildown): app code or gems, not
  Rails.

## Leads for ruby/ruby (not Rails PRs)

Lines that allocate only under YJIT on Rails' request paths (summed across all workloads, interpreter → YJIT):
`core.rb:481` `Relation.create(self)` 0 → 2,199, `abstract_adapter.rb:1426/1432` collector construction 0 → 397 and
0 → 396, `params_wrapper.rb:264` `def process_action(*) … super` 0 → 68, `instrumentation.rb:74` `super` in a block 0 →
78, `locking/optimistic.rb:72` and `builder/belongs_to.rb:87`. `<internal:array>` lines appear only under YJIT because
YJIT runs Ruby implementations of `Array#each`/`map`/`select`, so the interpreter attributes those allocations to their
callers. That is an attribution shift, not extra allocation.

Standalone reproduction on Ruby 4.0.7 ([`census_4_yjit_probe.rb`](../../bench/upstream/census_4_yjit_probe.rb), no Rails; the last two rows come from a Rails micro on clean main), objects per call, interpreter → YJIT:

| Shape | Interpreter | YJIT |
| --- | ---: | ---: |
| `Sub.new` where `Sub#initialize` calls zsuper `super` | 4 | 8 |
| `Kw.new(1)` with `initialize(x, y = nil)` | 1 | 3 |
| `Comp.new(1, 2)` with `initialize(*parts)` | 2 | 4 |
| `def f(*) = super` (zsuper with anonymous rest) | 3 | 4 |
| `Post.connection.send(:collector)` (Arel collectors) | 5 | 23 |

So YJIT allocates two extra objects per `Class#new` when `initialize` has optional or rest parameters, and more when
`initialize` uses zsuper. These belong in a ruby/ruby report with this script, not in Rails.

## Limits

* Local suites only; no hosted CI for the Rails changes. The fork runs only `rails-new-docker` and the devcontainer
  smoke test.
* MySQL is covered by one app (Fizzy on MySQL 8.4). The MySQL and PostgreSQL suites were not rerun for branches 9,
  10 and 11, which do not touch adapter code; branch 8 ran the PostgreSQL suite.
* Candidates 8, 9 and 10 were also measured together (`new3`): median −21.3 / −20.5 per workload, 81 / 83 of 97
  moved, about the sum of the three, so they do not overlap. Candidate 11 was measured alone.
* Receipts: [data/rails-main-census-4/receipts.tar.gz](data/rails-main-census-4/receipts.tar.gz) holds the ranking
  TSVs, every compare output, and every run's JSON trimmed to the top 200 sites per workload. Full receipts stay under
  `.lowrail/private/rails-main-census-4/`.

