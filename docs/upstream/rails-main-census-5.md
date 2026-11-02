# Rails-main allocation census 5: after the census-4 merges

Census 5 reruns the [census-4](rails-main-census-4.md) harness on canonical Rails main after Rails merged all eleven PRs
from censuses 3, 3b and 4 (#59533–#59539, #59541–#59544). It ranks Rails source lines by breadth first: how many apps,
and what share of 97 workloads, reach a line; then objects per call times frequency.

Between the census-4 pin and this one, the median workload allocates 40 fewer objects (92 of 97 workloads moved,
interpreter; 94 under YJIT). Every census-4 candidate site is gone from the ranking (`where_clause.rb:117`, `extract.rb:15`,
`database_statements.rb:871`, `querying.rb:83`, `relation.rb:1369`).

**Four new exact candidates qualify**, each one commit on its own branch of the fork, based on canonical main. All four
are in Active Record's relation merging and association scope building. No PR is open for any of them.

| # | Branch | Commit | Idiomatic pattern | Per call | Workloads moved (A/A 17 / 18) | Median per workload | With open #59212 |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| 12 | [`thomasklemm/merge-skip-empty-extending`](https://github.com/thomasklemm/rails/tree/thomasklemm/merge-skip-empty-extending) | [`2c301c33bf`](https://github.com/thomasklemm/rails/commit/2c301c33bf539fbecd1d2bf714e08a8cd37ed46a) | every `Relation#merge`: association reads and relations (`author.posts.where(…)`, `.count`, `.exists?`), `merge(Post.published)` | −1 per merge | 76 / 74 of 97 | −5.8 / −6.0 | 63 / 62, −3.6 / −3.0 |
| 13 | [`thomasklemm/association-constraints-without-chain`](https://github.com/thomasklemm/rails/tree/thomasklemm/association-constraints-without-chain) | [`58ecb375e7`](https://github.com/thomasklemm/rails/commit/58ecb375e7f0c6c0a7e2a3a5d81ec4d61a0eb924) | every association scope build (`post.comments.size`, scoped and through readers, association relations) | −2 per direct reflection in the chain | 74 / 72 | −7.3 / −6.7 | 63 / 62, −3.8 / −3.3 |
| 14 | [`thomasklemm/default-extensions-frozen-empty`](https://github.com/thomasklemm/rails/tree/thomasklemm/default-extensions-frozen-empty) | [`e8c30f991d`](https://github.com/thomasklemm/rails/commit/e8c30f991dc2d654ab90cd5946fd5e229a28454f) | every collection association proxy (`author.posts`) on a model without a default scope | −1 | 58 / 55 | −1.6 / −1.3 | 61 / 55, −1.8 / −1.1 |
| 15 | [`thomasklemm/merger-bang-method-names`](https://github.com/thomasklemm/rails/tree/thomasklemm/merger-bang-method-names) | [`40be14ce8d`](https://github.com/thomasklemm/rails/commit/40be14ce8d550df3d5f56b532dffd2534a1f1d7a) | merging a relation that sets `limit`, `offset`, `distinct`, `readonly`, `references`… (every singular association reader merges `limit(1)`) | −1 per merged value | 66 / 62 | −3.0 / −2.0 | 51 / 34, −1.0 / +0.0 |

Interpreter / YJIT. "Workloads moved" counts workloads whose median objects per operation fell by at least one object;
the A/A control moves 17 / 18 workloads by that much (and 24 / 23 up). Numbering continues from census 4 (1–11).
Allocation counts only; no timing is inferred from them.

**Ranking of the candidates.** 12 and 13 reach all nine apps at 79–81 % of workloads and keep about 63 of 97 workloads
even with open #59212 applied. 14 is smaller but survives #59212 unchanged. 15 is exact but depends on the association
reader path: with #59212 applied it moves 51 interpreter workloads and is flat under YJIT (34 moved vs. 18 in A/A), so
it should wait for #59212's outcome.

## Pins and method

* **Rails:** canonical `rails/rails` main [`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0)
  (merge of #59544), checked with `git ls-remote https://github.com/rails/rails refs/heads/main` on 2026-11-02. It
  contains all eleven merged census PRs. Every app bundles it as a `github:` ref; the fork branches are based on it.
* **Ruby 4.0.7**, interpreter and `--yjit` (no ZJIT), production environment, `RAILS_LOG_LEVEL=fatal`.
* **Harness:** census 4's [`rails_main_census_4.rb`](../../bench/upstream/rails_main_census_4.rb),
  [`census_4_workloads.rb`](../../bench/upstream/census_4_workloads.rb), ranking
  [`rails_main_census_4_rank.rb`](../../bench/upstream/rails_main_census_4_rank.rb) and
  [`census_4_compare.rb`](../../bench/upstream/census_4_compare.rb), unchanged except that `boot` also accepts
  `.corpus/census5-*` copies; the pin comes from `CENSUS_RAILS_PIN`. Same request client, status checks, 50 warmups,
  three GC-enabled windows of 20 operations (median reported) and 10 traced operations with GC disabled.
  [`census_5_run.sh`](../../bench/upstream/census_5_run.sh) is the runner (one app, all ten configurations, or a run
  with patches applied to the shared bundled Rails checkout and restored from a pristine copy afterwards; census 4's
  equivalents were never committed). [`census_5_table.rb`](../../bench/upstream/census_5_table.rb) prints the per-app
  table below.
* **Same shared controls as census 4:** `:test` job adapter with captured jobs executed as their own workloads,
  `:test` mail delivery, cleared `config.hosts`, `https://localhost` URL defaults. Each workload resets its own rows
  at setup; Lobsters' `CachePageJob` is excluded. Overlays are dependency-only.
* **Workloads (97 per mode):** the census-4 set unchanged: 38 HTML pages, 18 JSON, 15 form writes, 7 Turbo Stream, 14
  job `perform`s, 5 mailer `deliver_now`s.
* **A/A:** two full unpatched runs (`base`, `base2`): median +0.0 in both modes, 17 / 18 workloads move ≤ −1 and
  24 / 23 move ≥ +1. Candidates are measured against `base2`.
* **State reset:** every run is a fresh process per app and mode; the patched runs patch the bundled checkout, run all
  ten configurations, and restore it (checked identical with `diff -rq` afterwards). No `bundle` command ran during
  measurement.
* **Overlap with open #59212.** That PR (bruno-costanzo, "Don't build the association scope when the reader uses the
  statement cache") removes the association-scope build from every statement-cached association reader, which is
  where part of candidates 12, 13 and 15 save. It moves 75 / 74 workloads by itself (median −46 / −49). Each
  candidate was therefore also measured on top of #59212 (`pr59212-*` runs against `pr59212`).

### Apps

Same nine apps and pins as census 4, rebuilt from scratch in a fresh orb (MySQL 8.4.10 and PostgreSQL 15.19 as local
services; memcached and Redis for CodeTriage and Campfire). Overlays:
[fixtures/corpus/rails-main-census-5](../../fixtures/corpus/rails-main-census-5), each the diff of `Gemfile`,
`Gemfile.lock` and `.ruby-version` against the app's pin.

| App | Source pin | Database | Workloads | `Gemfile.lock` SHA-256 |
| --- | --- | --- | ---: | --- |
| Blog | [rubys/roundhouse `bb90df2`](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9) `fixtures/real-blog` | SQLite | 10 | `8691bb361174…` |
| Campfire | [basecamp/once-campfire `af4dd9f`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | SQLite | 9 | `045f5b00ab54…` |
| Writebook | [basecamp/writebook `7478e2c`](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84) | SQLite | 8 | `168d2ecceabd…` |
| Fizzy | [basecamp/fizzy `77eada1`](https://github.com/basecamp/fizzy/commit/77eada1c8ead75c39f7fda5c80f322bcf5a9adb5) | SQLite **and MySQL 8.4.10** (trilogy) | 14 + 14 | `67749ef184f9…` |
| CodeTriage | [codetriage `d1868f8`](https://github.com/codetriage/codetriage/commit/d1868f8634e97a111a7fca49d58cc776d206007e) | PostgreSQL 15 | 7 | `d25d8756e35d…` |
| PingCRM | [ledermann/pingcrm `22464f8`](https://github.com/ledermann/pingcrm/commit/22464f822dcf59c4425993dd623780ad44497fda) | PostgreSQL 15 | 8 | `e3de270c840f…` |
| Redprints CFP | [evilmartians/redprints-cfp `6080fc2`](https://github.com/evilmartians/redprints-cfp/commit/6080fc24fbf0015f7e5a5ae932e903731502c65a) | SQLite | 8 | `7c4224eed602…` |
| React starter kit | [inertia-rails/react-starter-kit `f808193`](https://github.com/inertia-rails/react-starter-kit/commit/f8081935e9bda68f8ef1ec53dc7eed19c819ee68) | SQLite | 8 | `e23229707a92…` |
| Lobsters | [lobsters `366e211`](https://github.com/lobsters/lobsters/commit/366e21167521eccd4c10a125cff45142c237275d) | SQLite | 11 | `552a38f8de43…` |

How the copies were built (none of this was committed for census 4):

* Source at the pin, then census 4's overlay with the Rails ref moved from `b5be036` to `5810776`. Census 4's
  overlays applied unchanged to Campfire, Writebook, Fizzy, PingCRM, Redprints, the starter kit and Lobsters, so their
  locks differ from census 4's only in the Rails revision. CodeTriage's applies on top of the older
  [codetriage.patch](../../fixtures/corpus/codetriage.patch) (Rails 8.1.4, Ruby 4.0.7). The Blog is regenerated
  locally by `script/corpus real-blog`, so its lock does not match census 4's; it took the `Gemfile` line and
  `bundle update rails --conservative`.
* Databases: `db:create db:schema:load` in production; the census `prepare` step loads seeds (Blog) or test fixtures
  (Campfire, Writebook, Fizzy on both adapters, CodeTriage). PingCRM: seeds with
  `Faker::Config.random = Random.new(42)` (1 account, 6 users, 100 contacts, 100 organizations). Lobsters:
  `config/database.yml` from the sample, `db:prepare`, then `FakeDataGenerator` with `srand(42)` (54 users, 110
  stories, 1,175 comments, 78 tags, as in census 4). CodeTriage uses its own `database.example.yml`. Then
  `assets:precompile` (with `bun install`/`npm ci` for the Inertia apps).
* MySQL 8.4.10 is the `linux-glibc2.28` minimal tarball, `--initialize-insecure`, port 3307, root without password;
  it needs `libaio1` in this orb.

Not run, unchanged from census 4: CASA (`caxlsx` needs `marcel ~> 1`, main needs `~> 2`), CodeTriage's mailer
(maildown calls a removed template-handler API), Wikino (no seeds or fixtures), Mastodon (setup cost). No extra app was
added; the nine boot and pass every workload on this pin.

## Ranking

Of 2,038 Rails lines, the top 45 by mean objects per operation all reach at least seven apps. Top of the interpreter
ranking on unpatched main (`base2`), with dispositions; lines whose disposition did not change since census 4 are
grouped.

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1, 5 | AS `output_safety.rb:245/73` SafeBuffers | 9 / 60% | 75.3, 37.3 | Output. Required (census 4). |
| 2 | AS `enumerable.rb:87` `index_with` | 9 / 93% | 70.9 | **Out of scope:** revisited in a separate thread. |
| 3 | AR `where_clause.rb:32` `WhereClause.new(predicates \| other.predicates)` | 9 / 81% | 60.0 | The merged clause itself. Required. (Its extraction Arrays, census-4 rank 10, are gone after #59541.) |
| 4, 19, 37 | AV `tag_helper.rb` element Strings | 9 / 50–55% | 45.4, 21.0, 13.8 | Output. Required. Open #57999 works on attribute strings. |
| 6, 8, 16 | AR `Relation.create`, `relation.rb:80/101` values Hashes | 9 / 80–89% | 37.3, 34.7, 23.3 | Relation objects and copies. Required. |
| 7, 14 | AS `time/calculations.rb:173/168` Rationals | 9 / 54–57% | 36.8, 24.9 | Lead from census 4 (zone/DST construction). Not small. |
| 9, 25, 26 | Arel attributes, select statement, Equality | 9 / 79–90% | 15–32 | Per-query AST. Required. |
| 10, 20, 21, 38, 40, 41 | AS `notifications/fanout.rb` groups, handles, events | 9 / 97–98% | 13–29 | Instrumentation bookkeeping per event. Lines 286/290 build the active-subscription list for silenceable subscribers that are not silenced. Which subscribers those are was not traced; open #58957 (skip structured events no log subscriber would log) may remove part of them. Not attempted. |
| 11, 31, 32 | AM `attribute_set/builder.rb:20`, `indexed_row.rb` | 9 / 93–96% | 14–28 | Overlaps open #59141 (tenderlove, Array-backed attributes). |
| 12, 42 | AR `predicate_builder.rb:146/129` | 9 / 84–86% | 27.2, 13.3 | Predicates and binds. Required. |
| 13 | AP `url.rb:361` | 9 / 45% | 25.3 | URL output. Required. |
| 15 | AM `type/string.rb:40` | 9 / 91% | 24.0 | Defensive copy. Required. |
| 17 | AR `associations.rb:62` association objects | 9 / 86% | 22.0 | Required. |
| 18 | AR `result.rb:196` IndexedRow | 9 / 93% | 21.2 | Overlaps #59141. |
| 22 | AS `hash/keys.rb:13` `stringify_keys` | 9 / 81% | 18.2 | Mostly `stylesheet_link_tag` (260 of 471 calls in Fizzy) and `link_to` data options; the copy is mutated afterwards. Rejected in census 4. |
| 23 | AR `relation.rb:1345` `values` (`@values.dup`) | 9 / 84% | 17.9 | Since #59543, 547 of 667 calls in Fizzy (129 of 219 in Lobsters) come from `Merger#initialize`, the rest from `empty_scope?` (preloader) and `structurally_incompatible_values_for`. **Lead, not a PR:** see below. |
| 24 | AV `asset_tag_helper.rb:723` early hints | 7 / 33% | 17.8 | Link header output. Required. Open #59428 touches the preload links. |
| 27 | AM `attribute.rb:10` | 9 / 67% | 15.3 | Attribute objects. Required. |
| 28 | AR `query_methods.rb:1989` `WhereClause.new(parts)` | 9 / 87% | 15.2 | The built clause. Required. |
| **29** | AR `merger.rb:164` `extending!(*other.extensions)` | 9 / 81% | 15.0 | **Candidate 12.** One rest Array per merge, for a call that returns immediately. |
| 30 | AR `spawn_methods.rb:51` Merger | 9 / 81% | 15.0 | The Merger object. Required. |
| 33 | AR `association_scope.rb:159` `scope.where!(key => value)` | 9 / 75% | 14.0 | Public bang API with a Hash argument. Required. |
| 34 | AR `abstract_adapter.rb:1270` RetryBudget | 9 / 93% | 14.0 | Per-query state. Required. |
| 35 | AR `persistence.rb:278` records | 9 / 96% | 13.8 | Model instances. Required. |
| 36 | AS `subscriber.rb:142` method name | 9 / 97% | 13.8 | Memo would be a cache; overlaps #58957. As census 4. |
| 39 | AS `date_and_time/zones.rb:38` TimeWithZone | 9 / 72% | 13.3 | Required. |
| 43, 67 | AR `scoping/default.rb:170/66` `method(:default_scope).owner` | 9 / 87–88% | 13.1, 9.1 | A `Method` per `has_default_scope?`/`build_default_scope` to detect a user-defined `default_scope` method. No allocation-free owner query exists; tracking definitions would be a cache. Lead only. |
| 44 | AS `deep_dup.rb:18` | 7 / 70% | 12.7 | Mostly Sentry breadcrumbs and app payloads. Not Rails' own work. |
| **45**, 102, 103 | AR `reflection.rb:765` `[self]`, `:223/:276` `scopes`/`constraints` | 9 / 79% | 12.7, 5.9, 5.9 | **Candidate 13** for the `constraints` share (`[self]` and the `flat_map` result). |
| 46 | AR `sqlite3/database_statements.rb:149` Result | 7 / 63% | 12.6 | Required. |
| 47, 48 | AS `event_reporter.rb:432/434` | 9 / 58% | 12.1 | `{ name: }` and `subscribers` per `notify`, before the "does anyone consume this" check (recent `81d95a3f74`). Called from structured event subscribers, which open #58957 skips when no log subscriber would log. Excluded as overlapping. |
| 49 | AR `query_methods.rb:1963` `transform_keys` | 9 / 86% | 11.9 | Normalized `where` hash keys. Required. |
| 59 | AM `attribute_set.rb:225` `keys` unions | 9 / 42% | 10.0 | Open #59141 rewrites `LazyAttributeSet#keys` (and open #58002 targets it too). Excluded. |
| **83** | AR `merger.rb:66` `public_send(:"#{name}!", *value)` | 8 / 76% | 8.2 | **Candidate 15** for the String half (4.1); the Array half is the bang method's rest parameter. |
| 87 | AV `capture_helper.rb:59` `yield(*, **)` | 7 / 39% | 6.9 | An Array per `capture` in the interpreter. Not reproduced by a standalone script; lead for the VM, not a Rails change. |
| 136 | AR `querying.rb:98` `column_types.reject` | 9 / 78% | 4.1 | Census-4 lead. **Covered by open #59141**, which deletes this reject. |
| **157** | AR `scoping/named.rb:77` `return []` | 9 / 64% | 3.4 | **Candidate 14.** |
| 164, 219 | AP `request_forgery_protection.rb:582/584` Vary | 9 / 56% | 2.9, 1.7 | Covered by open #59500 (czj, vary only for requests that check Sec-Fetch-Site). |
| 168, 186, 209, 312 | AR `relation.rb:1541–1554, 1310` `references_eager_loaded_tables?`, `joined_includes_values` | 7 / 26% | 1–2.8 | Census-4 lead `build_joins([])`. **Covered by open #59377** (kehra), which returns early without building joins and returns a frozen Array from `joined_includes_values`. |

The full rankings are in the receipts (`rank-base2-interpreter.tsv`, `rank-base2-yjit.tsv`).

## Candidates

All four are exact: same SQL, results, relation values and extended modules; live method dispatch kept; no memo,
boot certificate or cache of mutable state. Each is one commit on
[`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0) by Thomas Klemm
`<github@tklemm.eu>` (author and committer), with no trailers, pushed to the fork. No PR is open.

### Per-call micro

[`census_5_allocs.rb`](../../bench/upstream/census_5_allocs.rb), SQLite in memory, objects per warmed call,
interpreter / YJIT. Bold cells changed.

| Pattern | Clean main | 12 extending | 13 constraints | 14 extensions | 15 bang names |
| --- | ---: | ---: | ---: | ---: | ---: |
| `post.author` (belongs_to reader) | 223 / 227 | **221 / 225** | **220 / 224** | 223 / 227 | **222 / 226** |
| `author.posts.to_a` (has_many reader) | 239 / 243 | **237 / 241** | **236 / 240** | **238 / 242** | 239 / 243 |
| `author.published_posts.to_a` (scoped has_many) | 302 / 308 | **299 / 305** | **299 / 305** | **301 / 307** | 302 / 308 |
| `author.comments.to_a` (has_many :through) | 292 / 298 | **289 / 295** | **286 / 292** | **291 / 297** | **291 / 297** |
| `author.posts.where(published: true).to_a` | 113 / 117 | **111 / 115** | 113 / 117 | 113 / 117 | 113 / 117 |
| `author.posts.order(:id).first` | 119 / 123 | **117 / 121** | 119 / 123 | 119 / 123 | 119 / 123 |
| `author.posts.count` | 100 / 115 | **98 / 113** | 100 / 115 | 100 / 115 | 100 / 115 |
| `author.posts.exists?` | 96 / 98 | **94 / 96** | 96 / 98 | 96 / 98 | 96 / 98 |
| `post.comments.size` (unloaded) | 249 / 254 | **247 / 252** | **246 / 251** | **248 / 253** | 249 / 254 |
| `Post.where(author_id: 1).merge(Post.published).to_a` | 123 / 128 | **122 / 127** | 123 / 128 | 123 / 128 | 123 / 128 |
| `Post.published.merge(Post.recent).to_a` | 178 / 182 | **177 / 181** | 178 / 182 | 178 / 182 | **177 / 181** |
| `Post.where(title: 't1').to_a` (no merge, control) | 107 / 110 | 107 / 110 | 107 / 110 | 107 / 110 | 107 / 110 |
| `Author.includes(:posts).to_a` (control) | 406 / 413 | 406 / 413 | 406 / 413 | 406 / 413 | 406 / 413 |

With open #59212 applied, the plain readers (`post.author`, `author.posts.to_a`, `author.comments.to_a`) no longer
build an association scope, so 13 and 15 stop saving there; 12 keeps every row except those readers, 13 keeps the
scoped reader and `size`, and 14 keeps every proxy row.

### Request deltas

Median per workload (patched − `base2`), per app, interpreter / YJIT. A/A is `base2 − base`.

| App | A/A | 12 extending | 13 constraints | 15 bang names | 14 extensions |
| --- | ---: | ---: | ---: | ---: | ---: |
| Blog | −0.3 / +0.0 | +0.0 / +0.0 | +0.6 / +0.0 | +0.3 / +0.1 | +0.0 / +0.0 |
| Campfire | +0.0 / +0.0 | −5.8 / −4.3 | −6.8 / −6.0 | −1.0 / −1.1 | −1.0 / −1.3 |
| CodeTriage (PG) | +0.7 / +0.0 | −4.3 / −2.4 | −7.3 / −6.0 | −1.6 / −1.0 | −4.3 / −1.5 |
| Fizzy (SQLite) | +0.0 / +0.0 | −27.0 / −19.0 | −39.0 / −26.8 | −7.0 / −9.0 | −5.0 / −3.0 |
| Fizzy (MySQL) | +0.0 / +0.0 | −19.0 / −27.0 | −39.0 / −27.0 | −8.0 / −4.0 | −4.0 / −1.1 |
| Lobsters | +0.0 / +0.0 | −6.0 / −10.1 | −9.0 / −10.9 | −2.1 / −3.8 | +0.0 / −4.3 |
| PingCRM (PG) | +1.7 / −1.2 | −1.5 / −2.7 | −4.2 / −2.7 | −2.6 / −0.8 | −1.0 / +0.7 |
| React starter kit | +1.4 / +1.0 | −2.8 / −2.5 | −3.5 / −2.3 | −2.2 / +0.0 | −1.6 / +1.0 |
| Redprints CFP | +0.1 / +0.0 | −1.5 / −3.7 | −4.3 / −1.5 | −0.7 / −1.1 | −0.7 / +0.3 |
| Writebook | +0.0 / +0.4 | −10.8 / −12.8 | −15.0 / −14.8 | −3.4 / −2.3 | −1.7 / −2.3 |
| **All 97 workloads** | **+0.0 / +0.0** | **−5.8 / −6.0** | **−7.3 / −6.7** | **−3.0 / −2.0** | **−1.6 / −1.3** |
| Moved ≤ −1 / ≥ +1 | 17 / 24 · 18 / 23 | 76 / 6 · 74 / 8 | 74 / 8 · 72 / 7 | 66 / 11 · 62 / 8 | 58 / 15 · 55 / 18 |
| On top of #59212: median, moved ≤ −1 | — | −3.6 / −3.0, 63 / 62 | −3.8 / −3.3, 63 / 62 | −1.0 / +0.0, 51 / 34 | −1.8 / −1.1, 61 / 55 |

All four together on top of #59212: median −10.7 / −8.9, 72 / 68 of 97 moved. Largest page savings (interpreter):
12 Fizzy board −111, Writebook leaf −30, Lobsters tag page −19; 13 Fizzy board −95, Writebook leaf −22, Lobsters story
−22. The Blog's only association reads are the article page and comment POST, so its median stays at 0.

### Why each one is exact, and its boundaries

12. **`extending!` only when there are extensions.** `Merger#merge_multi_values` ended with
    `relation.extending!(*other.extensions)`. `extending!(*modules, &block)` returns `self` as its first statement when
    `modules` is empty and there is no block, but the splat still built its rest Array. The call is now skipped when
    `other.extensions` (`extending_values`, `FROZEN_EMPTY_ARRAY` by default) is empty, which is exactly when it
    returned immediately; nothing is assigned to `@values` on that path, so relation state is the same.
    **Boundary:** an override of the `:nodoc:` `extending!` in a `Relation` subclass would no longer be called with no
    arguments. Open #59416 (kehra) edits the lines just above in the same method (`reorder`/`order`); a rebase is
    trivial.
13. **`constraints` of a direct association is its `scopes`.** `AbstractReflection#constraints` is
    `chain.flat_map(&:scopes)`. For `AssociationReflection` (every `belongs_to`, `has_one`, `has_many` that is not
    `:through`), `chain` is `collect_join_chain`, which returns `[self]`; flattening it builds `[self]` and a copy of
    `scopes`, which is itself a new Array (`scope ? [scope] : []`). `AssociationReflection#constraints` now returns
    `scopes`. `ThroughReflection` and `PolymorphicReflection` keep their own `constraints`; `RuntimeReflection`
    delegates to the wrapped reflection and gets the shortcut. The caller only iterates the Array.
    **Boundary:** a subclass of the `:nodoc:` `AssociationReflection` that overrides `collect_join_chain` or `chain`
    would no longer affect `constraints`. None exists in Rails.
14. **Shared empty `default_extensions`.** `default_extensions` returned `[]` when the model has no default scope (and
    when building it yields nothing). Its only caller, `Association#extensions`, computes
    `klass.default_extensions | reflection.extensions`, which returns a new Array regardless. It now returns
    `Relation::FROZEN_EMPTY_ARRAY`. **Boundary:** a third-party caller of the `:nodoc:` method that mutates the result
    would raise `FrozenError`. The `Method` that `has_default_scope?` allocates on the same path stays (rank 43).
15. **Bang method names built once.** `Merger#merge` looped over `NORMAL_VALUES` and sent `:"#{name}!"`, building a
    String for each value set on the merged relation. `NORMAL_VALUE_BANG_METHODS = NORMAL_VALUES.index_with { … }`
    holds the same Symbols, in the same order; `public_send` and the `blank?` test are unchanged. **Boundary:** none
    observable; `NORMAL_VALUES` stays. Open #59416 adds `:default_order` to the exclusion list above it; the new
    constant derives from it. Most of the effect comes from singular association readers merging `limit(1)`, the path
    #59212 removes; hold until #59212 is decided.

Census 4's untried `Merger#initialize` lead: no caller mutates `Merger#values`. `Merger` is `:nodoc:`, built only in
`SpawnMethods#merge!` and `HashMerger#merge`, never returned, and `merge` only reads `values[name]`. Removing the copy
still needs a way to read the other relation's `@values` without `Relation#values`' dup: a new `:nodoc:` reader on
`Relation` or an `instance_variable_get`. Reading through the generated `*_value(s)` readers would replace one Hash
dup with about fifteen sends per merge. Not submitted; it is the largest remaining merge allocation (one Hash per
merge, 15 objects per operation across the apps) if maintainers want a reader.

### Behavior controls and suites

[`census_5_controls.rb`](../../bench/upstream/census_5_controls.rb) records SQL, relation values (including
`extending`) and singleton-class extensions plus results for 26 relations: merges plain, with `extending` modules and
blocks, into an extended relation, with `limit`/`order`, `distinct`/`readonly`/`annotate`/`offset`,
`strict_loading`/`group`/`having`, `unscope`, `references`/`eager_load`, `none`, Hash and Proc merges, a
cross-model merge and a self `merge!`; association scopes for plain, scoped, `extending`-scoped, block-extended,
through, scoped-through, limited and `source_type` polymorphic-through associations, `belongs_to`, a `default_scope`
model with `extending`, and STI; plus calls into the extension modules and `exists?`/`count`/`size`. Output is
identical between clean main and every branch, interpreter and YJIT.

Local suites, Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, `SEED=41231`, serial:

* **Active Record SQLite, full:** clean main and all four branches: 10,247 runs, 0 failures, 0 errors, 52 skips (the
  census-4 count). Branch 15 ran again on its final head after a RuboCop amend (`to_h` → `index_with`).
* **Active Record PostgreSQL 15, full:** clean main and all four branches: 11,166 runs, 0 failures, 0 errors, 31 skips (the census-4 count).
* **RuboCop:** each branch's changed file, no offenses.
* The first clean-main SQLite run had 4 errors in `sqlite_rake_test.rb` because the orb lacked the `sqlite3` CLI;
  after installing it, 0.

### PR description drafts (not published)

**12 — Skip `extending!` in `Relation#merge` when there are no extensions**

> Every `Relation#merge` (association reads and association relations like `author.posts.where(...)`, `.count` and
> `.exists?`, and `merge(Post.published)`) ended with `relation.extending!(*other.extensions)`. Relations almost never
> have extensions, and `extending!` returns right away without any, but the splat still allocates the rest Array it
> receives. Skip the call when there are no extensions.
>
> One Array fewer per merge (`author.posts.count` 100 → 98 objects, `Post.where(...).merge(Post.published).to_a`
> 123 → 122; same under YJIT). Across nine apps on Rails main, 76 of 97 request, job and mailer workloads allocate
> fewer objects (median −6). Allocation counts only; no timing claim.

**13 — Use the scopes as constraints of a direct association reflection**

> Building an association scope asks each reflection in the chain for its `constraints`, which is
> `chain.flat_map(&:scopes)`. For a `belongs_to`, `has_one` or `has_many` that doesn't go through another association
> the chain is just `[self]`, so this builds two Arrays to copy `scopes`. Return `scopes` for those reflections;
> through and polymorphic reflections keep their own `constraints`.
>
> Two Arrays fewer per direct reflection (`post.comments.size` 249 → 246, a scoped `has_many` 302 → 299,
> `has_many :through` 292 → 286). Across nine apps, 74 of 97 workloads allocate fewer objects (median −7). No timing
> claim.

**14 — Return a frozen empty Array from `default_extensions`**

> Every collection association proxy (`author.posts`) asks `Association#extensions`, which unions
> `klass.default_extensions` with the reflection's extensions. For a model without a default scope,
> `default_extensions` returned a new empty Array that only feeds that union. Return a shared frozen one.
>
> One Array fewer per association proxy (`author.posts.to_a` 239 → 238). Across nine apps, 58 of 97 workloads
> allocate fewer objects (median −1.6). No timing claim.

**15 — Don't build bang method names when merging relation values**

> `Relation#merge` sends `limit!`, `offset!`, `distinct!`, `readonly!` and so on for each value set on the merged
> relation, and built each method name with `:"#{name}!"`, a new String per value. Singular association readers merge
> `limit(1)` every time, and scopes that set these values merge them too. Build the names once, next to
> `NORMAL_VALUES`.
>
> One String fewer per merged value (`post.author` 223 → 222, `Post.published.merge(Post.recent)` 178 → 177).
> Across nine apps, 66 of 97 workloads allocate fewer objects (median −3). No timing claim.

## Rejected and excluded, with reasons

* **`index_with` (rank 2):** out of scope; another thread is revisiting it.
* **Census-4 leads now covered by open PRs:** `_load_from_sql`'s `column_types.reject` (open #59141 deletes it);
  `build_joins([])` in `references_eager_loaded_tables?` and `joined_includes_values` (open #59377 returns early in
  both). `LazyAttributeSet#keys` unions (open #59141; also #58002). The Vary header split (open #59500).
  `EventReporter#notify` and fanout bookkeeping for structured events (open #58957).
* **`Merger#initialize` `other.values` copy:** safe (no caller mutates `Merger#values`) but needs a new reader to
  reach `@values`; recorded above as a lead with that tradeoff.
* **`get_chain`'s `reflection.chain.zip(routes)`:** replacing `zip` with an indexed loop saved nothing measurable in
  the micro (0 objects in every pattern) and ±1 in standalone tests. Dropped.
* **`unscope!(*item.table_name_qualified_unscope_values)` with no values:** skipping it is not exact. `unscope!`
  with no arguments still assigns `unscope_values |= []`, which adds an `:unscope` key to `@values`, and preloader
  grouping compares `values_for_queries`.
* **`method(:default_scope).owner` (ranks 43, 67):** no allocation-free way to ask Ruby for a method's owner; a
  definition hook would be a cache.
* **Around-callback template splat (`callbacks.rb:131`, 2.8/op):** removable only by restructuring the template
  destructuring with `shift`; small and obscure. Not attempted.
* **`asset_url_helper.rb:221` `"#{source}#{tail}"`:** returning `source` when there is no tail can hand the caller's
  own String back (a leading-slash path with no host), which changes ownership. Rejected.
* **`where(*args)` → `where!(opts, *rest)` rest Array (rank 96):** needs a signature change on a method gems call.
  Rejected, as in census 4.
* **Single-app sites:** none reached the top 200 that are Rails code; app and gem sites are not Rails PRs.

## Leads for ruby/ruby (not Rails PRs)

YJIT-only allocations on Rails paths are the census-4 set (`core.rb:481` `Relation.create(self)` 0 → 21,997 objects
summed over all workloads; Arel collectors `abstract_adapter.rb:1426/1432` 3,973 → 7,944; `where!(*args)`
6,192 → 8,821), already explained by the held YJIT/ZJIT empty-anonymous-rest branch
(`thomasklemm/ruby:jit-anon-rest-empty-frozen`). Two new shapes,
[`census_5_yjit_probe.rb`](../../bench/upstream/census_5_yjit_probe.rb) (no Rails), objects per call after 2,000
warmups, Ruby 4.0.7:

| Shape | Interpreter | YJIT | Rails sites |
| --- | ---: | ---: | --- |
| `"t#{i}_r#{j}"` with Integers | 1 | 3 | `join_dependency.rb:188` column aliases (190 → 540 summed) |
| `"#{klass} Update"` with a Class | 1 | 2 | `persistence.rb:236/229` update/insert names (860 → 1,643; 245 → 476) |
| `"#{s} Update"` with a String (control) | 1 | 1 | |

So YJIT allocates an intermediate String for each Integer or Module interpolated, which the interpreter avoids. That
belongs in a ruby/ruby report with this script. `capture_helper.rb:59` (`yield(*, **)`, an Array per `capture` in the
interpreter on 7 apps) did not reproduce standalone and stays unexplained.

## Limits

* Local suites only; no hosted CI for the Rails changes. The MySQL suite was not run (no adapter code changed); Fizzy
  on MySQL 8.4 is the only MySQL coverage.
* Request numbers are allocation counts from one process per app and mode; single write workloads move by tens of
  objects in A/A, so the candidates are judged by the distribution, not single cells.
* The Blog's lock differs from census 4's (regenerated locally), so cross-census comparisons for the Blog are
  approximate. The −40 median between pins includes every change on main between `b5be036` and `5810776`, not only
  the merged census PRs.
* Receipts: [data/rails-main-census-5/receipts.tar.gz](data/rails-main-census-5/receipts.tar.gz) holds the ranking
  TSVs, every compare output (`DETAIL=1`), the per-app table, the micro and control outputs, suite summaries, and each
  run's JSON trimmed to the top 200 sites per workload. Full receipts stay under `.lowrail/private/rails-main-census-5/`.
