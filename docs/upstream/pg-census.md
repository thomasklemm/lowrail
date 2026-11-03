# PostgreSQL census: seven more PG apps on Rails main

Lowrail bet L4. Censuses 3 to 5 had two PostgreSQL apps (CodeTriage and PingCRM), so PG-adapter costs were priced
on thin evidence. This round adds seven open-source Rails apps that run on PostgreSQL in production. It runs all nine
on canonical Rails main through [`script/census`](census.md), under the interpreter and YJIT with an A/A twin, and adds
two `prepared_statements: false` configurations, as behind PgBouncer. Sites are ranked by breadth across the PG apps,
and PG-adapter sites are separated from general ones.

**Result.** The PG type-map dispatch that census 3b priced at about 25 objects per request on CodeTriage and rejected
is the broadest and largest PG-adapter site: **9 of 9 apps, 99% of workloads, mean 257 objects per request**. It
costs one `[fmod, sql_type]` Array per column of every query. The reason it was rejected does not hold: the Array
is the cache key, but the key can be a reused frozen Array instead of a new one, with no cache restructure.

**Two exact candidates**, each one commit on its own fork branch on canonical main `5810776eec`, both in casting a
PostgreSQL result. No open PR covers either.

| # | Branch | Per call | Workloads moved (of 124; A/A 22 / 27) | Median per workload |
| --- | --- | ---: | ---: | ---: |
| 16 | [`thomasklemm/pg-result-type-args`](https://github.com/thomasklemm/rails/tree/thomasklemm/pg-result-type-args) | −1 Array per result column | 120 / 122 | −171 / −211 (−2.4% / −2.5%) |
| 17 | [`thomasklemm/pg-cast-result-scratch`](https://github.com/thomasklemm/rails/tree/thomasklemm/pg-cast-result-scratch) | −2 Arrays per query | 121 / 121 | −22.5 / −23.8 |

Interpreter / YJIT. Both save the same with prepared statements on or off. Seven apps were added (Docuseal,
Mastodon, Lago, Discourse, Loomio, Sure, and CASA, deferred since census 4). Wikino stays deferred, and Forem failed
on Ruby 4. Booting the apps on main also turned up two Rails-main breaks worth reporting:
[rails#58427's `find_by_sql` binds on PostgreSQL](#rejected-covered-elsewhere-and-leads), and
`Arel::Table.new(name)` changing to a keyword with no deprecation.

## Pins and method

* **Rails:** canonical `rails/rails` main
  [`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0) (merge of #59544),
  checked with `git ls-remote` on 2026-11-03; main had not moved since census 5. The fork branches are based on it.
* **Ruby 4.0.7**, interpreter and `--yjit`, production environment, PostgreSQL 15 on the local socket.
* **Command:** [`script/census`](../../script/census) (`setup`, `run --aa`, `compare`), the harness
  [`bench/upstream/census/harness.rb`](../../bench/upstream/census/harness.rb) with census 4's request client and
  measurement (50 warmups, three GC-enabled windows of 20, 10 traced operations), and the PG workloads in
  [`pg_workloads.rb`](../../bench/upstream/census/pg_workloads.rb). The PG view of a label (PG-only breadth ranking,
  PG families, pg-gem lines, type-map price per app, prepared vs unprepared) is
  [`pg_sites.rb`](../../bench/upstream/census/pg_sites.rb): `ruby bench/upstream/census/pg_sites.rb OUT LABEL MODE`.
* **Configurations (11):** docuseal, mastodon, lago, discourse, loomio, sure, casa, codetriage, pingcrm, plus
  `mastodon-nops` and `lago-nops`, which run the same copies with `prepared_statements: false` (the harness checks the
  connection really has it off). 100 PG workloads in the nine apps, 124 with the two variants.
* **A/A:** `base` and `base2`, both unpatched: median +0.0 in both modes; 22 / 27 workloads move ≤ −1 and 25 / 22
  move ≥ +1 (interpreter / YJIT, `base2 − base`). Candidates are compared with `base2`. Moved workloads beyond the
  A/A are cumulative state: Discourse's `GET topic.json` and Loomio's `POST comment` grow with each run's replies,
  and Mastodon's Redis cache makes `mastodon-nops` query counts depend on run order (`GET profile` 6 vs 17 queries).
* **Allocation counts only.** No timing is inferred.
* **Receipts:** [data/pg-census/receipts.tar.gz](data/pg-census/receipts.tar.gz) holds every run JSON and log for
  `base`, `base2`, `typeargs3` (candidate 16 at `408e6a3e29`) and `scratch`, plus the full `rank-base2-interpreter.tsv`.

## Apps

Seven apps added, each pinned in [`script/corpus`](../../script/corpus) to its main/master of 2026-11-02, with an
overlay in [fixtures/corpus/pg-census](../../fixtures/corpus/pg-census) and a row in `script/census`
([census.md](census.md#services-and-apps)). Every overlay moves the app to Ruby 4.0.7 and Rails main. The edits beyond
that are listed per app; each is a Rails-main incompatibility, not a measurement change.

| App | Pin | Workloads (100 + 24 nops) | Seeds | Rails-main edits in the overlay |
| --- | --- | --- | --- | --- |
| [Docuseal](https://github.com/docusealco/docuseal) (document signing) | `6c416dd` | 13: 5 HTML (dashboards, template, submission, signing form), 5 JSON API (templates, submissions, PUT template, POST submission), 1 mailer, 2 jobs | seed script through its services | `Arel::Table.new(:webhook_urls)` → `name:` (b1650993b0); `ActiveStorage::LogSubscriber.detach_from` guarded (log subscribers moved to the event reporter) |
| [Mastodon](https://github.com/mastodon/mastodon) | `5ccbf0e` | 14: 2 HTML, 8 JSON (OAuth REST API, WebFinger), POST status, favourite, 4 Sidekiq workers | its `db/seeds.rb` plus a seed script | RemoteIp extension: `filter_proxies(...).first` → `first_non_proxy` (752cc3915d) |
| [Lago](https://github.com/getlago/lago-api) (usage billing, API-only) | `b0007bf` | 10: 7 JSON reads, customer upsert, event ingest, `Events::PostProcessJob` | its seeds with `srand(42)` | clickhouse-activerecord only registers its adapter (`require: [...]`: main autoloads Arel, d1598cc763, and the gem's extensions mutate the now-frozen `VALID_UNSCOPING_VALUES`); `kaminari-core` explicit; Sidekiq's own Active Job adapter (main removed Rails', 10c24f2481); JSON log subscriber `detach_from` guarded; a `method` attribute on `RecurringTransactionRule` shadows `owner.method` (7249a66350), worked around in the model |
| [Discourse](https://github.com/discourse/discourse) | `0f52471` | 14: 3 crawler HTML, 5 JSON reads, POST reply (API key), 5 Sidekiq jobs | seed script (users, categories, topics, posts) | Rails component gems pinned to main; `Arel::Table.new(table_name)` → `name:` in json_api_kit. `LOAD_PLUGINS=0`: the bundled chat plugin's composite `foreign_key` fails on main's `Key::Mapping` ("Key mappings must have the same number of columns") |
| [Loomio](https://github.com/loomio/loomio) (group decisions) | `407d4a8` | 15: 3 HTML, 5 JSON (v1 API the Vue client uses, user API), POST comment, 6 jobs | seed script | none (npm 11.16 for the Vue build) |
| [Sure](https://github.com/we-promise/sure) (personal finance; maintained fork of the archived Maybe) | `8d0d84d` | 9: 5 HTML (dashboard, accounts, transactions, budget), 2 JSON API reads, Turbo Stream PATCH, POST API transaction | `demo_data:default` with `SEED=42` | lookbook ≥ 2.3.15 (marcel 2); two `find_by_sql` calls changed for rails#58427, see [Leads](#rejected-covered-elsewhere-and-leads) |
| [CASA](https://github.com/rubyforgood/casa) (deferred since census 4) | `b584d2e` | 10: 7 HTML (Pundit-scoped), JSON API sign-in, case PATCH as form and JSON | its seeds with `DB_SEEDS_RANDOM_SEED=42` | caxlsx from master `e92ca3e` (allows marcel 2; unreleased); flipper from main `a467311` (flipper#1003 takes `Arel::Table` `name:`; unreleased); production `database.yml` user and Active Storage service from env |
| CodeTriage, PingCRM | census 4 | 7, 8 | census 4 | census 4's overlays |

**Deferred or failed:**

* **Wikino** stays deferred: it has no seeds or fixtures (factories only), and the repository is mid-migration to a
  Go service, so a seed script would model an app that is going away.
* **Forem:** `ddtrace ~> 1.16` does not install on Ruby ≥ 3.4, and Forem pins it. Not pursued further.
* **Chatwoot** (Rails 7.2 and Ruby 3.4.4 pins), **Spree/Solidus** (a sandbox generator, not an app) were not
  attempted; seven apps were enough for breadth. **Maybe** is archived; Sure is its maintained fork.

Services: PostgreSQL 15 with pgvector 0.8.1 (Discourse) and pg_partman (Lago), Redis, memcached (CodeTriage), libvips
and pdfium (Docuseal; the bblanchon chromium/8125 build behind a stub for Docuseal's nine extra symbols).


## Ranking

`pg_sites.rb` on `base2`, interpreter, nine PG apps and 100 workloads (the two `-nops` runs are excluded from breadth,
as `fizzy-mysql` was in census 4). Lines are tiered by apps reached (≥ 0.5 objects per operation), then ordered by
mean objects per operation over every workload. YJIT agrees to within 1% on every line below.

### PG-adapter lines

| Rank | Site | Apps / share | Objects/op | Family | Disposition |
| ---: | --- | --- | ---: | --- | --- |
| 1 | `postgresql/database_statements.rb:258` `ActiveRecord::Result.new(fields, result.values, …)` | 9 / 99% | 309 | result building | Row values decoded by pg (String, Time, BigDecimal) plus the Result. **Required.** |
| 2 | `postgresql_adapter.rb:1047` `type_map.fetch(oid, fmod, sql_type)` | 9 / 99% | 257 | type map | **Candidate 16.** One `[fmod, sql_type]` rest Array per result column per query. |
| 3 | `postgresql/database_statements.rb:228` `result.fields` | 9 / 99% | 126 | result building | The field Array is required. The field-name Strings (one per column, 0 on pg 1.7) are a pg-gem cost: pg 1.7.0 interns them (ruby-pg#750). Apps on pg 1.5.9/1.6.3 (Lago, Sure, CASA, Docuseal, CodeTriage) pay it. **Upgrade lead, not a Rails PR.** |
| 4–6 | `postgresql/database_statements.rb:231/232/233` `types`, `field_types`, `missing_oids` | 9 / 99% | 17 each | result building | `types` is the Result's column types. **Candidate 17** removes `field_types` and `missing_oids`. |
| 7 | `postgresql_adapter.rb:1124` `sql_key` | 8 / 85% | 9.6 | statements | `"#{schema_search_path}-#{sql}"`, the statement-pool key, per prepared query (0 without prepared statements). A key is needed; a two-level pool keyed by path would be a cache change. Lead only. |
| 12 | `postgresql/quoting.rb:129` `connection.escape(s)` | 5 / 26% | 6.0 | quoting | The escaped literal. Required. |
| 13, 14 | `postgresql/database_statements.rb:189/211` `send_query_prepared` / `send_query_params` | 5–6 / 31–43% | 2–3 | `exec_params` | Binds passed to libpq. Required. |
| 15–17 | `postgresql/oid/array.rb:28/30/112` | 2–4 / 7–17% | 0.3–1.2 | OID decoding | Array column decoding (Mastodon, Discourse, Docuseal, Sure). Required output. |

**Family totals** (mean objects per operation over all PG workloads): result building and statements 492, type map
257, other adapter lines 10, quoting 6, OID decoding 1.9, Arel's PG visitor 0. **pg gem:** `PG::Result` per query (19
objects per operation across versions); Ruby-level `TextDecoder::Date` (4 objects per date, Sure only, through
`decode_dates`). ruby-pg master has a C date decoder (unreleased), so that one also needs only an upgrade.

### General lines

The general ranking matches census 5's (mostly SQLite apps): the top lines are the same, in nearly the same
order, and keep their census-5 dispositions.

| Rank | Site | Apps / share | Objects/op | Disposition |
| ---: | --- | --- | ---: | --- |
| 1 | AS `enumerable.rb:87` `index_with` | 9 / 98% | 462 | Open #59555/#59557 (Ruby 4.1 path). Out of scope here. |
| 2, 6 | AS `output_safety.rb:245/73` SafeBuffers | 8 / 47% | 160, 86 | Output. Required. |
| 3 | Arel `table.rb:91` Attribute | 9 / 99% | 153 | Per-query AST. Required. |
| 4 | AM `attribute.rb:10` `FromDatabase` | 9 / 69% | 126 | Attribute objects. Required; overlaps #59141. |
| 5 | AR `where_clause.rb:32` | 9 / 89% | 105 | The merged clause. Required. |
| 7–14 | relation, delegation, `type/string.rb:40`, `attribute_set/builder.rb:20`, `relation.rb:80/101`, `associations.rb:62`, `predicate_builder.rb:146` | 9 / 92–99% | 66–81 | As census 5: required or overlapping #59141. |
| 11 | AM `attribute_set.rb:225` `LazyAttributeSet#keys` | 9 / 55% | 69 | Mastodon 294, Sure 158 objects per op. Open #58002 (ikraamg) rewrites exactly this method; #59141 replaces it. **Covered by open PRs.** |
| 15 | AV `tag_helper.rb:1545` | 8 / 35% | 60 | Output. Open #57999. |
| 18–20 | AS `notifications/fanout.rb:378–381` | 9 / 95% | 40–44 | As census 5 (open #58957). |

### `prepared_statements: false`

`mastodon-nops` and `lago-nops` against the same copies with prepared statements on. Median per workload: Mastodon −37
objects (interpreter) / −38 (YJIT), Lago −19 / −19. What moves:

* **Gone without prepared statements:** the bind collector (`abstract_adapter.rb:1425–1427`, `arel/collectors/bind.rb:9`,
  `composite.rb:39`, about 14–18 per op), `query_cache.rb:302` and `abstract/quoting.rb:219` (type-cast binds,
  16–19), `sql_key` (11 in Lago), and in Mastodon `attribute.rb:18` (−61).
* **Added:** `SubstituteBinds` (`abstract_adapter.rb:1430/1432`, `substitute_binds.rb:24`) and the quoted literals:
  `abstract/quoting.rb:86` `value.to_s` for Numeric (+96 in Mastodon, whose ids are 18-digit snowflakes), and in Lago
  `quoting.rb:80` and `postgresql/quoting.rb:129` (+28, +30) for String literals, plus `abstract_adapter.rb:1270`.
* **Unchanged:** the type map (`postgresql_adapter.rb:1047`) and result building. Both candidates save the same
  amount with prepared statements off (see below). Nothing found was specific to the unprepared path and worth a PR:
  the added objects are the SQL literals themselves.

## Candidates

Numbering continues from census 5 (12–15). Each candidate is one commit on its own fork branch, based on
`5810776eec`. Both are in casting a PostgreSQL result, so every query on every PG app reaches them.

| # | Branch | Commit | Pattern | Per call | Workloads moved (A/A 22 / 27 of 124) | Median per workload | Median % |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: |
| 16 | [`thomasklemm/pg-result-type-args`](https://github.com/thomasklemm/rails/tree/thomasklemm/pg-result-type-args) | [`408e6a3e29`](https://github.com/thomasklemm/rails/commit/408e6a3e29d6a7ebc212c352eeac094c053598d6) | every query result on PostgreSQL: each column's type lookup | −1 per result column (10-column `cast_result` 27 → 17) | 120 / 122 | −171 / −211 | −2.4% / −2.5% |
| 17 | [`thomasklemm/pg-cast-result-scratch`](https://github.com/thomasklemm/rails/tree/thomasklemm/pg-cast-result-scratch) | [`0afbc4b871`](https://github.com/thomasklemm/rails/commit/0afbc4b871488eb35c0914daf111629f64c7fa21) | every query result on PostgreSQL | −2 per query (27 → 25) | 121 / 121 | −22.5 / −23.8 | −0.4% / −0.4% |

Interpreter / YJIT. The two branches touch different methods, so their savings should add up (not measured together).

**Per app** (median objects per workload, interpreter / YJIT):

| App | Workloads | 16: type-map keys | 17: scratch Arrays |
| --- | ---: | ---: | ---: |
| Sure | 9 | −402 / −397 | −51 / −80 |
| Mastodon (and `-nops`) | 14 | −279 / −279 | −30 / −30 |
| Lago (and `-nops`) | 10 | −257 / −257 | −28 / −27 |
| Loomio | 15 | −164 / −164 | −16 / −16 |
| CASA | 10 | −147 / −148 | −30 / −25 |
| Discourse | 14 | −133 / −293 | −18 / −18 |
| Docuseal | 13 | −119 / −117 | −21 / −19 |
| CodeTriage | 7 | −51 / −51 | −2.9 / −2.8 |
| PingCRM | 8 | −28 / −29 | −4.6 / −6.7 |

Every workload of every app moves, except 2–3 that grow for reasons outside Rails. Discourse's `GET topic.json`
and `GET latest.json` grow in rack-mini-profiler lines (which Discourse samples in production), while their Rails
lines fall (8,944 → 8,353 and 8,646 → 8,356 traced). Loomio's `POST comment` grows with each run's comments
(base 22.2k → base2 22.4k → scratch 22.8k). Sure's `GET accounts` grows in non-Rails lines while its Rails lines
fall by 50. Prepared statements on or off make no difference to either candidate.

### Census 3b's rejection, re-priced

Census 3b priced `postgresql_adapter.rb:1047` at 25.3 objects per request on CodeTriage, ≈0.8% of request objects.
It rejected the site because the `[fmod, sql_type]` Array is the `Concurrent::Map` key, so removing it seemed to need
a cache restructure. Across nine PG apps the price is ten times higher: a median of 31–399 objects per workload per app
(CodeTriage 52, PingCRM 31, Docuseal 113, Loomio 170, CASA 272, Mastodon 284, Lago 289, Discourse 293, Sure 399).
Candidate 16 removes 0.7–3.6% of each app's objects per workload (median).

The key has to be an equal Array, but it doesn't have to be a new one. Result columns always look up with
`sql_type = ""`, so their key is `[fmod, ""]`. A frozen `[fmod, ""]` per type modifier (a handful per app: −1, varchar
lengths, numeric precisions) is the same key the cache already stores. `HashLookupTypeMap#fetch_result_type` keeps
it on the type map next to the cached types it indexes, and only once a type was cached under it: `register_type` and
`clear` (so `reload_type_map`) drop it with them, a discarded type map takes it along, and a lookup whose block
raises retains nothing. Nothing about the cache changes: key encoding, `register_type` and `alias_type` blocks
(which still receive `*args`), and lookups with a SQL type (schema columns, which still use `fetch`).

Review history: the first version (`e25d80d6af`) kept the keys in a process-global map that survived
`reload_type_map` and grew with every distinct modifier. The second (`895b983e73`) moved them onto the type map but
stored a key before its lookup succeeded, so failing lookups grew the key map until `clear`. `408e6a3e29` fixes both;
census numbers are identical across the three (median +0.0 between them).

### Why each one is exact

* **16:** the cache key passed to `fetch_or_store` is equal (`[fmod, ""].eql?([fmod, ""])`, same `hash`).
  `Concurrent::Map` looks keys up by `hash`/`eql?`, so a reused frozen key finds the same entry; on a miss it stores
  that frozen Array, which nothing mutates (before, it stored the caller's fresh rest Array). `perform_fetch`
  receives the same splatted arguments, so registered blocks see the same values (a block that mutates its rest
  args mutates a copy). The key table holds at most one key per modifier with a cached type, and is cleared with
  that cache; the type cache itself already grows the same way on main. A `clear` racing an in-flight lookup can
  leave that one lookup's key behind, harmlessly (it is equal to the key it replaces). Third-party callers of
  `fetch`/`lookup` are unchanged. Tests cover a hit through both paths, invalidation by `register_type`, `clear` and
  `reload_type_map`, the keys belonging to the type map, failed lookups retaining nothing, and blocks mutating
  their arguments.
* **17:** `PG::Result#ftype` returns an Integer without allocating, so reading it again in each of the three passes
  replaces `field_types`. `missing_oids` is built only when an OID is missing, which is the only time it was read.
  The passes, their order, `load_additional_types` and `register_unknown_oid_type` calls are unchanged.

### Behavior controls and suites

* [`pg_types_control.rb`](../../bench/upstream/census/pg_types_control.rb) prints the resolved type (class, type,
  precision, scale, limit, subtype) of 58 result columns, twice (cold and cached), and of the same 58 as schema columns
  of a table. The columns cover int, float, numeric with and without scale, money, text, varchar(n), char, bool,
  date/time/timestamp(tz) with precisions, interval(p), bit, bytea, json(b), uuid, inet, geometric types, xml,
  tsvector, arrays of int/numeric/varchar/timestamp(3)/text, all ranges, regclass, and an unknown OID. The output (175
  lines) is byte-identical on clean main and both branches (md5 `c2baa0d5`).
* The census SQL control: no workload changed SQL beyond the A/A's own changes (Discourse `GET topic.json` text,
  `mastodon-nops` cache-order counts under YJIT).
* Local suites, Ruby 4.0.7, `RAILS_STRICT_WARNINGS=1`, no warnings printed:
  * **Active Record PostgreSQL 15, full:** 17: 11,166 runs; 16 (`408e6a3e29`, with its 6 new tests): 11,172 runs.
    Both 0 failures, 0 errors, 31 skips.
  * **Active Record SQLite, full:** 17: 10,247 runs; 16: 10,252 runs. Both 0 failures, 0 errors, 52 skips. A first
    run had 4 errors in `sqlite_rake_test.rb` because the orb lacked the `sqlite3` CLI; after installing it, 0.
  * **RuboCop:** each branch's changed files, no offenses.
* **Open PRs:** none changes `get_oid_type` or `HashLookupTypeMap`. #44478 and #46409 (2022/2024) move the type
  map into the schema cache and touch `get_oid_type`'s surroundings, not the key. #57785 adds a `get_oid_type` call
  in quoting, compatible. #57517 (oneearedrabbit) wraps `cast_result` in `@lock.synchronize` and reindents it, so it
  conflicts textually with 17 (not semantically); 17 rebases onto it in one hunk.

### PR description drafts (not published)

**16 — Reuse type map cache keys for PostgreSQL result columns**

> Every query result on PostgreSQL looks up each column's type with `type_map.fetch(oid, fmod, sql_type)`. That
> `*args` Array is the type map's cache key, so even when the type is cached, every column of every query allocates
> one Array.
>
> Result columns have no SQL type, so their key is always `[fmod, ""]`. `HashLookupTypeMap#fetch_result_type` keeps
> that key on the type map once a type was cached under it, next to the cached types it indexes: `register_type` and
> `clear` (so `reload_type_map`) drop it with them, failed lookups retain nothing, and nothing is process-global.
> Cache keys, registered type blocks and resolved types are unchanged; lookups with a SQL type still use `fetch`.
>
> One Array fewer per result column (a 10-column `select_all`: 27 → 17 objects in `cast_result`). Across nine
> open-source apps on PostgreSQL (Mastodon, Discourse, Lago, Loomio, Docuseal, Sure, CASA, CodeTriage, PingCRM), 120 of
> 124 request, job and mailer workloads allocate fewer objects, median −171 per workload (−2.4%), with or without
> prepared statements. Allocation counts only; no timing claim.

**17 — Avoid scratch Arrays when casting PostgreSQL results**

> `cast_result` allocates two Arrays for every query: `field_types`, to remember each column's OID across its three
> passes, and `missing_oids`, which stays empty unless the type map lacks an OID. `PG::Result#ftype` is a cheap
> Integer accessor, so read it again in each pass, and build `missing_oids` only when an OID is missing.
>
> Two Arrays fewer per query. Across the same nine PostgreSQL apps, 121 of 124 workloads allocate fewer objects,
> median −23 per workload. No timing claim.

## Rejected, covered elsewhere, and leads

* **Row values (`database_statements.rb:258`, 309/op), field Array (`:228`), `types` (`:231`), `PG::Result`:** the
  result itself. Required.
* **Field-name Strings (`:228` String share, one per column per query on pg < 1.7):** fixed in the pg gem 1.7.0
  (ruby-pg#750 interns them). Lago, Sure (1.5.9), CASA, Docuseal, CodeTriage (1.6.3) would drop as many objects as
  candidate 16 saves by upgrading pg. **Upgrade lead for those apps, not a Rails PR.**
* **`PG::TextDecoder::Date` (Sure, `decode_dates`):** 4 objects per decoded date in Ruby (MatchData, captures, Date).
  ruby-pg master replaces it with a C decoder (unreleased). Upgrade lead.
* **`sql_key` (`postgresql_adapter.rb:1124`, 9.6/op):** the statement-pool key String per prepared query. A
  path-keyed nested pool would remove it, but that changes the statement cache. Lead only.
* **Quoting and `exec_params` lines:** the escaped literals and libpq binds. Required. Without prepared statements,
  the extra objects are the SQL literals themselves (`quoting.rb:86` Integer `to_s` for Mastodon's snowflake ids).
* **`LazyAttributeSet#keys` (`attribute_set.rb:225`, 9 apps, Mastodon 294/op):** open #58002 and #59141 change exactly
  this method. Excluded.
* **General lines:** unchanged from census 5; see its rejections.

**Rails-main regressions found while booting the apps** (none has an issue yet; leads for maintainers, not PRs):

* **rails#58427 (`8c4ed25f0a`), array-form `find_by_sql` binds.** Values in `find_by_sql([sql, {…}])` are now bound
  parameters instead of interpolated literals. With prepared statements on, PostgreSQL rejects typed literals built
  from placeholders: `SELECT DATE :d` becomes `DATE $1`, a syntax error (`PG::SyntaxError … at or near "$1"`).
  Untyped placeholders it can't infer also fail, as in Sure's transfer matcher. With `prepared_statements: false`
  it works, because the binds are substituted. The CHANGELOG entry mentions binds but not this break. Sure needed
  `CAST(:x AS date)` and `sanitize_sql_array`.
* **`b1650993b0`, `Arel::Table.new(name)` → `Arel::Table.new(name:)`.** No deprecation path and no CHANGELOG entry.
  It broke 3 of 7 apps (Docuseal and Discourse directly, CASA through flipper 1.4.2, the latest release); cancancan
  3.7's AR4 adapter also still calls it positionally. flipper fixed it on main (flipper#1003), unreleased.
* Also seen: `RemoteIp` `filter_proxies` (Mastodon), Rails' Sidekiq adapter removed (Lago), `VALID_UNSCOPING_VALUES`
  frozen (clickhouse-activerecord), log subscribers moved to the event reporter (`detach_from` on Active
  Storage/Job subscribers), `Key::Mapping` rejecting Discourse chat's composite foreign key. These are deliberate
  changes that need app updates.

## script/census: what it needed

The census ran entirely through `script/census` (setup, run --aa, compare, rank, prs). Fixes and additions:

* **Variant lock dropped `RUBY VERSION`:** the variant Gemfile drops the `ruby` pin, but the copied lock kept
  `RUBY VERSION`, and frozen Bundler refused to resolve. The variant lock now drops that section. General bug.
* **Rails component Gemfiles:** apps that list `railties`, `activerecord`… instead of `rails` (Discourse) get every
  component line swapped, and `lock_outside_rails` recognizes a `railties` GIT block.
* **A failed app no longer stops its mode:** each app's failure is collected, the other apps finish, then `run`
  raises with the list. Before, a thread's exception left the run half done.
* **Copies shared by configurations:** `copy: APP` rows (`-nops`) run APP's copy; `run` serializes configurations of
  one copy so they never share a database at the same time.
* **New row keys:** `pre_db`, `db`, `assets: false`, overlay paths outside the default directory, per-app env.
* **Harness:** `CENSUS_SIDEKIQ_FAKE`, `CENSUS_PREPARED_STATEMENTS` check, `CENSUS_DEBUG`, a missing `require "faker"`
  (PingCRM prepare), YJIT-enable hiding for Sure, and `rank` treats `APP-nops` as APP. Throttles reset per run
  (Mastodon's Redis posting limit carried over between runs and failed the YJIT runs with HTTP 429).
* **Not fixed:** `compare` prints "(no meta.json)" for a label whose run has not finished yet (cosmetic). A
  supervised orb service restarts a failed `run` from scratch; run it from a wrapper that exits 0.

## Limits

* Allocation counts only, one machine, PostgreSQL 15. No timing is inferred.
* The seeds are small and deterministic (the apps' own generators where they have one). Real data changes column
  counts per query only slightly, and both candidates scale with columns and queries, not rows.
* Some workloads carry state across runs (Discourse topic replies, Loomio comments, Mastodon's Redis cache). Each
  shows up in the A/A, and the candidates' Rails lines were checked separately where it mattered.
* Discourse runs without plugins (`LOAD_PLUGINS=0`) and serves crawler HTML and JSON, not the Ember app.
* Wikino, Forem, Chatwoot and Spree/Solidus are not included (see Apps).
