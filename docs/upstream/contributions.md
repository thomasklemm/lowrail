# Upstream contributions

These are scoped upstream changes, not extra Lowrail request prices or whole-application speed claims.

**Checked on 2026-10-22:** every merged/open label below was verified with
`gh pr view`, including the PR body and GitHub's merge commit when merged.
Later checks are dated on the individual entries.
Numbers summarize the linked PR's own evidence, not new measurements.
Allocation reductions, instruction counts, fallback diagnostics and helper
microbenchmarks are not interchangeable with request latency or throughput.
Where a PR reports no performance measurement, none is inferred here.

**Rechecked on 2026-11-02:** every PR state below was read again with
`gh pr view`; PRs opened October 23 – November 2 were added from
`gh search prs --author thomasklemm --created 2026-10-23..2026-11-02`.

Coverage: public PRs by `thomasklemm` opened October 19 – November 2 that
relate to Lowrail, plus the older Campfire work below. Roundhouse compiler work
and a review of another author's Mail PR are listed separately. Closed
superseded PRs are omitted except for the notes under [Closed](#closed).

[Merged](#merged) · [Closed](#closed) · [Open](#open) · [Campfire maintenance](#campfire-maintenance) ·
[Reviews](#reviews) · [Roundhouse](#roundhouse) ·
[Investigated, not submitted](#investigated-not-submitted)

## Merged

All entries in this section are **merged; rechecked on 2026-11-02**.
The merge links use GitHub's `mergeCommit`, not the contributor's pre-merge commit.

### Rails — rails/rails

**Status 2026-11-04 09:00 UTC:** 30 of the 38 Rails PRs from this cycle (#59533–#59598) are merged, all by amatsuda: #59583 and #59585 overnight, #59596 (07:33), #59597 (07:37) and #59598 (07:43 UTC) on 2026-11-04. Open: #59557, #59564, #59565, #59569, #59570, #59574, #59584. #59577 closed 09:32 UTC as superseded by #59590 (see [Closed](#closed)).

- [#59616](https://github.com/rails/rails/pull/59616) (W2 from the [Active Record write-path round](ar-write-paths.md)), `record_update_timestamps` reads the clock only right before the first timestamp column it writes, so the second timestamp pass of an update no longer calls `with_connection` for a time it never uses — `post.update!` Callgrind −1.4% / −0.9% / −1.4% (interpreter / YJIT / ZJIT, A/A ≤ 0.20%), 190 → 189 allocations in the micro; three tests. Subagent primary and adversarial reviews, then Sol: open after fixes (applied). Lib +2/−1, test +34, L1. Head `ef0266d0d6` on main `9cf3693a0a`; merge-tree clean on `d2ab41e65a`. Opened 2026-11-04 13:53 UTC with Thomas's OK ([body](../../bench/upstream/ar_write_paths/w2-body.md)). Watched report-only from the round thread. **Merged 2026-11-04 14:58 UTC** by amatsuda (merge `8b06b0eb98`), no comments or reviews, CI green; watch cleared.
- [#59615](https://github.com/rails/rails/pull/59615) (AS-1 from the [background census](background-census.md#candidate-as-1-read-the-blob-filenames-extension-once-when-choosing-a-variant-format)), `Representable#format` reads `filename.extension` once instead of up to three times (each read builds a `Filename` and sanitizes the whole name) — variant construction `blob.variant(resize_to_limit: [100, 100])` on a PNG 61 → 39 objects, −33% / −40% / −37% instructions (interp / YJIT / ZJIT, A/A ≤ 0.12%), −30% / −35% time; variant-representation-path workloads −7.2% to −9.9% interpreter instructions in six apps (A/A ≤ 1.5%), 22 fewer allocations in most, 9 in Fizzy's avatar variant. Lib +3/−2, L0; subagent review, then Sol (open after body fixes, keep the code). Head `fa58e6094c` on main `9cf3693a0a`; merge-tree clean; adjacent, not duplicate: #51115, #58615, #57597, #57731. Opened 2026-11-04 ready for review; watched every 2 hours, report-only, from the opening thread. Merged 2026-11-04 14:31 UTC by amatsuda as [`6c23cb8f2a`](https://github.com/rails/rails/commit/6c23cb8f2a34b4cb1e10656b492027a4c008f446).
- [#59607](https://github.com/rails/rails/pull/59607) (CP-3 from [Rails common paths, round 2](rails-common-paths-2.md#cp-3-resolve-attribute-aliases-with-a-fetch-default)), `resolve_attribute_name` passes the resolved name as `fetch`'s default instead of `&:itself`: `type_for_attribute` −12% instructions interpreted, −22% YJIT, −29% ZJIT; shipit −0.11% instructions per iteration interpreted. Opened 2026-11-04 12:31 UTC as Thomas under the standing OK (DECISIONS 6aca583) after two Sol rounds; head `be7ab87287` on main `9b116f1fed`. **Merged** by amatsuda on 2026-11-04 13:57 UTC (merge commit `4e76f138b8`), with no comments or reviews and CI green (Buildkite rails and docs-preview, rails-new-docker, labeler); watch cleared.
- [#59605](https://github.com/rails/rails/pull/59605) (AR-1 from the [Active Record request-path round](ar-request-paths.md)), SQLite3 `perform_query` looks up the type map once per result instead of once per column (`result_type_map = type_map`) — `Post.find` (9 columns) instructions −2.2% / −1.8% / −1.6% (interpreter / YJIT / ZJIT, A/A ≤ 0.37%); with `default_timezone` in database.yml −15% / −24% / −23%; objects unchanged (60 → 52 with `default_timezone`); ruby-bench shipit −0.44% / −0.25%, lobsters −0.14% / −0.19% (A/A ≤ 0.08%), railsbench YJIT within noise; census 8: all 8 SQLite apps, about 0.02% of instructions. Subagent primary and adversarial reviews, then Sol: no problem in stock Rails; differences only from overrides of the private `type_map` or type-map factories that mutate adapter state (accepted). Renamed from `type_map = type_map()` on Sol's readability note. Lib +2/−1, L0. Head `501bf5cc67` on main `9b116f1fed`; `test:sqlite3` 10,281 runs, 0 failures, 0 errors; RuboCop clean. Opened 2026-11-04 12:12 UTC with Thomas's OK. Watched report-only from the round thread. **Merged 2026-11-04 13:29 UTC** by amatsuda (merge `9cf3693a0a`).
- [#59603](https://github.com/rails/rails/pull/59603) (T1 from the [Action View round](actionview-render-c10.md#t1-check-for-string-tag-attribute-values-first)), `TagBuilder#append_tag_option` checks for a String attribute value first instead of after the Array, Hash, Regexp and Symbol checks; same body as `else`, so Strings are escaped as before. `tag.input` with three String attributes −6.2% / −2.2% / −2.0% instructions (interpreter / YJIT / ZJIT; A/A ≤ 0.24%), −4.7% / −2.4% time; non-String values pay one more check (Symbol +1.2% interpreted); 90–98% of attribute values are Strings in 5 apps, about 0.1% of a Fizzy or Lobsters page; railsbench within noise. L1; primary and adversarial subagent reviews approve. Head `f02e21ddbb` on main `9b116f1fed` (merge-tree clean, main unchanged at opening). Opened 2026-11-04 with Thomas's OK, ready for review, body as reviewed. Merged 2026-11-04 13:14 UTC by amatsuda with no review comments, CI green ([1ca7528](https://github.com/rails/rails/commit/1ca7528bac)).
- [#59596](https://github.com/rails/rails/pull/59596) (CP-1 from the [common-path round](rails-common-paths.md), opened 2026-11-04 06:13 UTC after Thomas approved), a cached statement's SQL is frozen once when it is cached, so `to_sql_and_binds` no longer copies it on every cached `find`/`find_by`/association read (prepared statements only) — `Post.find` 61 → 59 objects, −0.40% / −0.53% / −0.59% instructions (interp / YJIT / ZJIT; A/A ≤ 0.2%); ruby-bench within noise. Boundaries: `payload[:sql]` is the same frozen String per execution; an override of `find_by_sql`/`select_all` that edits the SQL in place now raises `FrozenError` (on main it corrupted the cached SQL). The unprepared half was dropped after the adversarial round. L0. Head `aabbcd09e9`. Merged 2026-11-04 07:33 UTC by amatsuda ([6b95940](https://github.com/rails/rails/commit/6b95940a24)).
- [#59597](https://github.com/rails/rails/pull/59597) (CP-2, same round), `allow_browser` converts its named version sets (`:modern`) to HWIA once at load instead of per checked request — 190 → 189 objects, −5.7% / −3.5% / −4.5% instructions, 43.9 → 40.4 µs / 23.5 → 22.5 µs per check (A/A ≤ 1.7%); custom hashes unchanged; Ractor-shareability test. L1. Head `e78c7e93d3`. Fork devcontainer smoke test failed only in its trilogy step (sqlite3/postgresql/mysql passed on the same code; CP-1 passed all four), so infrastructure, not this change. Merged 2026-11-04 07:37 UTC by amatsuda ([03ccff5](https://github.com/rails/rails/commit/03ccff57a7)).
- [#59598](https://github.com/rails/rails/pull/59598), `URI_REGEXP` anchors once instead of per alternative (`^(?:A|B|C)` for `^A|^B|^C`), same matches at the same positions (8.1M exhaustive strings plus 320k random) — `asset_path("application.css")` 2,621 → 2,296 ns / 1,883 → 1,608 ns (−12.4% / −14.6%, A/A −1.1% / −0.9%), Ir −10.5% / −14.0%; `stylesheet_link_tag` Ir −3.7% / −5.6%, time within noise; absolute URLs unchanged; 0 objects changed; about 0.1% of a request, within noise ([record](rails-main-census-8.md#rebased-with-time-2026-11-03)). Lib +1/−1, L0. Head `8d9d843428` on main `d795dac950`; `6782df4a5e` did not touch the file and merges cleanly. Watched every 2 hours, report-only, from the opening thread. Merged 2026-11-04 07:43 UTC by amatsuda (merge f2dfd1ace1).
- [#59583](https://github.com/rails/rails/pull/59583), `ThroughAssociation#stale_state` reads a single-column belongs_to foreign key directly instead of `Array(fk).filter_map.presence` — **3 → 1** objects per loaded through read; Ir per call −22% interpreter, −40% YJIT, −42% ZJIT (A/A ≤ 0.2%); 16 workloads in 5 apps (bet R7-3, [record](rails-r7-queue.md)). Sol approve on both rubrics; adversarial Astra: String-subclass keys with `to_ary` diverged, fixed with `instance_of?(String)`; accepted: an `Array` method defined on the association class. Lib +10/−3, L1. Head `44048a3`. Opened 2026-11-03. Merged 2026-11-04 by amatsuda.
- [#59585](https://github.com/rails/rails/pull/59585), freeze `TimeZoneConverter` when its subtype is frozen and `EnumType` when its mapping and subtype are, so models share their default attributes through the schema context instead of Ractor-local storage — `Post.attribute_types` −40% / −45% instructions, `Post.new` −8.6% / −14%, loading 10 rows −4.1% / −4.9%; ruby-bench −0.13% to −0.23% (interpreter; railsbench and shipit under YJIT), ZJIT lobsters −0.20%; 223 of 312 models in eleven apps move to the shared path (bet AT, [record](schema-context.md)). ZJIT: a model left on the slow path is up to 4.6% slower per read (that branch compiled without a profile), both ZJIT apps net lower; accepted as explained. Sol and Astra: user subclasses of the converter were frozen, fixed with `instance_of?(TimeZoneConverter)` plus a stateful-subclass test (none on `EnumType`: `_enum` builds it with the literal `EnumType.new`). Accepted: `Delegator#freeze` freezes the already frozen subtype again (main does the same whenever a converter is frozen; only a freeze hook mutating a frozen subtype notices); prepends or `decorate_attributes` blocks that set ivars and `clone` plus mutation now raise, in line with the column types frozen since #54228 and #55606. Lib +6/−2, L1. Head `2236cd5`. Opened 2026-11-03. Merged 2026-11-04 by amatsuda.
- [#59235](https://github.com/rails/rails/pull/59235), skip empty notification-group mapping — no-subscriber and fully silenced handle cycles allocate **2 → 0 objects**; micro throughput is **1.59× / 2.46×** interpreter/YJIT without subscribers and **1.34× / 1.77×** fully silenced. Active-case allocations are unchanged and timings fall within reported error; no request-level improvement claimed. [Merge 206f2c9](https://github.com/rails/rails/commit/206f2c927a91226563af383df871aad745a36eb1).
- [#59236](https://github.com/rails/rails/pull/59236), avoid CurrentAttributes default-pair arrays — objects/reset **2 → 1** empty, **5 → 1** three unset/scalar, **8 → 4** mutable, **7 → 3** callable, **17 → 6** ten mixed; the mixed reset micro is **1.31× interpreter / 1.26× YJIT**, not an application request measurement. [Merge 596da00](https://github.com/rails/rails/commit/596da00373ca9606a4d7741289203fe62d6ce12b).
- [#59244](https://github.com/rails/rails/pull/59244), use nested Symbol attribute names without a copy — **one object per processed nested Symbol key** saved: three-key tags **17 → 14**, two-key aria **18 → 16**, links **19 → 16**, buttons **27 → 24**, in interpreter/YJIT. No stable throughput claim: exploratory timings include lower link/button point estimates; Symbol names are shared/frozen, not identity/mutability-preserving. [Merge 9998e98](https://github.com/rails/rails/commit/9998e98857e606c834659ab0be75b8361c2696b6).
- [#59252](https://github.com/rails/rails/pull/59252), append error-translation keys without ancestor-pair arrays — GC-counter objects/lookup **169 → 167 / 246 → 243 / 398 → 393** for one/two/four ancestors; MemoryProfiler instead counts **1 / 2 / 4** fewer Arrays (**40 / 80 / 160 bytes**) because it excludes internal objects. The synthetic validation-error endpoint saves about **18 objects/request**; mixed timings and noisy A/A establish neither speed nor equivalence. [Merge 0213cf5](https://github.com/rails/rails/commit/0213cf5f4103e509e79f042e10a6297bd4ceaf50).
- [#59270](https://github.com/rails/rails/pull/59270), reuse delegated-type helper names — **2 → 1 allocations/call** in interpreter/YJIT/ZJIT; median million helper calls/s **0.977 → 1.181 / 1.358 → 1.594 / 1.371 → 1.748**, respectively. Helper microbenchmarks only, not application-level speedups. [Merge ab5a78a](https://github.com/rails/rails/commit/ab5a78a7c221915cbf09c2824068c4479d144f91).
- [#59274](https://github.com/rails/rails/pull/59274), reuse unique asset-tag source arrays — **one Array/helper call** saved in all nine cases and interpreter/YJIT/ZJIT (default **29 → 28**, three stylesheets **64 → 63**, preload-disabled/deferred **22 → 21**). Allocation-only: two ZJIT A/A timing controls exclude parity; no speedup/application saving claimed. [Merge e4fd6cb](https://github.com/rails/rails/commit/e4fd6cb9678755b209de3fbb79ccb36f4311e4dc).
- [#59278](https://github.com/rails/rails/pull/59278), reuse PostgreSQL result fields while casting — **one Array per column-bearing result**, including zero rows: **11 → 10 / 10 → 9 / 72 → 71 / 16 → 15** objects/cast across the four fixtures; zero-column control unchanged. All 108 preregistered interpreter/YJIT/ZJIT workers retain the delta; noisy CPU intervals support **no speed or Ir claim**. [Merge fb7501a](https://github.com/rails/rails/commit/fb7501ad2d7f77713a7de4ed20db1d1d5b5f1c02).
- [#59533](https://github.com/rails/rails/pull/59533), build `WhereClause#ast` predicates in one pass — one Array fewer per compiled where clause, interpreter and YJIT alike. Allocation-only. **Merged 2026-11-02.** [Merge b5be036](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953).

**This cycle, moved from Open on 2026-11-03** (all merged by amatsuda; text as recorded when they were open):

From [census 3/3b](rails-main-census-3.md); allocation counts only, no timing claim. Held candidates 3, 4, 6 and 7 are listed there.

- [#59534](https://github.com/rails/rails/pull/59534), map Arel `project`/`order`/`Window` rest arguments in place — Fizzy **−126/−39/−13**, Writebook **−6…−21**, blog index **−4**, both modes. **Merged 2026-11-02** ([090f540](https://github.com/rails/rails/commit/090f5408f4)).
- [#59535](https://github.com/rails/rails/pull/59535), avoid a rest Array in `HashWithIndifferentAccess#fetch` — every `params.fetch` and enum value cast: `params.fetch(:q)` **3 → 2** objects, `Post.where(status: :live).to_a` **77 → 74**; boundary tests for missing keys, falsy defaults and a present key with a block (head `fee8edf`; the block-plus-default warning test was dropped because Rails' strict-warnings CI turns that Ruby warning into an error); Codex Thermos (GPT-6.1 Sol) approve on both rubrics for the final head. **Merged 2026-11-02** ([c0cacea](https://github.com/rails/rails/commit/c0cacea4cd)).
- [#59536](https://github.com/rails/rails/pull/59536), share one frozen empty `collect_warnings` Array when a query has none — every executed query on SQLite, PostgreSQL without notices and MySQL without warnings (`Post.find(1)` **62 → 61**). Boundary: a third-party override appending to `super` would raise `FrozenError`. **Merged 2026-11-02** ([4740314](https://github.com/rails/rails/commit/4740314734)).
- [#59537](https://github.com/rails/rails/pull/59537), take `tag_string` options before the optional content — every `tag.*` call (`tag.span` **5 → 4**, custom `tag.my_widget` **9 → 6**). Boundary: private `:nodoc:` signature. **Merged 2026-11-02** ([45de402](https://github.com/rails/rails/commit/45de402637)).
- [#59538](https://github.com/rails/rails/pull/59538), frozen empty defaults when loading a relation — every query-running `Relation#load` −1, association load −2 (`post.author` **231 → 229**). Boundary: with `prepared_statements: false`, `sql.active_record` `binds` is that frozen Array. **Merged 2026-11-02** ([f4a40dc](https://github.com/rails/rails/commit/f4a40dc8a1)).
- [#59539](https://github.com/rails/rails/pull/59539), `drop(index)` for the join chain tail — one object per joined reflection in `joins`/`left_joins`/`eager_load`. **Merged 2026-11-02** ([d9ed22e](https://github.com/rails/rails/commit/d9ed22eef0)).
- All four went through Codex Thermos reviews (GPT-6.1 Sol), approve on both rubrics, before opening.
- From [census 4](rails-main-census-4.md) (nine apps, SQLite/PostgreSQL/MySQL, 97 request/job/mailer workloads per mode), reviewed with Codex Thermos (GPT-6.1 Sol) before opening; all merged 2026-11-02:
  - [#59541](https://github.com/rails/rails/pull/59541), skip unneeded Arrays when merging into an empty `WhereClause` — every association read and `Relation#merge` (`post.author` **235 → 228**); 82/97 workloads, median **−19**. **Merged 2026-11-02** ([1c4feea](https://github.com/rails/rails/commit/1c4feea25b)).
  - [#59542](https://github.com/rails/rails/pull/59542), skip finalizing intents on checkin when none are pending — every connection checkin (`Post.first` **118 → 117**); 82/97, median **−7**. **Merged 2026-11-02** ([ee16712](https://github.com/rails/rails/commit/ee16712354)).
  - [#59543](https://github.com/rails/rails/pull/59543), `except`/`only` read `@values` without the `values` dup — `exists?`, scoped `count`, association scopes; 62/97. Boundary: a subclass overriding `values`. **Merged 2026-11-02** ([f861e1e](https://github.com/rails/rails/commit/f861e1e0ce)).
  - [#59544](https://github.com/rails/rails/pull/59544), extract Ranges in `ArrayHandler` only when present — every `where(col: array)` and preload `IN`; 60/97. **Merged 2026-11-02** ([5810776](https://github.com/rails/rails/commit/5810776eec)).
- From [census 5](rails-main-census-5.md) (same nine apps on main 5810776 after the merges), Codex Thermos (GPT-6.1 Sol) approve on both rubrics for each; opened 2026-11-02:
  - [#59551](https://github.com/rails/rails/pull/59551), skip `extending!` in `Relation#merge` when there are no extensions — every merge −1 (`author.posts.count` **100 → 98**); 76/97, median **−5.8**; 63/97 still move with open #59212. **Merged 2026-11-03** by amatsuda ([bd77235](https://github.com/rails/rails/commit/bd77235be534f5a2103cb2f33f6bb356ab6e535f)).
  - [#59552](https://github.com/rails/rails/pull/59552), a direct association reflection's `constraints` returns `scopes` — −2 per direct reflection (`post.comments.size` **249 → 246**); 74/97, median **−7.3**. Boundary: a subclass overriding `chain`. **Merged 2026-11-03** by amatsuda ([e64b660](https://github.com/rails/rails/commit/e64b660612fa582a4a89a91bc002269b29426e76)).
  - [#59553](https://github.com/rails/rails/pull/59553), frozen empty `default_extensions` without a default scope — −1 per association proxy; 58/97, median **−1.6**. Boundary: a caller mutating the result. **Merged 2026-11-03** by amatsuda ([f21e7f4](https://github.com/rails/rails/commit/f21e7f42b510327f6bc57dcb7fcc9825d4670a91)).
  - [#59554](https://github.com/rails/rails/pull/59554), precomputed bang method names in `Merger#merge` — −1 String per merged value (`post.author` **223 → 222**); 66/97, median **−3.0**. Overlaps open #59212 (with it: 51/97 interpreter, median −1; YJIT within noise), stated in the PR. Sol approve on both rubrics; opened 2026-11-03. On #59212 itself (Sol static review: no findings) we posted the nine-app breadth numbers: 75/74 of 97 workloads, median −46/−49. **Merged 2026-11-03** by amatsuda ([c9a34da](https://github.com/rails/rails/commit/c9a34da1671ea9536a0281a840c956e48a1a27a2)).
  - [#59555](https://github.com/rails/rails/pull/59555), `Enumerable#index_with` yields what `each` yields again — fixes an unreleased regression from 2b88dc1995 where Hash/HWIA receivers got only keys and Struct got member names; `Array#index_with` keeps `to_h`. Sol approve on both rubrics; opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([3bdc579](https://github.com/rails/rails/commit/3bdc57909066eb17dee70fea0b6266edaffa9ffc)).
  - [#59556](https://github.com/rails/rails/pull/59556), `Merger` reads the other relation's values without a dup (new `:nodoc:` `values_for_merge`; copies only when the values Hash is the receiver's own) — every merge and association read −1…−3 (`post.author` **223 → 221**); 80/97, median **−6.8**. Sol: first round request-changes (CollectionProxy self-merge dropped `limit`), fixed and approved on both rubrics; opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([e2e002b](https://github.com/rails/rails/commit/e2e002be27e69e6acdbc7e81ecec417109073ae8)).
- From the [PostgreSQL census](pg-census.md) (nine PG apps incl. Mastodon, Discourse, Docuseal, Lago, Loomio, Sure, CASA; 124 workloads incl. `prepared_statements: false`):
  - [#59558](https://github.com/rails/rails/pull/59558), `cast_result` without `field_types`/`missing_oids` scratch Arrays — −2 per query result; 121/124, median **−23**. Sol approve on both rubrics; opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([25e5dd3](https://github.com/rails/rails/commit/25e5dd34e7860e3c0e880a49180ded0e8520511f)).
  - [#59560](https://github.com/rails/rails/pull/59560), reuse frozen `[fmod, ""]` type-map keys for PostgreSQL result columns, kept per type map and dropped with its cache — −1 Array per result column (10-column `cast_result` **27 → 17**); 120/124 PG workloads, median **−171** (−2.4%). Head `408e6a3` after two Sol request-changes rounds (process-global keys, then keys retained by failed lookups); Sol approve on both rubrics. Opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([98353c4](https://github.com/rails/rails/commit/98353c4ba21b8c7cf575c256b8bb581dff304ec6)).
  - [#59561](https://github.com/rails/rails/pull/59561), `thread_mattr_accessor` uses a frozen literal key for the defining module (subclasses still build theirs) — reader/writer **2 → 0** objects, reader 364 → 198 ns interpreter / 299 → 109 ns YJIT; 83/97 workloads, median **−10.8** (Lobsters −41 via query log tags). From the [framework census](rails-framework-census.md) (bet R2). Sol approve on both rubrics; opened 2026-11-03, **merged** 2026-11-03 by amatsuda (e367362), no review comments.
  - [#59562](https://github.com/rails/rails/pull/59562), `ActiveSupport::Subscriber` records each String pattern's handler in an ivar at `attach_to`, so `#call` no longer slices the event name — **1 → 0** objects per call (424 → 217 ns interpreter, 242 → 87 ns YJIT); 75/97 workloads, median **−3.3** (Fizzy −23 to −29). Complements open #58957. Head `963c79f` after two Sol request-changes rounds (public accessor collided with handler names and dotted names changed dispatch; then Regexp `prepare_pattern` broke `attach_to`); Sol approve on both rubrics. Opened 2026-11-03. amatsuda found a regression (a subclass that skips `super` in `initialize`, subscribed directly); fixed with his `&.` suggestion plus a test, head `81f6b8a`, replied. fatkodima objected to `instance_variable_get`; the map moved to the subscriber class (head `7b23c4e`), replied. **Merged 2026-11-03** by amatsuda ([d47dc59](https://github.com/rails/rails/commit/d47dc59e6559c15b1775d086c00f4f71e7f52114)).
  - [#59563](https://github.com/rails/rails/pull/59563), Active Job `serialize_hash` walks the Hash with `each` instead of `each_with_object` pairs — typical kwargs **13 → 6** objects per serialize, Chatwoot status toggle −238 (−1.3%). From the [Inertia/Chatwoot census](inertia-chatwoot-census.md) (bet L6). Sol approve on both rubrics; opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([107b889](https://github.com/rails/rails/commit/107b889051d3cb8af4731435875acbd05f409563)), no review comments.
- From the CPU deep dives (bets V1 and A1; instruction counts with A/A, no timing claim). Sol on both rubrics, then an adversarial Astra round (DECISIONS 2026-11-03). Opened 2026-11-03.
  - [#59568](https://github.com/rails/rails/pull/59568), `_load_from_sql` reads `attribute_types` once instead of twice per column — `Post.find` −6.6% / −3.8% instructions (interp / YJIT); ruby-bench shipit −4.1% / −5.3%, railsbench and lobsters about −1%. Moot if #59141 lands first. Astra P3 (a schema change injected mid-filter keeps the old types) accepted. **Merged 2026-11-03** by amatsuda ([ee0d58f](https://github.com/rails/rails/commit/ee0d58f5c36a83577e2a93320b2d61feaf666bab)), no review comments.
  - [#59571](https://github.com/rails/rails/pull/59571), scope methods for lambda bodies without parameters take no parameters — `Post.published` 19 → 17 objects, `relation.published` 20 → 18; census median −13 objects per request in 20 of 21 configurations (bet R6, [record](rails-r6-leads.md)). Sol: request-changes (`->(**nil)` message), fixed (`parameters.empty?`), approve on both. Astra adversarial: two P3s accepted (an extension overriding the internal `_exec_scope` to swallow arguments; a Proc with overridden `parameters`). Head `8e4bb3a`. Opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([2915abb](https://github.com/rails/rails/commit/2915abbf91bf82a5eb047f3eff6fb3af61ff1f79)), no review comments.
  - [#59576](https://github.com/rails/rails/pull/59576), `WhereClause#ast` wraps a single predicate directly instead of building a nodes Array — `where(id: 1)` 92 → 91 objects; 187 of 251 workloads, median −4 (18 apps). From [census 7](rails-main-census-7.md). Sol approve on both rubrics; adversarial Astra: overrides of the private `predicates_with_wrapped_sql_literals` and a predicate appended from inside `eql?` accepted. Head `f903005`. Opened 2026-11-03. **Merged 2026-11-03** by amatsuda ([1597d57](https://github.com/rails/rails/commit/1597d576bd222de7bf55bf7a12bffd87138f2a13)).

**Combined (2026-11-03):** all eleven merged #59533–#59544 together, against the same Rails main with them
reverted, remove 1.66% / 1.64% of allocations (interpreter / YJIT) over 206 workloads in sixteen apps; wall time on
railsbench and lobsters is a tie within A/A ([combined effect](combined-effect.md)).

### Ruby — ruby/ruby

**Merged; checked on 2026-11-02.** JIT correctness and diagnostics fixes; none claims a speedup.

- [#19485](https://github.com/ruby/ruby/pull/19485), stop ZJIT send counters accumulating across specialization retries — repro counters **[18, 18, 9] → [9, 9, 9]**; railsbench's first two counters **749,107 → 250,038**, control unchanged. Counter-correctness fix; three stats-off chunky-png comparisons ran 2.3–5.7% longer with identical HIR, cause unexplained, **no performance claim**. [Merge 8258233](https://github.com/ruby/ruby/commit/8258233785195eb92e05e7bd964d0b00d94ed824).
- [#19538](https://github.com/ruby/ruby/pull/19538), exit with the original send's stack on ZJIT stack overflow — master crashed or returned wrong arguments for default-filled/reordered keywords, rest and `&nil` sends at all 12 tested VM stack sizes; the PR passes all of them. Correctness fix, normal path unchanged. [Merge 461085c](https://github.com/ruby/ruby/commit/461085c2c7c23a0c3393223d603d4254f30f6f7c).
- [#19554](https://github.com/ruby/ruby/pull/19554), YJIT falls back for explicit keywords in IFUNC block calls — `enum_for` with `yield [], key: 1` returned `[[[], 1]]` instead of the interpreter's `[[[], {key: 1}]]`. Correctness fix. [Merge 54d0988](https://github.com/ruby/ruby/commit/54d098816777fd29e716746c2adcb3bbe4f88710).
- [#19586](https://github.com/ruby/ruby/pull/19586), ZJIT guards the lookup CME when resolving aliases — re-aliasing a module method could keep calling the old target; regressions for sends and `super` fail without the fix. [Merge 1654a6a](https://github.com/ruby/ruby/commit/1654a6a0fd71ef962635d1322a37cc50f908d91a).
- [#19619](https://github.com/ruby/ruby/pull/19619), backport of #19554 to `ruby_4_0`, requested in review. [Merge 9bebcb4](https://github.com/ruby/ruby/commit/9bebcb455f0f9ddbd4af1d3e5dcf2a96b508a455).
- [#19484](https://github.com/ruby/ruby/pull/19484), allow Proc arguments for explicit block parameters in ZJIT — **27 final send fallbacks/request removed in Fizzy, none in the blog**; earlier Arel-style forwarding micro ZJIT **−61.41% [−63.78, −59.53]**, interpreter **+1.75% [+0.03, +3.67]**, YJIT unresolved. Nine unrelated yield fallbacks remain; no request-throughput claim. **Merged 2026-11-03** by XrXr ([13c3f56](https://github.com/ruby/ruby/commit/13c3f56bb85f7e3f7e07b945c829117b48ee43f5)).
- [#19660](https://github.com/ruby/ruby/pull/19660), `Hash.new` redefinition and prepend are no longer ignored: #19537 registered `BOP_NEW` on Hash's singleton class, which `vm_redefinition_check_flag()` didn't map, so `opt_new` kept its Hash fast path after `Hash.new` was redefined. Correctness fix with a regression test; Codex Thermos (GPT-6 Astra) approve on both rubrics. Opened 2026-11-03. **Merged 2026-11-03** by byroot ([a8b095a](https://github.com/ruby/ruby/commit/a8b095a07e55adf429839d4642027e832e30d3a7)); follow-ups #19661 and #19663 are under [Open](#open).

### SQLite — sparklemotion/sqlite3-ruby

- [#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758), avoid a row Array on statement completion — **one Array/completed statement, not per row**: empty SELECT **2 → 1**, one-row SELECT **4 → 3**, empty UPDATE **2 → 1** objects; repeated DONE stays zero. Allocation-only; no speed, latency or CPU no-regression claim. **Merged; checked on 2026-11-02.** [Merge 526d4e1](https://github.com/sparklemotion/sqlite3-ruby/commit/526d4e1d8aea588950850d4a204f298616d95b81).

### Prism — ruby/prism

- [#4298](https://github.com/ruby/prism/pull/4298), add Rust `Version::CRuby4_0`, retaining deprecated `CRuby3_5` — both select the same grammar; naming/API compatibility work, **no performance measurement**. Exhaustive matches need the new arm and old-variant uses warn. [Merge ca888b3](https://github.com/ruby/prism/commit/ca888b3a0e715b36a18fb8da0bd89fc7615e9a18).

### Campfire — basecamp/once-campfire

These performance-related PRs were opened before the October 19–22 census.

- [#318](https://github.com/basecamp/once-campfire/pull/318), query sidebar directs and shared rooms separately instead of loading all memberships then splitting/re-sorting — **no benchmark number in the PR body**. [Merge 0d5998f](https://github.com/basecamp/once-campfire/commit/0d5998f05778bf12c73bec3972e3dfa86a5a3af2).
- [#337](https://github.com/basecamp/once-campfire/pull/337), serve bot-page totals from SQLite-maintained `rooms.messages_count`, including bulk/foreign writers — removes the per-page messages `COUNT(*)`; **no measured speedup in the PR body**. This is the trigger-based revision, not the superseded callback counter cache. [Merge fd49099](https://github.com/basecamp/once-campfire/commit/fd490997290b930585b54aa87bde2a7ce1c69204).
- [#339](https://github.com/basecamp/once-campfire/pull/339), move SQLite WAL checkpoints off the request thread to an elected writer with a dedicated connection — **250 ms** PASSIVE loop, unchanged journal mode/`synchronous=NORMAL`; configuration/design evidence, **no benchmark number in the PR body**. [Merge e55b6dc](https://github.com/basecamp/once-campfire/commit/e55b6dc3e534e6dd884eb74eac387fd576c3e6a9).

### Gems

- [mperham/connection_pool#225](https://github.com/mperham/connection_pool/pull/225), `#with` passes frozen constant interrupt masks to `Thread.handle_interrupt` instead of Hash literals — `pool.with {}` **14 → 10** objects; −4.6 objects per workload on the 18 census configurations that lock 3.x (Mastodon −27.6). From the [gem census](gem-census.md) (bet G1). Sol approve on both rubrics; adversarial Astra: three low items accepted (wrappers of `handle_interrupt` taking `**mask` or mutating the mask, constant-redefinition warnings on reload); a `Fiber#raise` scheduler leak exists in base too. Opened 2026-11-03; mperham asked whether an inline `{Exception => :never}.freeze` avoids the allocation (it still builds the Hash per call, 1 object vs 0) and merged the constants. [Merge 17c1eef](https://github.com/mperham/connection_pool/commit/17c1eefdacebead60c5ac706b4c1088094e3b86b), 2026-11-03.
- [caxlsx/caxlsx#550](https://github.com/caxlsx/caxlsx/pull/550), infer native Integer cell types without decimal Strings — **200,000 fewer objects for 200,000 Integer cells**, **40,000** for the 160,000-cell mixed fixture; one object/Integer in all post-warmup samples. A/A wall medians differed **14.9% / 0.5%**, so allocation-only, not a reliable timing percentage; assumes standard native Integer methods. 2026-11-03: kiskoza requested `is_a?(Integer)` (the codebase's pattern) instead of `Integer ===`; switched, the spoofed-`is_a?` test dropped, rebased onto master as one commit `4649af4`, replied. Approved and merged by kiskoza. [Merge 886cec0](https://github.com/caxlsx/caxlsx/commit/886cec0663507cfb246355a0a9250e7eae8b36cf), 2026-11-03.

## Closed

- **Closed unmerged by skipkayhil on 2026-11-04 16:09 UTC:** [rails/rails#59623](https://github.com/rails/rails/pull/59623) (E1 from the [ecosystem test round](ecosystem-tests.md#regressions-and-their-fixes)), `descendants_tracker.rb` requires `active_support/weak_set`. [His comment](https://github.com/rails/rails/pull/59623#issuecomment-6635608877): "You must require active_support before cherry picking core extensions. Then WeakSet would autoload correctly." That is the documented contract, so the fix moved to ransack (G1, open as [activerecord-hackery/ransack#1792](https://github.com/activerecord-hackery/ransack/pull/1792)). Thomas replied with thanks. The E1 patch is superseded.
- **Closed by the author on 2026-11-04 11:50 UTC** (Thomas's OK, proposal in [explainers-ruby-open](explainers-ruby-open.md); ruby/ruby down to 10 open, the cap): [ruby/ruby#19483](https://github.com/ruby/ruby/pull/19483), guard ZJIT protected sends with runtime caller `self` — earlier stacked prototype permission fallbacks/request **87 → 1** blog, **353 → 9** Fizzy; inherited-options micro ZJIT **−36.45% [−38.75, −34.95]**, but YJIT **+3.61% [+1.26, +6.80]**. Not measurements of this independently master-based PR binary; no master-alone or whole-app speed claim. **Body rewritten 2026-11-04 05:55 UTC** with measurements of the PR itself (ruby-bench 73918b2, master 9b30fd207f, ZJIT stats diff format): `send_not_optimized_need_permission` 1,374,055 → 49 railsbench, 458,647 → 13,029 lobsters, 770,476 → 2,794 shipit; Callgrind instructions per iteration (GC excluded) −0.59% / −0.21% / −0.27%, master A/A ≤ 0.12%; `run_benchmarks.rb` wall time within the spread of two master builds. No review in 13 days. **Why closed:** ten new guard sites with no measurable run-time effect (`run_benchmarks.rb` within the spread of two master builds), not requested, and no review in 13 days ([closing comment](https://github.com/ruby/ruby/pull/19483#issuecomment-6629847121)).
- **Closed by the author on 2026-11-04 11:50 UTC** (Thomas's OK, proposal in [explainers-ruby-open](explainers-ruby-open.md); ruby/ruby down to 10 open, the cap): [ruby/ruby#19655](https://github.com/ruby/ruby/pull/19655), ZJIT passes (YJIT and ZJIT until the one-concern split on 2026-11-03; the YJIT half was dropped) the shared frozen empty Array to an empty anonymous `*` at non-splat call sites, as the interpreter has since 43683e1e9d (same change as merged #9972 for anonymous kwrest). Submitted as interpreter parity, not as a speed claim: ruby-bench allocations YJIT shipit −1.10%, lobsters −0.56%, railsbench −0.12%; timing within A/A. Head then `3db46445ca` on master b51db981f6, now `852298882d` (ZJIT only; body: ZJIT objects −1,919 / −1,057 / −2,084 per iteration on shipit / lobsters / railsbench); `make check`, btest with both JITs at threshold 1, zjit-check pass apart from pre-existing environment failures. Codex Thermos review (GPT-6 Astra): correctness approve, quality approve-with-nits (move the accessor to jit.c; declined, because yjit.c follows #9972 and k0kubun's request on #19648). Opened 2026-11-02. **Why closed:** small and correct, but without the ruby-bench effect the rule asks for; the finding stays in our docs and is quick to rebuild if the team wants it ([closing comment](https://github.com/ruby/ruby/pull/19655#issuecomment-6629848209)).
- **Closed by the author on 2026-11-04 11:50 UTC** (Thomas's OK, proposal in [explainers-ruby-open](explainers-ruby-open.md); ruby/ruby down to 10 open, the cap): [ruby/ruby#19685](https://github.com/ruby/ruby/pull/19685), ZJIT marks each JITFrame ISEQ once per GC instead of once per JITFrame (lead 13, [zjit-yjit-gap.md](zjit-yjit-gap.md)); head `aa82ba85e1`. Callgrind instructions per iteration with GC, ruby-bench, `--zjit-exec-mem-size=512 --zjit-mem-size=1024`, 0 OOM: `rb_zjit_root_mark` **28.5 → 2.0 M** railsbench, **7.0 → 0.26 M** lobsters, **~40 → 1.9 M** shipit; totals **−0.64%** railsbench (A/A 0.04% / 0.03%), **−0.23%** lobsters (A/A 0.07% / 0.08%), **about −0.5%** shipit (one master run in the slow warmup phase excluded). Same marked ISEQs; tests fail without root marking and without the compaction rebuild. Reviews: Astra correctness approve, Astra quality approve-with-nits (test helper tightened), adversarial Sol approve. Opened 2026-11-03 as the extra ZJIT-lead slot; CI and comments checked every 3 hours by its orb (the Amp GitHub App cannot subscribe to ruby/ruby). **Why closed:** fewer marking instructions under Callgrind, but no `run_benchmarks.rb` result beyond noise; the finding (marking per frame instead of per ISEQ) stays in [zjit-yjit-gap](zjit-yjit-gap.md) and is not an issue, since performance leads don't become issues on their own ([closing comment](https://github.com/ruby/ruby/pull/19685#issuecomment-6629849306)).
- **Closed by the author on 2026-11-04 09:43 UTC** (Thomas's OK, close proposal of the 09:00 UTC status check; ruby/ruby down to 13 open): [ruby/ruby#19663](https://github.com/ruby/ruby/pull/19663), YJIT ports the interpreter's `Hash.new` branch; `Hash.new(0)` 67 → 24 ns. Stacked on #19660 (merged) and #19661. Current body (head `251d0561d4`): `Hash.new(0)` 134.0 / 115.6 → 60.0 / 66.4 ns under YJIT, best of 7 in two runs. byroot suggested calling `rb_hash_s_new` directly (2026-11-03); we asked him at 21:36 UTC whether he prefers that or keeping the caller-side `#initialize` send for call-site refinements; no answer by 2026-11-04 09:00 UTC. byroot's [#19703](https://github.com/ruby/ruby/pull/19703) ("Refactor `opt_new` handling of Hash.new", merged by byroot 2026-11-04 09:03 UTC as 4d2f677b60) removed the `BOP_NEW` record and checks for `rb_hash_s_new` instead. This PR's guard is `assume_bop_not_redefined(jit, asm, HASH_REDEFINED_OP_FLAG, BOP_NEW)` and its bindings still list `BOP_NEW`, so it no longer builds on master although GitHub shows no textual conflict; it was also stacked on #19661, which #19703 replaced. **Why closed:** byroot's #19703 reworked `opt_new` for `Hash.new` and removed `BOP_NEW`, so this approach no longer applies; the refinement difference stays reported as Shopify/ruby#1101 ([closing comment](https://github.com/ruby/ruby/pull/19663#issuecomment-6627672705)).
- **Closed by the author on 2026-11-04 09:43 UTC** (Thomas's OK, close proposal of the 09:00 UTC status check; ruby/ruby down to 13 open): [ruby/ruby#19664](https://github.com/ruby/ruby/pull/19664), YJIT no longer dups a splat array before slicing it into a rest parameter (every Rails `where(...)` via `where!(*args)`), interpreter parity from the [JIT parity census](jit-parity-census.md); ruby-bench YJIT objects −0.07/−0.10/−0.13% (railsbench/lobsters/shipit). Astra approve on both rubrics; opened 2026-11-03. XrXr (review, 2026-11-03): YJIT is in maintenance mode and this touches a high-risk part, so "we're unlikely to take it for the next release". No reply needed: it sets expectations and asks nothing; the maintainers decide (DECISIONS, YJIT in maintenance mode). **Why closed:** YJIT is in maintenance mode (XrXr) and the gain is small ([closing comment](https://github.com/ruby/ruby/pull/19664#issuecomment-6627680229)).
- **Closed by the author on 2026-11-04 09:43 UTC** (Thomas's OK, close proposal of the 09:00 UTC status check; ruby/ruby down to 13 open): [ruby/ruby#19666](https://github.com/ruby/ruby/pull/19666), YJIT reuses a splat array as the rest parameter where vm_args.c's `rest_dupped` does (`SPLAT_MUT`, exact anonymous rest, `f(*a, **nil)`) — Rails' `process_action(*) = super` chain 5 → 3 objects (2 only with the YJIT half of #19655, which was dropped; #19655 is ZJIT-only); railsbench −0.23%. Astra: approve-with-nits (test could pass through the interpreter, `**nil` missing), fixed, approve; overlaps #19664 in one `if`. Opened 2026-11-03. **Why closed:** same as #19664 ([closing comment](https://github.com/ruby/ruby/pull/19666#issuecomment-6627680964)).
- **Closed by the author on 2026-11-04 09:43 UTC** (Thomas's OK, close proposal of the 09:00 UTC status check; ruby/ruby down to 13 open): [ruby/ruby#19665](https://github.com/ruby/ruby/pull/19665), YJIT interpolates Fixnums and Modules like `vm_objtostring` (guarded on `rb_int_to_s`/`rb_mod_to_s`, so refinements fall back) — `"#{klass} Update"` 2 → 1 object; shipit −0.21%. Astra: request-changes (refinement bypass), fixed, approve on both; opened 2026-11-03. **Why closed:** YJIT is in maintenance mode; the ZJIT version is open as #19678 ([closing comment](https://github.com/ruby/ruby/pull/19665#issuecomment-6627681555)).
- **Closed by the author on 2026-11-04 09:43 UTC** (Thomas's OK, close proposal of the 09:00 UTC status check; ruby/ruby down to 13 open): [ruby/ruby#19558](https://github.com/ruby/ruby/pull/19558), ZJIT reprofiles shape-polymorphic send misses — across 16 headline workloads, polymorphic fallbacks **20,763,714 → 16,787,818** and dynamic sends **87,940,035 → 84,116,799** (erubi-rails **12,222,068 → 8,921,915**); megamorphic fallbacks rise **8,175,838 → 8,317,469**. Three interleaved headline runs: geomean PR/base **0.986 / 1.006 / 0.997** versus A/A **1.006 / 0.997 / 0.996**, so **no measurable timing effect**. **Why closed:** no timing benefit beyond noise could be measured ([closing comment](https://github.com/ruby/ruby/pull/19558#issuecomment-6627682183)).
- **Closed by the author on 2026-11-04 09:32 UTC** (Thomas's OK): [rails/rails#59577](https://github.com/rails/rails/pull/59577), `preprocess_order_args` checks and references `order` arguments without intermediate Arrays, making the same calls on each argument as before — `order(:id)` 108 → 102 objects, `order(created_at: :desc)` 123 → 119; 203 of 251 workloads, median −10 (18 apps). From [census 7](rails-main-census-7.md). Four Sol + adversarial Astra rounds: private/singleton `to_ary`, singleton `to_a` on Hashes, live Hash iteration and adopted nested results fixed; accepted: conversions that rewrite the internal rest-args array via ObjectSpace, overrides of the private `flattened_args`, and a `disallow_raw_sql!` hook that keeps a reference to its argument. Head `889fdbf`. Opened 2026-11-03. fatkodima asked how candidates are chosen and whether it is worth the complexity; shrunk to `column_references` only (+16/−3, head `51c3f20`, `order(:id)` 106 → 102), [method page](method.md) written, [replied](https://github.com/rails/rails/pull/59577#issuecomment-6609726728). **Conflicts since 2026-11-04 06:19 UTC:** kamipo's merged [#59590](https://github.com/rails/rails/pull/59590) ("Extract order references from the built Arel nodes") rewrote `column_references` to take the references from the built nodes, collecting them into a lazily created Array and returning `FROZEN_EMPTY_ARRAY` when there are none, which is what this PR does on the old code; `order(:"posts.id")` 39 → 19 allocations there. Proposed: close with one neutral line (DECISIONS, someone else's PR covers ours) after checking that main leaves nothing for this PR. **Why closed:** superseded by kamipo's merged #59590; [closing comment](https://github.com/rails/rails/pull/59577#issuecomment-6627503050): "Closing, since #59590 covers this on main."
- **Closed by the author on 2026-11-04 08:47 UTC:** [ruby/ruby#19661](https://github.com/ruby/ruby/pull/19661), Hash subclasses keep the `opt_new` fast path in the interpreter (follow-up to merged #19660). k0kubun (02:43 UTC) found it fine and asked byroot or tenderlove to look; byroot (07:35 UTC): "it's a good catch, but the patch ain't very good", and opened [#19703](https://github.com/ruby/ruby/pull/19703) (08:17 UTC, "Fix" #19661; merged by byroot 09:03 UTC, 4d2f677b60), which drops the `BOP_NEW` record and checks whether `new` is `rb_hash_s_new`, keeping the fast path and capacity preallocation for Hash subclasses. Closed in favor of #19703 ([closing comment](https://github.com/ruby/ruby/pull/19661#issuecomment-6626621482)), which also notes that `String` and `Array` subclasses skip the fast path the same way (the case of our closed #19667).
- **Closed by the author on 2026-11-04:** [ruby/ruby#19680](https://github.com/ruby/ruby/pull/19680), ZJIT caches `iseq_may_write_block_code()`; fixes Shopify/ruby#1064. k0kubun asked for a cache that is dropped after each compile and for evidence in the tools' own format. Reworked that way, it saves about 1.2% of compile instructions on railsbench, lobsters and shipit (Callgrind, A/A within 0.1%), and a 2,000-call method compiles in 3.68 G instead of 7.15 G instructions, but `run_benchmarks.rb` shows no difference beyond A/A. Closed with the raw tables ([closing comment](https://github.com/ruby/ruby/pull/19680#issuecomment-6624629962)). The railsbench GC effect found while measuring it is recorded as lead G in the [lead queue](zjit-iseq-leads.md#queue-which-leads-are-free-2026-11-03).
- **Closed by the author on 2026-11-03:** [ruby/ruby#19662](https://github.com/ruby/ruby/pull/19662), ZJIT specializes `Hash.new` (`HashAlloc`, stock `initialize` elided for opt_new's own send). `Hash.new` 78 → 15 ns per call, but ruby-bench within noise; it was stacked on #19661, conflicted with master and was +937/−62 in 18 files. Closed with one neutral line; a smaller ZJIT-only version stays a candidate, not to be opened under the PR stop.
- **Closed unmerged by tekknolagi on 2026-11-03** ("Closing.", after the YJIT maintenance-mode decision): [ruby/ruby#19671](https://github.com/ruby/ruby/pull/19671), YJIT specializes `sendforward` (every Rails `delegate` method) when the caller passed no arguments — `send_forwarding` 75,134 → 0 per railsbench iteration (shipit 100,648 → 1,994), dynamic sends −5 to −9%, Callgrind instructions −0.47% railsbench / −1.08% shipit (A/A ≤ 0.25%); no wall-time claim. Bet J2 ([record](yjit-sendforward.md)). Astra approve-with-nits on both rubrics, tests extended; opened 2026-11-03.
- [IAPark/tiktoken_ruby#132](https://github.com/IAPark/tiktoken_ruby/pull/132) (magnus 0.8.2 → 0.8.4 for Ruby 4.1): closed 2026-11-03 by gjtorikian, who merged Dependabot's [#130](https://github.com/IAPark/tiktoken_ruby/pull/130) (magnus 0.9.0, open since 2026-10-01) instead. We missed #130 because only issues were searched. Main `e9f6f60` builds on master `b51db981f6` and passes 72/72 specs; no release yet (0.0.17 still fails). Bet E1.
- [cabo/cbor-ruby#43](https://github.com/cabo/cbor-ruby/pull/43), Ruby 4.1 compatibility: Buffer, Packer and Unpacker use TypedData instead of the removed `Data_Wrap_Struct`/`Data_Get_Struct` (fixes #42). cbor 0.5.10.3 does not compile on master; 5 of 20 census apps lock it (Discourse, Flow, Loomio, Mastodon, Sure, via webauthn → cose). 170 specs on 4.0.7 and master, plus a `GC.stress` loop. Astra approve-with-nits (`dsize` NULL, as before; offered as a follow-up), adversarial Sol approve. From the [ecosystem sweep](ruby-4.1-ecosystem.md) (bet E1). Opened 2026-11-03. **Closed 2026-11-03** in favor of nobu's earlier [#31](https://github.com/cabo/cbor-ruby/pull/31) (same conversion plus `dsize`, `TypedData_Make_Struct` and a 1.8 fallback), which we had missed; [comment](https://github.com/cabo/cbor-ruby/pull/43#issuecomment-6607960797) with #31's results on 4.0.7 and 4.1.0dev (170/170 specs, GC.stress, cose round trip).
- **Closed unmerged; checked on 2026-10-23:** [ruby/ruby#19478](https://github.com/ruby/ruby/pull/19478), ZJIT empty keyword-rest direct sends, closed in favor of [#19488](https://github.com/ruby/ruby/pull/19488), which carries both commits, at [k0kubun's suggestion](https://github.com/ruby/ruby/pull/19478#issuecomment-6353913049). This is consolidation, not a merge; the historical microbenchmark remains in the closed PR.
- **Closed unmerged by the author; checked on 2026-11-02:** [ruby/ruby#19488](https://github.com/ruby/ruby/pull/19488), the consolidated ZJIT empty/literal keyword-rest PR, closed 2026-10-26 following k0kubun's complexity concern ([closing comment](https://github.com/ruby/ruby/pull/19488#issuecomment-6423531796)): on ruby-bench the removed literal-keyword fallbacks are about **0.07%** of sends on railsbench and **0.03%** on shipit, the hottest affected callees save roughly 40 ns/call, and headline timings stay within A/A noise for ZJIT and YJIT. Its earlier fallback counts, micros and headline-fallback reply remain in the closed PR; they are not merged work.
- **Closed by the author on 2026-11-02:** [ruby/ruby#19625](https://github.com/ruby/ruby/pull/19625), ZJIT Ruby fast path for `Integer#step`: tekknolagi noted that ZJIT does not inline blocks and that without a measurable difference on any benchmark it is not worth merging; optcarrot showed 1.006 vs 1.001 A/A.
- **Closed unmerged; checked on 2026-11-02:** [ruby/ruby#19555](https://github.com/ruby/ruby/pull/19555), recompile once when a PatchPoint invalidates a ZJIT final version, closed in favor of another author's [#19617](https://github.com/ruby/ruby/pull/19617), which handles the same case.
- **Closed unmerged by the author; 2026-11-03:** [ruby/ruby#19667](https://github.com/ruby/ruby/pull/19667), keep the `opt_new` fast path for String/Array subclasses (SafeBuffer, SqlLiteral), closed after [jhawthorn's objection](https://github.com/ruby/ruby/pull/19667) to adding complexity to `vm_exec_core` for edge cases. Per call it was faster (`SafeBuffer.new` 410 → 303 ns YJIT), but ruby-bench headline timing stayed within A/A noise, so it did not meet our own bar either. A JIT-only variant was not pursued because it would make interpreter and JIT differ on visibility and refinements.

## Queue

Prepared candidates waiting for room or a gate (rules in [DECISIONS](../DECISIONS.md#submission-queue-2026-11-03)).

| Candidate | Repo | Branch @ SHA | Effect | Status |
| --- | --- | --- | --- | --- |
| GC: restore the slot-count incremental sweep pool budget (4.1 regression 2) | ruby/ruby | [`thomasklemm/gc-pool-budget`](https://github.com/thomasklemm/ruby/tree/thomasklemm/gc-pool-budget) @ `4b02fa55cb` on master `9b30fd207f` (first version `gc-pool-budget-slots` @ `a06b86d852`) | master vs master+fix, 97 workloads: major GCs 86 → 13 (interp), 98 → 26 (YJIT); GC time −15% / −23%; RSS +1.7–3.3 MB per workload window; sweep pause p99 +4% / +12%, maximum unchanged; ruby-bench shipit majors 25 → 6 / 27 → 5 ([watch](ruby-4.1-regression-watch.md#2-sparse-large-slot-heaps-force-nofree-major-gcs)) | Candidate, not opened: no new ruby/ruby PRs for now (DECISIONS, 2026-11-03). Step-size objection measured; body and explanation drafted. No reply on ruby/ruby#17251. |
| i18n C2, C3: Symbol defaults/links without merge; early return on a missing Symbol key | ruby-i18n/i18n | `resolve-symbols-without-merge` @ `3bef11d6e3`, `lookup-symbol-miss` @ `b82af9eeae` | −2.5 and −2.3 objects per workload, 4–5 apps | Held: small, and #763–#766 have no maintainer response yet. Revisit after the first one. |
| E2: SQLite schema readers find tables by any ASCII case | rails/rails | [`thomasklemm/sqlite-schema-readers-table-name-case`](https://github.com/thomasklemm/rails/tree/thomasklemm/sqlite-schema-readers-table-name-case) @ `8f41f1c9c3` on main `8b06b0eb98` | table `Widgets` read as `widgets` works again (columns, primary key, indexes, foreign keys, views); ransack's `context_spec.rb:80` | Ready, Sol: open with nits |
| E2b: a temporary SQLite table or view hides the permanent one in the schema readers | rails/rails | [`thomasklemm/sqlite-schema-readers-temp-shadowing`](https://github.com/thomasklemm/rails/tree/thomasklemm/sqlite-schema-readers-temp-shadowing) @ `3923e11a71` on main `8b06b0eb98` | columns and indexes no longer duplicated, primary key no longer composite; temp indexes and triggers hide nothing | Ready, Sol: open with nits (applied); at the end of the PR queue. Whichever of E2/E2b lands second adds `COLLATE NOCASE` to the hiding check |
| E3: deprecate `ActiveSupport::LogSubscriber.colorize_logging` | rails/rails | [`thomasklemm/log-subscriber-colorize-logging-deprecation`](https://github.com/thomasklemm/rails/tree/thomasklemm/log-subscriber-colorize-logging-deprecation) @ `8672567e15` on main `8b06b0eb98` | awesome_print 1.9.2 loads again; administrate boots | Ready, Sol: open with nits |
| E4: Active Support requires minitest 5.18 | rails/rails | [`thomasklemm/activesupport-minitest-floor`](https://github.com/thomasklemm/rails/tree/thomasklemm/activesupport-minitest-floor) @ `0a69eb6cce` on main `8b06b0eb98` | Bundler reports a conflict instead of a NameError in `active_support/test_case` | Ready, Sol: open with nits |

### Erklärungen für Thomas: E1–E4, E2b und G1 (2026-11-04, Ecosystem-Tests; E1 als #59623 geschlossen, durch G1 ersetzt; G1 geöffnet als ransack#1792)

Ergebnisse aller 24 Suites, Ursachen und Leads: [ecosystem-tests](ecosystem-tests.md).

**E1, fehlendes `require` (ersetzt).** `WeakSet` liegt seit 3c77803ec0 in einer eigenen Datei, die nur per Autoload aus `active_support.rb` kommt. skipkayhil hat #59623 geschlossen: Wer Core-Extensions einzeln lädt, muss vorher `active_support` laden, das ist der dokumentierte Vertrag. 

**G1, ransack.** Deshalb gehört der Fix zu ransack: `lib/ransack.rb` lädt jetzt `active_support` vor `active_support/core_ext`. Damit lädt ransack auf Rails main wieder, und auf 8-1-stable und 8.1.0 ändert sich nichts.

**E2, Groß-/Kleinschreibung bei SQLite.** Seit 2cb3daba96 liest Rails das Schema vieler Tabellen in einer Abfrage, vergleicht die Namen dabei aber exakt; SQLite selbst ignoriert bei Namen die ASCII-Schreibweise. Mit `COLLATE NOCASE` und Zeilen pro angefragtem Namen findet `widgets` wieder die Tabelle `Widgets`. `Ärger` und `ärger` bleiben zwei Tabellen, wie in SQLite.

**E2b, temporäre Tabellen.** Dieselbe Abfrage listet eine temporäre Tabelle und die gleichnamige permanente, und beide Zeilen lösen auf die temporäre auf. So kommen Spalten und Indizes doppelt zurück, und der Primärschlüssel wird zusammengesetzt. Jetzt verdeckt eine temporäre Tabelle oder View die permanente, wie bei SQLite selbst; temporäre Indizes und Trigger verdecken nichts, und auch die Collation kommt aus dem CREATE-Statement der temporären Tabelle.

**E3, `colorize_logging`.** aebcb61520 hat den Klassen-Accessor von `LogSubscriber` ohne Deprecation entfernt. awesome_print 1.9.2 liest ihn beim Laden, deshalb bootet z. B. administrate nicht mehr. Er kommt als veralteter Delegator auf `ActiveSupport.colorize_logging` zurück und warnt bis zur Entfernung in Rails 9.0.

**E4, minitest-Untergrenze.** 23420be739 nutzt `refute_pattern`, das es erst ab minitest 5.18 gibt, aber das Gemspec erlaubt noch 5.1. Die ehrliche Untergrenze `>= 5.18` lässt Bundler den Konflikt melden, statt dass `active_support/test_case` mit einem NameError abbricht.

### Erklärungen für Thomas: AP-1 und AP-2 (2026-11-04, Action Pack; geöffnet als #59619 und #59620)

Aufzeichnung, Belege und Reviews: [actionpack-request-path](actionpack-request-path.md).

**AP-1, Routen-Format (#59619).** Wenn Rails einen Pfad wie `post_path(post)` erzeugt, hängt es die Teile der Route
einzeln an einen String an, und der Parser liefert für `/posts/:id` die Stücke `"/"`, `"posts"`, `"/"` getrennt. Jetzt
werden benachbarte feste Stücke einmal beim Laden der Routen zu `"/posts/"` zusammengefügt. Außerdem merkt sich das
Format die Parameter selbst statt ihrer Positionen und prüft sie mit `any?`; das alte `return` aus einem `each`-Block
legte jedes Mal ein Objekt an, wenn eine optionale Gruppe wie `(.:format)` wegfiel. Zusammen: etwa 8% weniger Zeit
pro `post_path`, ein Objekt weniger, gleiche URLs bis aufs Byte; das Bauen einer Route kostet etwa 2 µs mehr.

```ruby
["/", "posts", "/", :id]   # vorher: drei Strings anhängen, dann die id
["/posts/", :id]           # jetzt: einer, einmal beim Bauen der Route zusammengefügt
```

**AP-2, Renderer-Set (#59620).** Bei jedem `render` prüft Rails, ob eine Option wie `json:` gesetzt ist, und baut dafür
auf main seit #57830 (noch nicht released) jedes Mal ein neues Set aus den eigenen Renderern des Controllers und den
eingebauten. Fast jeder Controller hat keine eigenen, dann ist das neue Set nur eine Kopie der eingebauten; jetzt nimmt
Rails in diesem Fall direkt das eingebaute, eingefrorene Set. Einzige sichtbare Änderung: wer `_all_renderers`
überschreibt und `super.delete(:json)` aufruft, bekommt jetzt `FrozenError`.

```ruby
_renderers + Renderers.all                                     # vorher: bei jedem render ein neues Set
_renderers.empty? ? Renderers.all : _renderers + Renderers.all # jetzt (als if/else): Kopie nur, wenn nötig
```

#### AP-1 PR-Text (wie gepostet, nach der Überarbeitung)

Title: Join adjacent literals when building a route's path format

`Journey::Format` now joins each run of adjacent literals once, when the route is built, so generating `/posts/:id` appends `"/posts/"` instead of `"/"`, `"posts"` and `"/"`. It also keeps its parameters themselves instead of their indexes and checks them with `any?`: on main, returning from the `each` block allocated an object whenever an optional group like `(.:format)` was skipped. The unused `@children` is gone.

URLs generated from Rails-built routes are unchanged: the parser's literals are its ASCII `/` and `.` or slices of the route path, so the joined string has the same bytes and encoding. Hand-built `Format.new` arrays could notice the new internal `@parts` (mutating the input afterwards, mixed-encoding literals failing at construction, String subclasses normalised). Building a format costs about 19% more instructions (2 µs per route); formats retain less memory than before.

`post_path(post)` per call, Ruby 4.0.9:

| | main | this |
| --- | ---: | ---: |
| objects | 7 | 6 |
| interpreter | 4,336 ns, 34,472 instructions | 3,988 ns (−8.0%), 31,855 (−7.6%) |
| YJIT | 2,005 ns, 15,571 instructions | 1,880 ns (−6.2%), 14,840 (−4.7%) |

`posts_path` saves 6.1% / 5.9% of instructions; `root_path` (one literal) is unchanged. Measured with Lowrail, my research project ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionpack-request-path.md#ap-1-join-adjacent-literals-when-building-a-routes-format)).

#### AP-2 PR-Text (wie gepostet)

Title: Don't build a Set of renderers on every render

When a controller has no local renderers, `_all_renderers` now returns `Renderers.all` itself instead of building `_renderers + Renderers.all`, an identical copy, on each render. Controllers with `use_renderers`, and their subclasses, still get the union with their renderers first.

#57830 worked toward Ractor safety by replacing the registry with a new frozen Set on every `add` and `remove`, so the result has the same renderers in the same order and stays a snapshot while it is iterated. One contract changes: on this path the internal method returns the shared frozen registry rather than a fresh Set, so an override calling `super.delete(:json)` would raise `FrozenError`. Rails only iterates the result, and the union is unreleased.

Per call in a controller without local renderers, Ruby 4.0.9:

| | main | this |
| --- | ---: | ---: |
| renderer check of a template render, interpreter / YJIT | 1,354 / 1,165 ns | 801 / 552 ns |
| `render json:`, interpreter / YJIT | 3,928 / 2,658 ns | 3,274 / 2,001 ns |
| objects, check / `render json:` | 3 / 9 | 2 / 8 |

Tests cover Base and API without local renderers, inherited local renderers, and renderers added or removed between renders. Measured with Lowrail, my research project ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/actionpack-request-path.md#ap-2-no-set-union-on-every-render)).

### Erklärung für Thomas: AS-1 (2026-11-04, Active Storage; #59615 gemergt)

Messungen, Review, PR-Text und die abgelehnten Stellen: [background-census](background-census.md).

**AS-1, Dateiendung einmal lesen.** Jede `variant` eines Web-Bilds (PNG, JPEG, GIF) bestimmt ihr Standardformat in
`Representable#format`, und das fragte bis zu dreimal `filename.extension` ab; jeder Aufruf baut ein neues
`ActiveStorage::Filename` und bereinigt seit dem Security-Fix `0e6a6afe3c` den ganzen Namen neu (`encode`, `strip`,
`tr`). Jetzt steht die Endung einmal in einer lokalen Variablen; Marcel liest sie nur und das Ergebnis ist derselbe
String-Inhalt, deshalb wählt Rails mit der normalen Filename-Implementierung dasselbe Format, nur 22 Objekte und ein Drittel der
Instruktionen pro `variant` weniger.

```ruby
filename.extension.present? && Marcel::MimeType.for(extension: filename.extension) == content_type  # vorher: 3x bereinigen
extension = filename.extension                                                                     # jetzt: 1x
```

### Erklärungen für Thomas: N1 und H1 (2026-11-04, Active Support; geöffnet als #59613 und #59614)

PR-Texte, Messungen und Reviews: [as-request-paths](as-request-paths.md#pr-bodies-as-opened).

**N1, Notification-Handle ohne `Hash#map`.** Jedes `instrument` mit einem aktiven Subscriber (jede SQL-Abfrage, weil
Active Records Laufzeitzähler immer zuhört) baut in `build_handle` pro Subscriber-Gruppe ein Objekt, bisher mit
`groups.map`. Ein Hash hat kein eigenes `map`; das `map` aus Enumerable legt bei jedem Aufruf einen internen Block an
und ruft unseren Block über C auf. Jetzt füllt `each` mit `<<` ein leeres Array, wie `groups_for` direkt darüber:
dieselben Gruppen in derselben Reihenfolge, ein Objekt weniger und 5–11 % weniger Instruktionen pro Event; merken
würde es nur, wer das interne `groups_for` überschreibt und einen Hash mit eigenem `map` zurückgibt.

```ruby
groups = { TimedGroup => [sub] }
groups.map { |k, v| k.new(v) }                       # vorher: Enumerable#map, interner Block pro Aufruf
list = []; groups.each { |k, v| list << k.new(v) }   # jetzt: dasselbe Array, ohne den Umweg
```

**H1, `Hash#extract!` ohne `each_with_object`.** `stylesheet_link_tag` und `javascript_include_tag` holen bei jedem
Aufruf vier mögliche Optionen mit `extract!` aus den Optionen, meist ist keine davon gesetzt. `extract!` lief über
`each_with_object` aus Enumerable, mit demselben internen Block wie oben. Jetzt legt es ein leeres Ergebnis an, geht
die Schlüssel mit `each` durch und gibt das Ergebnis zurück; der Hash bekommt dieselben `has_key?`- und `delete`-Aufrufe, das
neue Ergebnis dieselben `[]=`-Aufrufe, in derselben Reihenfolge; nur Backtraces aus diesen Methoden haben einen Frame weniger.

```ruby
opts = { "media" => "all" }
%w[host].each_with_object({}) { |k, r| r[k] = opts.delete(k) if opts.key?(k) }  # vorher
r = {}; %w[host].each { |k| r[k] = opts.delete(k) if opts.key?(k) }; r          # jetzt: dasselbe {}
```

### Erklärungen für Thomas: I1 und IW (2026-11-04, Bugfixes; I1 geöffnet als #59609, IW als Lead geparkt)

Triage, Prüfungen und PR-Text: [rails-issue-fixes](rails-issue-fixes.md).

**I1, gruppierte Zählung über eine Subquery (rails/rails#48420).** Wer nach einer Spalte aus einer gejointen Subquery
oder CTE gruppiert, etwa `group("ranges.range").count`, bekommt seit Rails 7.0.5 die Schlüssel als rohe Strings
statt als Range, Date oder Boolean. Rails nimmt den Typ seitdem zuerst von der Gruppenspalte, und für eine Tabelle,
die das Schema nicht kennt, ist das nur der Platzhalter-Typ, der nichts umwandelt; jetzt nimmt Rails genau in diesem
Fall den Typ, den die Datenbank für das Ergebnis meldet, wie vor 7.0.5, und Spalten bekannter Tabellen behalten
ihren Typ.

```ruby
Booking.joins("JOIN (SELECT tsrange(...) AS range) ranges ON TRUE").group("ranges.range").count
# vorher: { "[\"2020-01-01 00:00:00\",\"2020-01-02 00:00:00\")" => 1 }
# jetzt:  { 2020-01-01 00:00:00 UTC...2020-01-02 00:00:00 UTC => 1 }
```

**IW, `index_with` auf Array-Unterklassen.** Seit byroots 2b88dc1995 (noch nicht released) baut `Array#index_with`
den Hash mit `Array#to_h`, das die gespeicherten Elemente direkt liest; eine Unterklasse, die `each` überschreibt,
bekommt deshalb andere Schlüssel als in 8.1. Der Fix schickt Unterklassen wieder über `each`, kostet aber bei jedem
normalen Array (also bei jeder Query) etwa 5% mehr Instruktionen, für einen Fall, den auch Rubys eigenes `map` oder
`to_h` nicht beachten; deshalb empfehle ich, ihn nicht zu öffnen.

```ruby
class Tens < Array; def each = super { |x| yield x * 10 }; end
Tens[1, 2].index_with { _1 }   # 8.1: {10=>10, 20=>20}, main: {1=>1, 2=>2}
Tens[1, 2].map { _1 }          # in beiden: [1, 2], Array-Methoden ignorieren das eigene each
```

### Erklärungen für Thomas: W2 und W3 (2026-11-04, fertig; PR-Erstellung gesperrt)

Aufzeichnung und PR-Texte: [ar-write-paths](ar-write-paths.md).

**W2, Zeitstempel beim Update.** Bei jedem `update` läuft die Methode, die `updated_at` setzt, zweimal: einmal vor
und einmal nach den `before_update`-Callbacks, damit auch Änderungen aus einem Callback einen frischen Zeitstempel
bekommen. Beim zweiten Durchlauf ist `updated_at` meist schon gesetzt, er schreibt also nichts, hat aber trotzdem
vorher die Uhrzeit geholt (und dafür die Datenbankverbindung nach ihrer Zeitzone gefragt). Jetzt wird die Zeit erst
geholt, wenn wirklich eine Spalte geschrieben wird; ein Update wird so etwa 1–1,5% billiger, und `updated_at` und
`updated_on` bekommen weiter dieselbe Zeit.

```ruby
current_time = current_time_from_proper_timezone      # vorher: immer, auch wenn nichts geschrieben wird
current_time ||= current_time_from_proper_timezone    # jetzt: erst vor dem ersten Schreiben
```

**W3, `SELECT posts.*` ohne Hilfs-Array.** Jede Abfrage, die alle Spalten lädt, baut `SELECT "posts".*` über
`arel.project(table[Arel.star])`. Weil `project` beliebig viele Argumente nimmt (`*projections`), legt Ruby bei jedem
Aufruf ein Array mit diesem einen Element an. Jetzt wird das Element direkt an die Liste gehängt; `project` hätte
damit ohnehin nichts weiter gemacht, weil es nur Strings und Symbole umwandelt. Ein Objekt weniger pro geladener
Relation, in allen 20 Apps.

```ruby
arel.project(table[Arel.star])        # vorher: [node] als Splat-Array, dann concat
arel.projections << table[Arel.star]  # jetzt: direkt angehängt
```

### Erklärung für Thomas: AR-1 (2026-11-04, nicht geöffnet)

Aufzeichnung und PR-Text: [ar-request-paths](ar-request-paths.md).

**AR-1, SQLite3: Type Map einmal pro Ergebnis.** Wenn der SQLite3-Adapter ein Abfrageergebnis baut, sucht er für
jede Spalte den Typ in der Type Map; die holt er sich über die Methode `type_map`, die jedes Mal prüft, ob in der
Datenbank-Config eine eigene `default_timezone` steht, und dann die Konstante liest (mit Zeitzone in der Config
sogar einen Hash baut und in einem `Concurrent::Map` nachschlägt). Das passierte für jede Spalte neu, obwohl immer
dieselbe Map herauskommt; jetzt wird sie einmal pro Ergebnis geholt. `Post.find` wird so etwa 2% billiger
(mit Zeitzone in `database.yml` 15–24%); anders sieht es nur ein Override von `type_map`, der seine eigenen
Aufrufe zählt.

```ruby
stmt.types.map { |t| type_map.lookup(t) }          # vorher: type_map bei jeder Spalte
result_type_map = type_map                          # jetzt: einmal pro Ergebnis
stmt.types.map { |t| result_type_map.lookup(t) }
### Erklärung für Thomas: TC-1 (2026-11-04, Active Support; geöffnet als #59617)

**TC-1, `Time#change` in der doppelten Stunde.** Wenn die Uhr im Herbst zurückgestellt wird, gibt es eine Stunde
zweimal; `change` baut die neue Zeit mit `Time.new(..., zone)`, und eine `TZInfo::Timezone` wirft dafür
`AmbiguousTime`, weil sie nicht weiß, welche der beiden gemeint ist (auch Active Models Präzisions-Cast ruft
`change(nsec:)` und wirft dann); bei Dublin wählt die Zone die falsche und die Zeit springt um eine Stunde. Jetzt
probiert `change` zuerst den alten UTC-Offset: Stimmt die Zone zu, ist es genau die gemeinte Zeit, sonst entscheidet
die Zone wie bisher; über alle Zeitumstellungen bis 2037 ändert sich das Ergebnis nur in diesen Fehlerfällen.

```ruby
t = Time.utc(2026, 10, 25, 0, 30).getlocal(TZInfo::Timezone.get("Europe/Berlin"))  # 02:30 +0200
t.change(sec: 1)   # vorher: TZInfo::AmbiguousTime, jetzt: 02:30:01 +0200
```

### Erklärung für Thomas: TH-1 (2026-11-04, Action View; geöffnet als #59606)

Aufzeichnung, Belege und PR-Text: [census-backlog](census-backlog.md#th-1-restore-the-template-handler-lookup-methods).

**TH-1, drei Template-Handler-Methoden zurück.** Als Rails die Liste der Template-Handler für Ractors auf
eingefrorene Daten umgestellt hat (#57874, noch nicht released), sind drei Methoden auf `ActionView::Template`
nebenbei weggefallen, darunter `registered_template_handler(:erb)`, mit der sich Markdown-Handler wie maildown den
ERB-Handler holen; auf main bricht deshalb jedes `.md`-Template beim ersten Kompilieren mit `NoMethodError` ab
(im Census die Mails von CodeTriage). Die drei Methoden kommen als Einzeiler zurück, die nur an die neue Liste
weiterreichen und für jede getestete Eingabe dasselbe liefern wie Rails 8.1; am Render-Pfad ändert sich nichts.

```ruby
ActionView::Template.registered_template_handler(:erb)   # 8.1: der ERB-Handler, main: NoMethodError
ActionView::Template::Handlers.template_handlers[:erb]   # neu: genau das macht die Methode jetzt
```

### Erklärungen für Thomas: T1 und T2 (2026-11-04, Action View; T1 als #59603 gemergt, T2 als Lead geparkt)

Aufzeichnung und PR-Texte: [actionview-render-c10](actionview-render-c10.md#pr-bodies-reviewed-drafts).

**T1, String-Attribute zuerst.** Jedes Attribut, das `tag.*`, `content_tag`, `link_to` oder ein Formular-Helper
schreibt, läuft durch `append_tag_option`, und dessen `case` prüfte jeden Wert erst gegen Array, Hash, Regexp und
Symbol, bevor ein String im `else` landete; in den Apps sind aber 90–98 % der Werte Strings. Ein `when String` ganz
vorne mit genau dem Code aus `else` spart drei Klassenprüfungen pro String-Attribut; ein String kann keine der
anderen Klassen sein, deshalb wird alles genau wie vorher escaped, nur Nicht-Strings zahlen eine Prüfung mehr.

```ruby
case "card"                       # vorher: Array? Hash? Regexp? Symbol? dann else
when String then escape("card")   # jetzt: sofort hier, gleicher Code wie else
```

**T2, Array-Attribute ohne SafeBuffer.** Bei `class: ["btn", "active"]` rief Rails `safe_join` auf, das den
zusammengefügten String in einen neuen SafeBuffer packt, und hängte ihn dann an einen normalen String an, wo das
„html_safe" keine Rolle spielt. Jetzt werden die Werte direkt escaped und mit Leerzeichen verbunden, wie es
`token_list` in derselben Datei schon tut; nur wer `safe_join` in seiner View überschreibt, sieht diese Werte nicht
mehr.

```ruby
view.safe_join(["btn", "<x>"], " ")                               # vorher: SafeBuffer, sofort weggeworfen
["btn", "<x>"].flatten.map! { ERB::Util.unwrapped_html_escape(_1) }.join(" ")  # jetzt: derselbe Text, ein String
```

### Erklärungen für Thomas: K1 und N1 (2026-11-04, Gems; geöffnet als rack/rack#2550 und sparklemotion/nokogiri#3759)

Aufzeichnung und PR-Texte: [gem-request-census-2](gem-request-census-2.md).

**K1, rack: Cookie-Wert ohne Hilfs-Array escapen.** Jedes `Set-Cookie`, das Rails schreibt (Session-Cookie und alle
anderen), läuft durch `Rack::Utils.set_cookie_header`. Die Methode packte einen einzelnen Wert erst in ein Array, ließ
`escape` per `map` darüber laufen und fügte das Ergebnis mit `join` wieder zusammen; dabei entstehen zwei Arrays und
ein String, die sofort weggeworfen werden. Jetzt wird ein einzelner Wert direkt escaped, Arrays laufen wie bisher;
der Header ist mit dem normalen `escape` für jeden Wert derselbe, nur ein `escape`-Override, das keinen String
zurückgibt, würde es merken.

```ruby
v = "a b;c"
[v].map { |x| Rack::Utils.escape(x) }.join("&")   # vorher: Array, Array, String, dann das Ergebnis
Rack::Utils.escape(v)                             # jetzt: nur das Ergebnis, "a+b%3Bc"
```

**N1, nokogiri: `children` einmal statt zweimal.** `DocumentFragment#css` fragte `children.any?` und suchte dann in
einem zweiten `children`; jeder Aufruf baut eine neue NodeSet und schickt sie durch die Decorators des Dokuments
(bei Loofah heißt das `extend` mit einem Modul, also eine eigene Singleton-Klasse). Jetzt wird die erste NodeSet
behalten und durchsucht; das Ergebnis ist dasselbe, weil zwischen den beiden Aufrufen nichts passiert. Action Text
ruft das beim Rendern von Rich Text auf.

```ruby
frag = Nokogiri::HTML5.fragment("<p><a href='/x'>x</a></p>")
frag.children.any? && frag.children.css("a")      # vorher: zwei NodeSets
(nodes = frag.children).any? && nodes.css("a")    # jetzt: eine
```

### Erklärungen für Thomas: CP-1 und CP-2 (2026-11-04; geöffnet als #59596 und #59597, beide gemergt)

PR-Texte: [rails-common-paths](rails-common-paths.md#pr-bodies-as-opened). Beide wurden am 2026-11-04 geöffnet
und am selben Morgen von amatsuda gemergt (rails/rails#59596, rails/rails#59597).

**CP-1, Statement Cache.** `Post.find(id)`, `find_by` und viele Assoziations-Reads laufen über den Statement Cache:
Rails baut das SQL einmal und merkt es sich. Bei jeder Ausführung gibt es diesen String an `to_sql_and_binds`
weiter, und das kopiert jeden noch nicht eingefrorenen String vorsorglich (`dup.freeze`), damit sich das SQL später
nicht ändern kann. Weil der gecachte String nie eingefroren war, wurde dasselbe SQL bei jeder Abfrage neu kopiert,
zwei Objekte pro Query; jetzt wird es einmal beim Cachen eingefroren. Sicher ist das, weil der String Rails selbst
gehört und nach dem Einfrieren nur noch gelesen wird; sichtbar wird es nur für Code, der denselben String in einem
eigenen `find_by_sql`-Override verändert (der veränderte auf main schon den Cache selbst, das wird jetzt zu einem
`FrozenError`).

```ruby
sql = +"SELECT * FROM posts WHERE id = ?"   # gecacht, nicht frozen
3.times { sql.dup.freeze }                   # vorher: bei jedem find eine Kopie
sql.freeze                                   # jetzt: einmal beim Cachen
3.times { sql.frozen? ? sql : sql.dup.freeze } # keine Kopie mehr
```

**CP-2, allow_browser.** Jede neue App hat `allow_browser versions: :modern` im `ApplicationController`, also prüft
jeder Request mit User-Agent die Browser-Version. Dafür wurde die feste Tabelle `:modern` bei jedem Request in einen
`HashWithIndifferentAccess` umgewandelt, obwohl das Ergebnis immer gleich ist. Jetzt passiert das einmal beim Laden
der Klasse, das Ergebnis ist eingefroren; Hashes, die die App selbst übergibt, werden weiter bei jedem Request
umgewandelt, damit Änderungen daran sichtbar bleiben. Ein Check wird so um etwa 3,5 µs (Interpreter) bzw. 1 µs
(YJIT) schneller; der Rest der Zeit ist das Parsen des User-Agents.

```ruby
SETS = { modern: { chrome: 120, firefox: 121 }.freeze }.freeze
SETS[:modern].with_indifferent_access["firefox"]   # vorher: pro Request neu gebaut
EXPANDED = SETS.transform_values { _1.with_indifferent_access.freeze }.freeze
EXPANDED[:modern]["firefox"]                        # jetzt: einmal gebaut, nur gelesen
```

### CP-3 und CP-5: PR-Texte und Erklärungen für Thomas (2026-11-04; CP-3 geöffnet als #59607 und gemergt, CP-5 verworfen)

CP-3 wurde am 2026-11-04 als rails/rails#59607 geöffnet und um 13:57 UTC von amatsuda gemergt. CP-5 wurde nach Sols zweiter Runde verworfen: der verankerte Regex braucht bei langen sicheren Segmenten etwa 47 Bytes Match-Stack pro Zeichen (10 Mio. Zeichen: 492 MB statt 24 MB Spitze), und keine verankerte Form vermeidet das. Messungen,
Reviews und Ablehnungen: [rails-common-paths-2](rails-common-paths-2.md).

**CP-3, Alias-Lookup.** Jede `where`-Bedingung fragt `type_for_attribute` nach dem Typ der Spalte, und das prüft
zuerst, ob der Name ein Alias ist (`alias_attribute`), mit `attribute_aliases.fetch(super, &:itself)`: im Normalfall
ohne Alias ruft Ruby dafür einen Block über `Symbol#to_proc` auf, was mehr kostet als der Lookup selbst. Jetzt steht
dort `attribute_aliases.fetch(name = super, name)`: der Name ist einfach der Default von `fetch`, ohne Block. Sicher
ist das, weil es weiter `fetch` ist (Hash-Defaults und gespeicherte `nil` wirken wie vorher) und die Alias-Tabelle
weiter vor `super` gelesen wird; Sols Review hatte gezeigt, dass die erste Fassung (`[] || name`) genau daran
abwich.

```ruby
aliases = { "headline" => "title" }.freeze
aliases.fetch("body", &:itself)   # vorher: "body", über einen Block-Aufruf
aliases.fetch("body", "body")     # jetzt: "body", Default statt Block
```

**CP-5, URL-Escaping.** Jeder URL-Helper (`post_path(@post)`) prüft jedes Segment, ob es escaped werden muss; meist
nicht (IDs, Slugs). Bisher suchte Rails nach einem unsicheren Zeichen (`/[^…]/`), und die Regex-Engine setzt diese
Suche an jeder Position neu an; jetzt prüft es in einem Durchlauf, ob der ganze String nur aus sicheren Zeichen
besteht (`/\A[…]*\z/`, dieselben Zeichenlisten). Das ist für jeden gültigen String dieselbe Aussage, auch die
Fehler bei kaputten Bytes sind gleich, und die Tests prüfen jetzt, dass sichere Segmente als dasselbe Objekt
zurückkommen und jedes Zeichen über beide Wege dasselbe ergibt, sodass eine zu enge oder zu weite Liste auffällt;
langsamer wird es erst bei Segmenten über etwa 600.000 Zeichen (dann greift ein knappes `Regexp.timeout` früher).

```ruby
UNSAFE = /[^a-z0-9-]/; SAFE = /\A[a-z0-9-]*\z/
"my-post".match?(UNSAFE)   # vorher: false, also nichts zu escapen (Suche ab jeder Position)
"my-post".match?(SAFE)     # jetzt: true, also nichts zu escapen (ein Durchlauf)
```

#### CP-3 body: Resolve attribute aliases with a fetch default instead of a block

> Active Record looks up a column's type with `type_for_attribute` several times for each condition in `where`, and on association reads, creates and updates; `Post.where(title:, published:).to_a` calls it eight times. Each lookup first resolves an alias with `attribute_aliases.fetch(super, &:itself)`. For the usual name without an alias, `fetch` then calls its block, and `&:itself` makes that a `Symbol#to_proc` call, which costs more than the lookup itself.
>
> This passes the resolved name as `fetch`'s default instead: `attribute_aliases.fetch(name = super, name)`. It is still `fetch`, so a Hash default or a stored `nil` is treated as before, and the receiver is still read before `super` converts the name, so even a `to_s` that defines an alias sees the same table. Rails already assigns inside a `fetch` argument this way in `calculations.rb`.
>
> | `Post.type_for_attribute("title")`, per call | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: |
> | main | 641 ns | 384 ns | 5,455 | 3,769 | 3,243 |
> | this PR | 561 ns (−12.5%) | 293 ns (−23.7%) | 4,788 (−12.2%) | 2,925 (−22.4%) | 2,305 (−28.9%) |
> | main, run again (change from the first run) | +1.3% | +0.3% | −0.00% | −0.13% | +0.04% |
>
> Objects per call are unchanged. Ruby 4.0.9, SQLite in memory, GC disabled; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths_2/micro.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 calls minus its count for none, divided by 3,000, median of three runs. The two-condition `where` above runs 0.47% fewer instructions interpreted and about 1.4% fewer with YJIT. On ruby-bench (Rails 8.1 with the method patched in), shipit (about 21,600 lookups per iteration) runs 0.11% fewer instructions per iteration with the interpreter; railsbench, which makes no lookups, moves by up to 0.08% between two builds, so smaller changes there are noise. In a CPU census of 20 open-source Rails apps on Rails main, this lookup ran in all 20 and took 0.18% of interpreted instructions (0.39% with YJIT); I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths-2.md)).

#### CP-5 body: Check URL components for unsafe characters with an anchored match

> Every URL helper escapes each dynamic segment through `UriEncoder#escape`, and since #59058 it returns a segment as is when nothing in it needs escaping, which is nearly always (ids, slugs). It finds that out by searching for an unsafe character with a negated class such as `/[^...]/`, which the regexp engine tries again from every position.
>
> This matches the whole component against the safe characters instead, with `/\A[...]*\z/` built from the same character lists, as `xml_name_escape` does with `SAFE_XML_TAG_NAME_REGEXP`. For every valid string in an ASCII-compatible encoding, one pattern matches exactly when the other doesn't; invalid bytes and incompatible encodings raise the same errors in both, and components that need escaping go through the same `gsub` as before. Measured in wall time, only components longer than about 600,000 characters take longer than before (2–3×), so with a global `Regexp.timeout` such components time out sooner; URL components that long don't occur in practice. The new tests check that safe components come back as the same object and that every ASCII character gives the same result through the early return as through escaping, so a safe pattern narrower or wider than its escaping pattern fails them. As before, a component that overrides `match?` itself can change the result, now in the opposite direction.
>
> | `page_path("my-first-post-about-rails")` (`get "/pages/:slug"`), per call | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT | Instructions, ZJIT |
> | --- | ---: | ---: | ---: | ---: | ---: |
> | main | 4,870 ns | 2,767 ns | 37,570 | 20,624 | 26,896 |
> | this PR | 4,777 ns (−1.9%) | 2,449 ns (−11.5%) | 34,465 (−8.3%) | 17,435 (−15.5%) | 23,936 (−11.0%) |
> | main, run again (change from the first run) | +0.7% | +0.3% | +0.10% | −0.02% | −0.00% |
>
> Objects per call are unchanged. Ruby 4.0.9, GC disabled; ZJIT on Ruby master 9aa0898240 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/common_paths_2/micro_url.rb)). Times are medians of 15 runs in rotating order on one CPU; instructions are Callgrind's count for 3,000 calls minus its count for none, divided by 3,000. `escape_segment` itself runs 42% fewer instructions for that slug and 11% fewer for `"123"` (interpreter), and `post_path(post)` with an id 1.1% fewer interpreted and 2.5% fewer with YJIT, against A/As of 0.13% and 0.26%. On ruby-bench (Rails 8.1 with the method patched in), only shipit moves clearly beyond the noise between two builds (up to 0.1% here): 0.13% fewer instructions per iteration with the interpreter and 0.31% fewer with YJIT. railsbench's 9,670 escapes per iteration are numeric ids, which save about 350 instructions each, about 0.05% of an iteration. In a CPU census of 20 open-source Rails apps on Rails main, this check ran in 12 and took 0.10% of interpreted instructions; I found it there with Lowrail, my research project ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-common-paths-2.md)).

### R1: Erklärung für Thomas (2026-11-04, Ruby 4.1; geöffnet als #59611)

Aufzeichnung, Prüfung und PR-Text: [ruby-4.1-readiness](ruby-4.1-readiness.md#r1-declare-prism-as-a-dependency).

**R1, prism als Abhängigkeit.** In Ruby 4.1 ist prism kein Default-Gem mehr, sondern ein Bundled Gem: unter Bundler
lässt es sich nur noch laden, wenn es im Bundle steht. Rails main lädt prism in Action View (Template-Digests,
Eager Loading) und in Railties (Test-Runner, `bin/rails notes`), deklariert es aber nicht; Apps bekommen es heute nur
zufällig über minitest 6, irb oder rdoc, und ohne die gibt es auf 4.1 einen `LoadError`. Die Änderung trägt
`prism` ohne Version in beide Gemspecs ein, genau wie Rails es für `cgi` und `tsort` gemacht hat; alle prism-APIs,
die Rails aufruft, gibt es schon in der Version, die Ruby 3.3 mitbringt.

```ruby
# Gemfile ohne minitest 6 / irb ≥ 1.17 / rdoc, Ruby 4.1:
ActionView.eager_load!   # vorher: LoadError: cannot load such file -- prism
                         # jetzt: prism kommt über actionview.gemspec ins Bundle
```

## Open

All entries in this section are **open, not merged; checked on 2026-11-02**, and rechecked against live GitHub (state, draft, head, CI, comments) on 2026-11-04 09:00 UTC ([status check](#status-check-2026-11-04-0900-utc)).
Measurements are the PRs' own, from their original dates.

### Status check (2026-11-04, 09:00 UTC)

Every open PR by thomasklemm outside `thomasklemm/*`, from `gh search prs --author thomasklemm --state open` at
09:00 UTC, with each thread's comments, reviews, inline comments, check runs on the exact head and mergeability.
"Awaiting approval" means the fork's workflow runs wait for a maintainer to approve them (`action_required`); we
don't ask. Not Lowrail and not listed here: argos-ri, roundhouse-rb and once-campfire; rubycdp/cuprite#360, its
issue #359 and rubycdp/ferrum#695 (from Argos); and older personal PRs and issues (kane50613/takumi#1973 and #1974,
aws/aws-sdk-ruby#3041, croaky/recipient_interceptor#8, isaacs/github#1952). The 06:20 UTC table is in git history.

Since 06:20 UTC: rails/rails#59596, #59597 and #59598 merged (amatsuda, 07:33–07:43 UTC); ruby/ruby#19680 (06:52)
and #19661 (08:47, in favor of byroot's #19703, merged 09:03 UTC) closed by us; ruby/ruby-bench#564 opened (07:01,
new head `a920bf4259` at 08:28 UTC). No GitHub conflict on any open PR except rails/rails#59577.

**Update 09:45 UTC:** with Thomas's OK, ruby/ruby#19663, #19664, #19665, #19666 and #19558 were closed at 09:43 UTC
with a thank-you comment each, leaving 13 open ruby/ruby PRs, and rails/rails#59577 at 09:32 UTC as superseded by
#59590 ("Closing, since #59590 covers this on main."; this one has no thank-you, which the 2026-11-04 rule in
DECISIONS now asks for). rails/rails#59584 moved to `fc24e18ab8` (keeps main's single `gsub!` and skips it when
none of `<`, `>`, `&` occurs), CI green, reply to amatsuda posted 09:34 UTC. Entries moved to [Closed](#closed).

**Update 11:55 UTC:** with Thomas's OK, ruby/ruby#19483, #19655 and #19685 were closed at 11:50 UTC with the reviewed
thank-you comments from [explainers-ruby-open](explainers-ruby-open.md). 10 ruby/ruby PRs are open, exactly the cap:
#19487, #19492, #19620, #19648, #19659, #19670, #19678, #19681, #19682, #19699; none is a draft.

| PR | Head | CI on head | Last activity (UTC) | New since our last word | Action |
| --- | --- | --- | --- | --- | --- |
| ruby/ruby#19483 | `70a47d2cad` | green | 11-04 05:55 (body rewritten) | none | **closed 11:50 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19487 | `4f8f7fe7e7` | green | 11-03 20:32 | none (k0kubun approved 10-22) | 14 days approved on 11-05: one neutral note allowed (proposal) |
| ruby/ruby#19492 | `1c6d753c71` | red, not ours (macOS MMTk runner lost communication, 10-23) | 11-03 20:32 | none (k0kubun approved 10-22) | as #19487 |
| ruby/ruby#19558 (draft) | `ad6449b8ec` | red, not ours (`make all` 30-minute timeout, 10-30) | 11-03 21:31 | none | **closed 09:43 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19620 (`ruby_3_4`) | `626b7bd20c` | red, not ours (i686 `test_gc` canary, bundled gems) | 10-30 08:22 | none | none |
| ruby/ruby#19648 | `cc33a7d70b` | red, not ours (SHSTK JSON, bundled gems) | 11-03 20:32 | none (k0kubun approved 11-02) | none |
| ruby/ruby#19655 | `852298882d` | green | 11-03 20:21 | none | **closed 11:50 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19659 | `bfb53d473e` | red, not ours (SHSTK JSON) | 11-03 20:21 | none | none |
| ruby/ruby#19663 | `251d0561d4` | green, but no longer builds on master (`BOP_NEW` removed by #19703) | 11-03 21:35 (our question) | byroot's #19703 merged 09:03 | **closed 09:43 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19664 | `d531b19421` | red, not ours (MMTk, SHSTK JSON) | 11-03 20:40 | none | **closed 09:43 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19665 | `89472a2a77` | red, not ours (SHSTK JSON) | 11-03 20:40 | none | **closed 09:43 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19666 | `70b8e23a8f` | red, not ours (MMTk, SHSTK JSON) | 11-03 20:40 | none | **closed 09:43 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19670 | `9fd1f6f25d` (force-pushed 11-04 14:00 UTC by Thomas, replaces `eb01818c3d`) | green (134 passed, 1 skipped) | 11-03 20:40 | none | none |
| ruby/ruby#19678 | `4944f1a29e` | green; Haiku still running | 11-04 06:13 (our reply) | none | wait for k0kubun |
| ruby/ruby#19681 | `dea97c3afa` | red, ours: macOS flaky test that #19699 fixes | 11-04 05:55 (body) | none | wait for #19699, then rerun or rebase |
| ruby/ruby#19682 | `0442275697` | green | 11-04 06:20 (our replies) | none (k0kubun approved 02:37) | wait |
| ruby/ruby#19685 (draft) | `aa82ba85e1` | green | 11-03 21:31 | none | **closed 11:50 UTC** with Thomas's OK, thank-you comment |
| ruby/ruby#19699 | `642bcc8f5e` | green | 11-04 06:20 (opened) | none | wait for review |
| ruby/ruby-bench#564 | `a920bf4259` | 13 pass, Windows (head) running | 11-04 08:28 (push) | none | none |
| rails/rails#59557, #59564, #59565, #59569, #59570, #59574 | `9aafb10814`, `2fb737482f`, `ab69e1b5e7`, `fcfadc0ee8`, `a2a3bf0075`, `79b81aa0bf` | green (Buildkite) | 11-03 20:51–21:21 | none | none |
| rails/rails#59577 | `51c3f20e9f` | green, but **conflicts** with main | 11-03 21:03 | kamipo's #59590 merged 06:19, rewrote `column_references` | **closed 09:32 UTC** with Thomas's OK as superseded by #59590 |
| rails/rails#59584 | `fc24e18ab8` | green (Buildkite, labeler, rails-new-docker) | 11-04 09:34 (our reply) | amatsuda 07:23: same `include?` pattern for `JS_SEPARATORS`; measured, answered | wait for amatsuda |
| rails/propshaft#289 | `a5bd01cc65` | green | 11-03 21:06 | none | none |
| rails/importmap-rails#336 | `cf3d933700` | red, not ours: setup-ruby has no Ruby 3.1.7 on ubuntu-26.04 | 11-03 21:09 | none | none |
| ruby-i18n/i18n#763, #764, #765, #766 | `405f196476`, `6a57b94bc1`, `0ff39e7cbf`, `0b552378da` | awaiting approval | 11-03 09:38–21:06 | none | none |
| ruby/bigdecimal#562 | `1cfddbf9b0` | awaiting approval | 11-03 21:09 | none | none |
| MiniProfiler/rack-mini-profiler#670 | `03a1eaae2c` | awaiting approval | 11-03 19:31 | none | none |
| getlago/lago-expression#91 | `d23823a03e` | awaiting approval | 11-03 15:06 | none | none |
| inertiajs/inertia-rails#435, #436, #437, #441, #442 | `bf76e9a598`, `4d34b1d4ee`, `499b417758`, `ec00f768ee`, `3886d49e82` | awaiting approval | 10-20 – 11-03 21:09 | none | none |
| tzinfo/tzinfo#171 | `57c9c3ad35` | awaiting approval | 11-03 21:09 | none | none |
| rubocop/rubocop-performance#550, #551, #552 | `5bf156f96b`, `87fa051683`, `2ab630312b` | awaiting approval | 10-22 – 11-03 21:09 | none | none |
| rubocop/rubocop-rails#1670 | `d6024b0ff3` | awaiting approval | 11-03 21:09 | none | none |
| Shopify/tapioca#2748 | `7294b59f4c` | CLA and mergeability pass; CI awaiting approval | 10-20 17:50 | none | none |
| skryukov/rails_vite#57 | `e90f4a23c2` | awaiting approval | 11-03 21:09 | none | none |

Open issues: Shopify/ruby#1095, #1100 (answered 11-03, now ruby/ruby#19682), #1101 and ruby/rubygems#10017 have
no new comments; Shopify/ruby#1097 (an external PR against #1095) is unchanged. No action on any of them. Nothing
was posted, pushed or closed upstream from this check.

#### ruby/ruby at the cap: close proposals for Thomas (all five closed 2026-11-04 09:43 UTC)

18 ruby/ruby PRs are open against a cap of 10, with no new ones for now (DECISIONS, 2026-11-04). Proposed closes,
with the reason; nothing is closed until Thomas agrees. Performance leads don't become issues (DECISIONS), so a
closed performance PR is recorded in [yjit-leads](yjit-leads.md) or the [ZJIT lead queue](zjit-iseq-leads.md);
the one correctness point among them is already reported as Shopify/ruby#1101.

1. **#19663** (YJIT `Hash.new` in `opt_new`): superseded upstream. byroot's #19703 (merged 09:03 UTC) removed
   `BOP_NEW`, which this PR's guard and bindings use, so it no longer builds; byroot's suggestion of a direct
   `rb_hash_s_new` call has gone unanswered since our question; and it is a YJIT speedup in maintenance mode. The
   refinement difference stays reported as Shopify/ruby#1101.
2. **#19664** (YJIT: no splat dup for a rest slice): explicit maintainer disinterest. XrXr: maintenance mode, a
   high-risk part of YJIT, "unlikely to take it for the next release". Evidence is −0.07% to −0.13% objects on
   ruby-bench, no time effect.
3. **#19666** (YJIT: rest parameter owns the splat array): same area and same reason as #19664, which it overlaps
   in one `if`; railsbench −0.23% objects, no time claim.
4. **#19665** (YJIT: Fixnum/Module interpolation): a YJIT allocation change (shipit −0.21% objects) whose ZJIT
   counterpart #19678 is the one under active review; once relayed as a correctness fix, which it is not.
5. **#19558** (draft, ZJIT reprofiles shape-polymorphic misses): weak evidence. Three interleaved headline runs
   show no timing effect beyond A/A, megamorphic fallbacks rise, and dak2's alternative (one class guard) gives the
   same fallback totals; draft since 11-03 by Thomas's choice.

That left 13 (confirmed after the closes). The [explainers](explainers-ruby-open.md) then proposed closing #19483, #19655 and #19685, closed 11:50 UTC, so 10 are open, the cap. The text below is as of 09:00 UTC. The next weakest are #19487 (YJIT
speedup in maintenance mode, though k0kubun approved it) and #19655 (ZJIT parity, no timing effect, no review);
neither has a concrete reason to close today, so both stay open. Keep: #19483 (body now has ZJIT stats and
Callgrind on the PR itself), #19492, #19620 (backport requested in review), #19648, #19659, #19670, #19678,
#19681, #19682, #19685, #19699.


### Gems

- [activerecord-hackery/ransack#1792](https://github.com/activerecord-hackery/ransack/pull/1792) (G1 from the [ecosystem test round](ecosystem-tests.md#regressions-and-their-fixes); replaces closed rails/rails#59623), `lib/ransack.rb` requires `active_support` before `active_support/core_ext`, so ransack loads on Rails main again (NameError for `WeakSet` before); suite unchanged on 8-1-stable and 8.1.0. Head `4713d2d697`, opened by Thomas on 2026-11-04 16:18 UTC and linked from #59623. Workflows wait for maintainer approval. Report-only watch every 3 hours.
- [getlago/lago-expression#91](https://github.com/getlago/lago-expression/pull/91), Ruby 4.1 compatibility: `required_ruby_version` `~> 4.0.2` → `>= 4.0.2`, and rb-sys `stable-api-compiled-fallback` (rb-sys 0.9.130 has no 4.1 stable API). Lago installs it from git. 20 specs on 4.0.7 and master; patch from the F1 frontier census. Bet E1; opened 2026-11-03. The census master overlay installs Lago from this branch (`d23823a03e`), so Lago and Lago-nops run on master ([gems-on-master](gems-on-master.md)); open, no review on 2026-11-03.
- Issue [ruby/rubygems#10017](https://github.com/ruby/rubygems/issues/10017): Bundler 4.0.x (through 4.0.23) fails on Ruby 4.1 when `.bundle/config` is `---`, a file Bundler writes itself; asks whether 368fc29ce1 (from #9379, unlabeled so not backported) can go into the next 4.0.x, and notes it cherry-picks cleanly onto `4.0`. Bet E1; filed 2026-11-03. Until a fix ships, Thinkroom's census master overlay deletes its committed `.bundle/config`, which holds only `---` ([gems-on-master](gems-on-master.md)); no reply on 2026-11-03.
- [ruby-i18n/i18n#763](https://github.com/ruby-i18n/i18n/pull/763), `Backend::Fallbacks#translate` skips the String comparison when the fallback is the requested locale object (`equal?`) — `I18n.t(:hello)` **13 → 11** objects; −40.3 objects per workload, 0.40% of all allocations in 14 apps (most of it Sure's dashboard; about −10 without it). From the [gem census](gem-census.md) (bet G1). Sol: request-changes twice (custom `==`, then overridden `equal?`); the second accepted, since Ruby documents that `equal?` should not be overridden. Opened 2026-11-03.
- [ruby-i18n/i18n#764](https://github.com/ruby-i18n/i18n/pull/764), `extract_non_symbol_default!` skips the wrapper Array for scalar defaults (Symbol, String, Hash, Integer) — 2 objects fewer per call; −32.2 objects per workload, 0.32% of all allocations (Sure −722, Docuseal −64 and Discourse −17 via Integer defaults). Four review rounds (Sol and adversarial Astra): to_ary coercion, flatten dispatch, nil/false, Array mutation and `!` dispatch all fixed; accepted: a global redefinition of `Array#flatten` sees a different call order for `to_ary`-convertible defaults. Head `6a57b94`. Opened 2026-11-03.
- [ruby-i18n/i18n#765](https://github.com/ruby-i18n/i18n/pull/765), `Backend::Fallbacks#translate` copies plain-Hash options with `merge` and sets the two fallback keys, instead of collecting them into a keyword Hash — `I18n.t(:hello)` 13 → 12 objects, −3.7% instructions; −47.3 objects per workload, 0.38% of all allocations, 10 of 10 translating apps. From the [i18n evaluation](i18n-performance.md) (C1). Sol and adversarial Astra: Hash-subclass `[]=`/`merge` overrides fixed (subclasses keep the old merge); accepted: a singleton `merge` on a plain options Hash, which `I18n.t` cannot pass because `**options` always builds a fresh Hash. Head `0ff39e7`. Opened 2026-11-03.
- [ruby-i18n/i18n#766](https://github.com/ruby-i18n/i18n/pull/766), `I18n.config` checks for Fiber storage once on Rubies that have it (`Fiber[]` is core from 3.2) and keeps checking on every call where it was missing at load — CPU only: `I18n.t(:hello)` −3.3% instructions, −2.3% to −2.7% for other calls. From the [i18n evaluation](i18n-performance.md#c4) (C4). Sol approve on both rubrics, adversarial Astra approve. Head `0b55237`. Opened 2026-11-03.
- [rails/propshaft#289](https://github.com/rails/propshaft/pull/289), `LoadPath#assets_by_path` strips `File.join(path, "")` from each file instead of `relative_path_from` — rebuild over 422 assets **99.5M → 12.6M** instructions (4.0.9), 74,015 → 9,970 objects; 25 ms and 123k objects on Mastodon's first request (inline_svg). More lenient on one input: a filename that isn't valid UTF-8 now fails only its own asset, not the whole load path. From the [gem request census](gem-request-census.md#p1-propshaft-computes-logical-paths-without-pathnamerelative_path_from) (bet G1, P1). Sol approve on both rubrics, L1. Head `a5bd01c`. Opened 2026-11-03.
- [MiniProfiler/rack-mini-profiler#670](https://github.com/MiniProfiler/rack-mini-profiler/pull/670), the `render_template`/`render_partial` subscribers return before `shorten_identifier` when the request is not measured — one render event 33.9k → 25.4k instructions, 18 → 7 objects; 0.43% → 0.32% of request CPU and 339 → 9 objects per request in 5 apps. More lenient on one input: an anonymous renderable (`identifier: nil`) raises only while profiling. From the [gem request census](gem-request-census.md#r1-rack-mini-profiler-skips-its-render-subscribers-when-the-request-is-not-measured) (bet G1, R1). Sol approve on both rubrics, L0. Head `03a1eaa`. Opened 2026-11-03.
- [ruby/bigdecimal#562](https://github.com/ruby/bigdecimal/pull/562), `BigDecimalCmp` reuses the frozen positive zero for an Integer `0` operand instead of allocating a temporary BigDecimal — one comparison with Integer zero **1 → 0** objects; 2,000 Active Record decimal deserializations **6,001 → 4,001**; a 1,000-row PostgreSQL result with two numeric columns **14,024 → 12,024**; about 318 fewer Callgrind instructions per such comparison (interpreter, YJIT, ZJIT). Allocation and instruction counts, no speed claim; Linux x86-64 only. Head `1cfddbf9b0`. Opened 2026-10-23; not listed here before 2026-11-03; no review yet.
- [rack/rack#2550](https://github.com/rack/rack/pull/2550), `Rack::Utils.set_cookie_header` escapes a single cookie value directly instead of wrapping it in an Array for `map`/`join` (K1) — per `Set-Cookie` **12 → 9** objects, Callgrind instructions −14% / −13% / −15% (4.0.9 interpreter / YJIT / master ZJIT, A/A ≤ 0.5%); 17 of 20 apps write 0.6–2 cookies per request on average. Adds two escaping assertions (no test checked escaping before). Accepted differences: a non-String `escape` override result is converted with `to_s`, a non-String key's `to_s` runs after the value's escape, and `Array#map` leaves `escape`'s backtrace. From [round 2](gem-request-census-2.md#k1-rack-escapes-a-single-cookie-value-without-wrapping-it-in-an-array) (bet G1). Primary review approve-with-nits (applied), adversarial round, body checked; L1. Head `ea7982d6f2` (the reviewed `43ceb88370` with the PR number added to its CHANGELOG line). Opened 2026-11-04 with Thomas's OK.
- [sparklemotion/nokogiri#3759](https://github.com/sparklemotion/nokogiri/pull/3759), `DocumentFragment#css` calls `children` once instead of twice (N1) — HTML5 fragment 41 → 39 objects and −1.5% instructions, Loofah fragment **79 → 70** and −5.5%, similar on YJIT and master ZJIT; Action Text and Discourse call it about 1–9 times per request in 6 apps. From [round 2](gem-request-census-2.md#n1-nokogiri-searches-a-fragments-children-once-in-documentfragmentcss) (bet G1). Primary review approve, body checked; L0. Head `7ef8b0d431`. Opened 2026-11-04 with Thomas's OK; CI waits for a maintainer to approve the workflows (first contribution).

### Ruby — ruby/ruby

**Rechecked 2026-11-04 09:00 UTC** against `gh search prs --author thomasklemm --state open`: 18 open ruby/ruby PRs (#19558 and #19685 drafts), above the cap of 10 (DECISIONS, 2026-11-04); #19661 and #19680 closed since 06:20 UTC. **13 open since 09:43 UTC**, after #19558, #19663, #19664, #19665 and #19666 were closed; **10 open since 11:50 UTC** (the cap), after #19483, #19655 and #19685 were closed (see [Closed](#closed)); no drafts. Heads, CI and close proposals in the [status check](#status-check-2026-11-04-0900-utc).

- Comment on [#16909](https://github.com/ruby/ruby/pull/16909#issuecomment-6608177637) (Earlopain's closed "Deprecate `Pathname::SEPARATOR_PAT`"), no PR: 10 of 20 census apps still lock Bundler ≤ 4.0.11, so any path or git gem fails on 4.1 with `NameError`; restoring the constant with `deprecate_constant` makes Bundler 2.6.9 and 4.0.11 work (reference branch `thomasklemm/ruby:thomasklemm/pathname-separator-pat` @ `6c8385cd3f`, kept). Information for the 4.1 release, no ask. Bet E1; posted 2026-11-03.
- [#19487](https://github.com/ruby/ruby/pull/19487), compile YJIT `super` on Class/Module receivers — untimed singleton-super fallbacks/request **141 → 13** blog, **300 → 16** Fizzy; dynamic dispatch attempts **616 → 488 / 1,304 → 1,020**. Escaping micro: **352 fewer Ir/call (32.20% of marginal work)** and **23.12% less YJIT time [−29.82, −17.35]%**, not whole-request speed. Class/module graph retention remains; ordinary singleton receivers stay refused.
- [#19648](https://github.com/ruby/ruby/pull/19648), YJIT no longer raises `Ractor::IsolationError` while compiling a singleton-class guard on another Ractor's unshareable object (e.g. the block param proxy); found by the JIT differential run through Rails main's `DeprecationTest`. Correctness fix with regression test; Codex Thermos review (GPT-6 Astra) approve on both rubrics. Opened 2026-11-02.
- [#19659](https://github.com/ruby/ruby/pull/19659), ZJIT yields directly to simple ISEQ blocks that take fewer params than the args passed, dropping the extras like the interpreter and YJIT (resolves Shopify/ruby#1094, which tekknolagi filed after our closed #19625). `200_000.times { }` 25.2 → 4.6 ns/iteration; `invokeblock_not_specialized` −1% on 16 headline benchmarks; headline timing flat vs A/A. Auto-splat and too-few-args cases stay generic. Codex Thermos (GPT-6 Astra) approve on both rubrics. Opened 2026-11-02; replied on #19625.
- [#19670](https://github.com/ruby/ruby/pull/19670), Ruby 4.1 regression fix: `m(a: v, **h)` and zsuper with named keywords allocate one Hash again (`core#hash_new_for_merge` leaves room for 8 entries and `core#hash_merge_bang_kwd` merges the splat in place; head `9fd1f6f25d` since 2026-11-04 after three Sol rounds, replacing the `core#hash_merge_fit_kwd` version `eb01818c3d`); regression from #18344 (f01bf185f6). Hash totals over 97 Rails workloads: 4.0.7 **78,103**, master **81,992**, fix **77,840** (measured on the `eb01818c3d` version). From the [Ruby 4.1 regression watch](ruby-4.1-regression-watch.md) (bet L3). Astra approve / approve-with-nits (tests extended); opened 2026-11-03.
- Comment on [#17251](https://github.com/ruby/ruby/pull/17251#issuecomment-6595636309) (eightbitraptor, per-heap nofree majors): Rails census data (nofree majors +142%/+159%, YJIT GC time +12% vs 4.0.7), bisect to 16da5f23c2 (#16632), standalone repro; #17251 rebased reduces but does not remove it. Our 1,024-slot pool-budget fix was not submitted (Astra: much larger lazy-sweep steps). Posted 2026-11-03.
- Issue [Shopify/ruby#1099](https://github.com/Shopify/ruby/issues/1099): ZJIT polymorphic fallbacks on Rails are mostly lost profiles (one class, several shapes), class-level methods on model classes, and singleton objects since #19540; per-site data from nine apps and ruby-bench, three repros, offer to prototype ([record](zjit-polymorphism.md), bet Z3). Posted 2026-11-03. **Closed by us 2026-11-03 20:51 UTC**: "Closing this; it overlaps with #995 and doesn't ask for one specific change."
- Comment on [Shopify/ruby#1058](https://github.com/Shopify/ruby/issues/1058) (ZJIT `Kernel#dup`): Rails call counts, a measurement prototype (patch points plus a swapped cfunc, −0.68% / −0.50% / −0.90% Ir on railsbench / lobsters / shipit), and an offer to take it ([record](zjit-cfunc-paths.md), bet Z7). Posted 2026-11-03. tekknolagi asked what stops a pure-Ruby `dup`; our 16:34 UTC reply (Ruby `dup` prototype, dense table) was called "LLM shorthand" that is "very difficult to read" (19:54 UTC). Thomas replied at 20:04 UTC, explained the measurement in plain words and said he will not pursue this attempt further. **Withdrawn 2026-11-03**; the queue entry for `Kernel#dup` in DECISIONS predates this.
- Comment on [Shopify/ruby#1091](https://github.com/Shopify/ruby/issues/1091) (ZJIT Integer/Module `to_s` at objtostring): allocation-parity data from lobsters / shipit (4,270 / 3,795 `to_s` sends → 0 per iteration), branch `zjit-objtostring-int-module`, and an offer to take it ([record](zjit-objtostring.md), bet Z5). Posted 2026-11-03. **Answered 2026-11-03** by tekknolagi: "Sure, that is fine" (assigned to us). PR opened 2026-11-03: [ruby/ruby#19678](https://github.com/ruby/ruby/pull/19678) (fixes #1091).
- Comments on [Shopify/ruby#1064](https://github.com/Shopify/ruby/issues/1064) and [#1065](https://github.com/Shopify/ruby/issues/1065) (ZJIT compile time): cached `iseq_may_write_block_code` and a binary-search stopgap for `handle_caller_saved_regs`, lobsters compile time −3…−5% each, a 4,000-call method 3.58 s → 0.53 s with both; offers to take them ([record](zjit-compile-speed.md), bet Z6). Posted 2026-11-03. **Answered 2026-11-03** by tekknolagi: #1064 "Go for it" (assigned to us); #1065 "go for it", but without an interstitial Vec per CCall. PRs opened 2026-11-03: [ruby/ruby#19680](https://github.com/ruby/ruby/pull/19680) (fixes #1064) and [ruby/ruby#19681](https://github.com/ruby/ruby/pull/19681) (fixes #1065, without a per-CCall Vec).
- Comment on [ruby/ruby#18960](https://github.com/ruby/ruby/pull/18960) (XrXr, locals in the stack map): side-exit code grows as N² on master and OOMs at N=400; with the PR, exits are about 33 B and ruby-bench `code_region_bytes` drops 14–20% ([record](zjit-compile-speed.md), bet Z9). Posted 2026-11-03, **deleted the same day** (Thomas): unsolicited benchmarking of XrXr's PR that he had already measured. Our 2026-10-30 comment there (the PR also fixes the `for_spec.rb --repeat 2` failure, with a repro) stays.
- Issue [Shopify/ruby#1100](https://github.com/Shopify/ruby/issues/1100): ZJIT `super` in a method that received a block side-exits on every call (`recompile: None`); 10/10 census apps, railsbench 2,052 exits per iteration; asks whether k0kubun's super work covers it ([record](zjit-iseq-leads.md), bet Z10 lead 8). Posted 2026-11-03. **Answered 2026-11-03** by k0kubun: "It's free to take." PR opened 2026-11-03: [ruby/ruby#19682](https://github.com/ruby/ruby/pull/19682).
- Comment on [Shopify/ruby#1039](https://github.com/Shopify/ruby/issues/1039): Rails-main breadth (per-ISEQ ZJIT counters, 10 apps) for unassigned rows 11, 19, 20/22 and 47, data only ([record](zjit-iseq-leads.md), bet Z10). Posted 2026-11-03, **deleted the same day** (Thomas): #1039 is k0kubun's lobsters burndown, and Rails-main breadth answered no question asked there.
- Data comments on other people's ZJIT/VM PRs (bet Z4, [record](zjit-open-prs-on-rails.md)), posted 2026-11-03: [#18326](https://github.com/ruby/ruby/pull/18326#issuecomment-6600307476) (sendforward: wrong results when the argument shape differs from the profile, with repro and Rails divergences), [#19583](https://github.com/ruby/ruby/pull/19583#issuecomment-6600307871) (`.send(:sym)`: Rails suites unchanged, constant-name fallbacks 41,673 → 0 on railsbench), [#19447](https://github.com/ruby/ruby/pull/19447#issuecomment-6600308224) (Ractor shareable fix: Bug #22419 repro and Rails' Action Pack suite pass).
- Follow-ups to [#19660](https://github.com/ruby/ruby/pull/19660) (merged 2026-11-03, see [Merged](#merged)), opened 2026-11-03 after Astra re-review (approve, test nits fixed):
  - #19661 (Hash subclasses keep the `opt_new` fast path) was closed on 2026-11-04 in favor of byroot's [#19703](https://github.com/ruby/ruby/pull/19703); see [Closed](#closed).
  - Issue [Shopify/ruby#1095](https://github.com/Shopify/ruby/issues/1095), ZJIT copies a caller-built splat array (`ARGS_SPLAT_MUT`) into a new rest Array where the interpreter reuses or beheads it: 2 vs 1 objects per call; largest remaining ZJIT-over-interpreter gap in the nine-app census (`URI.for(*split(uri), self)`, 5/9 apps, +18.5 objects/op). Filed 2026-11-03 with repro, HIR and the #19538 replay constraint. An external contributor opened [Shopify/ruby#1097](https://github.com/Shopify/ruby/pull/1097) against it on 2026-11-03 (on a base predating #19538; no maintainer response yet); we did not comment.
- [#19620](https://github.com/ruby/ruby/pull/19620), backport of merged #19554 to `ruby_3_4`, requested in review — correctness fix, no measurement.
- [#19492](https://github.com/ruby/ruby/pull/19492), count YJIT dynamic sends before dispatch — for **1,000** raising, throwing or block-break sends, counter **0 → 1,000**; normal-return control **1,000 → 1,000** and results unchanged. Corrects attempt diagnostics only; **no performance claim**.
- [#19678](https://github.com/ruby/ruby/pull/19678), ZJIT interpolates Fixnums and Modules without sending `to_s` (`rb_fix_to_s` without a frame, `rb_mod_name`), guarded like a cfunc call; fixes Shopify/ruby#1091. ZJIT per iteration: `to_s` sends at interpolation 4,270 → 0 lobsters, 3,795 → 0 shipit; objects beyond the interpreter 1,576 → 931 / 3,835 → 1,361. Allocation counts, no time claim. tekknolagi's four review comments addressed in `3656855d29`; head `b6ed2f484e`, `4944f1a29e` on 2026-11-04 (refactor push for k0kubun's 02:51 UTC review: one if-else chain, each branch with its own lookup, guards and codegen; our 06:13 UTC reply offers a helper for the repeated setup). No answer by 09:00 UTC; CI green apart from the slow Haiku job. Opened 2026-11-03.
- [#19681](https://github.com/ruby/ruby/pull/19681), ZJIT finds caller-saved survivors with one binary-search pass instead of scanning every interval per CCall (stopgap, no interval splitting); fixes Shopify/ruby#1065. `compile_time_ns`: railsbench −2.9%, lobsters −5.4%, shipit +0.3% (within A/A); `handle_caller_saved_regs` Ir on railsbench 558 M → 328 M. Generated code unchanged. Head `dea97c3afa`. Opened 2026-11-03.
- [#19682](https://github.com/ruby/ruby/pull/19682), ZJIT records in the `invokesuper` profile whether the frame had a block, so `super` from a method that got a block no longer side-exits on every call; for Shopify/ruby#1100. Side exits per iteration 2,052 / 341 / 57 → 0 (railsbench / lobsters / shipit); repro 1,090 → 942 Ir per call; ruby-bench Ir within A/A. Opened 2026-11-03. On 2026-11-04, after k0kubun's two review points, it skips the frame's block when the call site passes its own (`super(&b)`, `super { }`) and keeps the flag in a `bool` on `ProfileEntry` instead of a `HashSet`: `zjit_alloc_bytes` railsbench 7,456,668 → 7,328,524 (base 7,357,592), lobsters 20,111,412 → 19,855,120 (base 19,866,920); an extra slot in the operand profile measured 7,354,212 / 19,904,604 and needs a special case in HIR. Head `0442275697` (one commit); replies posted on both review comments. k0kubun approved at 02:37 UTC ("I'd like to land a fix for the permanent exit"); CI green on `0442275697`; no answer to the 06:20 UTC replies by 09:00 UTC. Rethought on 2026-11-04 ([zjit-super-block.md](zjit-super-block.md)): keep it as it is; two measured limits (sites that only sometimes get a block, ISEQs with no version left) and the larger `super` gaps are recorded there as leads.
- [#19699](https://github.com/ruby/ruby/pull/19699), test-only fix for our flaky macOS test `test_send_proc_block_arg_to_block_param_callee` (from merged #19484): insta's first snapshot runs `cargo metadata`, and the child's SIGCHLD leaves a trap interrupt that makes the inlined second run side-exit. Both programs now run before the first snapshot. A/B on `macos-26`, 8 shards: test alone 8/1200 → 0/1200 failures, in the full suite 5/32 → 0/32. Approved exception to the ruby/ruby PR stop. Head `642bcc8f5e`, CI green (137 checks), no review by 09:00 UTC. Opened 2026-11-04.
- CI on 2026-11-04 09:00 UTC: no failure on any open head is caused by our change. #19681's only red jobs are the macOS `zjit-check` failure in our own flaky test, which #19699 fixes; #19678's new head passed that job. Not ours, besides the list below: #19492's `check (mmtk, release, macos-26)` (2026-10-23: the hosted runner lost communication), #19659's and #19664's `make (check, SHSTK)` (the JSON `rfc8785` failures), and #19558's `make` (2026-10-30: `make all` hit the 30-minute timeout). Earlier record, 2026-11-03 22:00 UTC: #19678, #19680 and #19681 fail `make (zjit-check, …)` on macOS in `codegen::tests::test_send_proc_block_arg_to_block_param_callee` (a test from our merged #19484); master is green in that workflow, as are #19682 and #19685. Rechecked 2026-11-04: this test is ours and the macOS fix for it is being prepared separately (the approved PR-stop exception); #19680 and #19681 stay as they are until it lands. Every other red ruby/ruby check is not ours: `SHSTK` JSON `rfc8785` tests (#19648, #19665; master's SHSTK run failed the same night), ModGC MMTk "failed to re-disable GC" (#19664, #19666; fails on master and others' PRs too), bundled-gem IRB/csv tests (#19648, #19670), Windows OpenSSL timeout and s390x RubyGems git test (#19670), and an interpreter stack-canary `[BUG]` in `test_gc` on i686 for the YJIT-only `ruby_3_4` backport #19620 (no YJIT on i686).
- Issue [Shopify/ruby#1101](https://github.com/Shopify/ruby/issues/1101): YJIT and ZJIT skip a call-site refinement of `Hash#initialize` in `Hash.new` since #19537 (interpreter applies it), with repro. Filed 2026-11-03; no reply by 2026-11-04 06:20 UTC. The body now names only #19663 (YJIT) and says there is no ZJIT fix yet.

### Benchmarks — ruby/ruby-bench

- [ruby/ruby-bench#564](https://github.com/ruby/ruby-bench/pull/564), lobsters and shipit use `:memory_store` instead of a file store in `tmp/cache`, so each benchmark process starts with an empty cache of its own. With three lobsters processes started together on one checkout, two stopped at `/replies/unread` with `Errno::ENOENT` from `File.rename`; with the memory store all three succeed. Same cache reads, writes and deletes per iteration (lobsters 118 / 18 / 8, shipit 249 reads) and the same 114 lobsters responses; lobsters' cache time falls from 21.7 to 1.7 ms per iteration with ZJIT (24.7 → 2.5 ms interpreter), about 2% of an iteration, so lobsters results before and after are not directly comparable (stated in the body). Rank 2 of the [ruby-bench evaluation](ruby-bench-improvements.md); ruby-bench is not covered by the ruby/ruby PR stop. Opened 2026-11-04 07:01 UTC; force-pushed 08:28 UTC to one commit `a920bf4259` (two files). CI: 13 checks pass, `benchmark-default-windows (head)` still running at 09:00 UTC; no review or comment yet.

### Rails — rails/rails

Open on 2026-11-04 09:45 UTC: the seven PRs below (#59557, #59564, #59565, #59569, #59570, #59574, #59584), plus #59605 opened later that day; #59577 closed at 09:32 UTC. #59596, #59597, #59598 and #59603 merged on 2026-11-04 and moved to [Merged](#merged). Later: #59605 merged 13:29 UTC; #59616 opened 13:53 UTC and merged 14:58 UTC; #59617 opened 14:01 UTC; #59618 opened 14:11 UTC.

- [#59624](https://github.com/rails/rails/pull/59624) (T1, test fix found from #59620's red Buildkite run 136127), `FieldOrderedValuesTest` loads `:author_addresses` with `:authors`. "Extract order references from the built Arel nodes" (63cf73e451) added `:authors` to the test; `authors.yml` points at `author_address_id: 1` through `fk_rails_94423a17a3`, and on PostgreSQL 18.4+ fixtures load with foreign keys `NOT ENFORCED` and then `ENFORCED` again, which validates existing rows, so the test errors whenever it runs before any test that loads `author_addresses` (CI: 21 errors, seed 14797, one shard). Same kind of fix as #28991. Repro on unmodified main with PostgreSQL 18.6: the file alone gives 21 `PG::ForeignKeyViolation` errors; PostgreSQL 15 and SQLite pass either way; with the fix it passes, and all 46 test files that load `authors` pass alone on 18.6 with `author_addresses` emptied first. Test only, +1/−1. Head `a712a0a9bc` on main `8b06b0eb98`, merges cleanly onto `e64f5a4258`. Opened 2026-11-04 15:46 UTC by Thomas by hand, ready for review ([body](../../bench/upstream/actionpack_request_path/fov-body.md)). Watched report-only every 2 hours from the round thread.
- [#59620](https://github.com/rails/rails/pull/59620) (AP-2 from the [Action Pack request-path round](actionpack-request-path.md#ap-2-no-set-union-on-every-render)), `_all_renderers` returns the frozen `Renderers.all` when the controller has no local renderers instead of building `_renderers + Renderers.all` on each render (an unreleased cost from #57830) — template-render check 1,354 → 801 ns / 1,165 → 552 ns (interp / YJIT), `render json:` 3,928 → 3,274 / 2,658 → 2,001 ns, one object fewer; ruby-bench railsbench −0.10% / −0.33%. Contract note in the body: `super.delete` in an override now raises `FrozenError`. Lib +5/−1, tests +44, L0/L1. Subagent primary review, cold read, then Sol: open after fixes (tests and body applied). Opened 2026-11-04 14:38 UTC as Thomas, ready for review, head `670e0c390f` on main `aa236fc09b`. Buildkite 136127 red in one shard (activerecord postgresql 3.4, 21 errors in `FieldOrderedValuesTest`, unrelated: the fixture gap below under Drafted); rebased unchanged onto `8b06b0eb98` as head `495c3a6405`, Buildkite 136134 green. Watched report-only every 2 hours from the round thread.
- [#59619](https://github.com/rails/rails/pull/59619) (AP-1 from the [Action Pack request-path round](actionpack-request-path.md#ap-1-join-adjacent-literals-when-building-a-routes-format)), `Journey::Format` joins adjacent literals once at build time, keeps its parameters instead of their indexes and checks them with `any?` (no allocation from a non-local `return` when an optional group is skipped), and drops the unused `@children` — `post_path` 34,472 → 31,855 instructions interpreted (−7.6%), −4.7% YJIT, −11.1% ZJIT; 4,336 → 3,988 ns (−8.0%) / 2,005 → 1,880 ns (−6.2%); 7 → 6 objects; building a format +19% instructions (about 2 µs per route), retained format memory 536 → 344 bytes per route. Opened 2026-11-04 14:28 UTC (head `5bce8c7450`); Thomas set it to draft and asked for a plainer `Format` (`join_adjacent_literals` loop, `@parameters.grep(Parameter)`, `any?`); reworked to his shape, cold read L1, differential unchanged, Action Pack and Action View suites green. Head `b86b5887b3` on main `aa236fc09b`, marked ready for review again. Watched report-only every 2 hours from the round thread.
- [#59627](https://github.com/rails/rails/pull/59627) (AR-2 from the [API regression audit](api-regressions.md)), restores `ActiveModel::SecurePassword::MAX_PASSWORD_LENGTH_ALLOWED` as a public constant pointing at `BCryptPassword`'s limit. #56041 moved it before release, and Spree's `maximum_password_length` default and open-build-service's `User` validation raise `NameError` at load on main. Compatibility fix, no performance claim; identical to 8-1-stable on interpreter, YJIT and ZJIT; load order unchanged (same 228 files, bcrypt gem not loaded). Subagent review, then Sol "open with nits" (applied). L0. Head `08be5191db` on main `8b06b0eb98`. Opened 2026-11-04 16:13 UTC by the coordinator as Thomas, ready for review ([body](../../bench/upstream/api_regressions/bodies/max-password-length.md)). Initial CI pending. Watched report-only every 3 hours from the census-backlog thread.
- [#59617](https://github.com/rails/rails/pull/59617) (TC-1 from the [census backlog](census-backlog.md#tc-1-keep-the-utc-offset-in-timechange-for-times-with-a-zone-object)), `Time#change` on a `Time` with a zone object keeps the original UTC offset when the zone gives the new local time that offset. Correctness fix: on 8.1 and main, TZInfo zones raised `TZInfo::AmbiguousTime` in the hour repeated when clocks are set back (also in Active Model's datetime cast when precision truncation is needed), and `ActiveSupport::TimeZone` picked the other occurrence in Dublin; the differential over every tzdata transition up to 2037 differs only there. Cost on zone-object Times: +6–12% instructions interpreted, +16–22% YJIT, about 2× when the offset changes. Reviews: subagent primary and adversarial approve, outsider body rewrite, Sol "open after fixes" (applied). L1. Head `553f9267ee` on main `aa236fc09b` (force-pushed 2026-11-04 with a spring-forward and offset-crossing test; was `d5252fae22`). GitHub refused PR creation for the account after 13 PRs that day; the coordinator opened it on 2026-11-04 at 14:01 UTC, ready for review, as Thomas, with the [short body](census-backlog.md#pr-body-final-ready-to-open). Initial CI: labeler pass; rails-new-docker, buildkite/rails and docs-preview pending. Watched report-only every 3 hours from the census-backlog thread, in the same schedule as #59606; replies go to the coordinator as drafts.
- [#59618](https://github.com/rails/rails/pull/59618) (W3 from the [Active Record write-path round](ar-write-paths.md)), `build_select` appends the default `table.*` attribute to the manager's projections directly instead of going through `project`, so no one-element splat Array is built per default-star projection — `Post.all.to_a` Callgrind −0.26% / −0.38% (interpreter / YJIT, A/A ≤ 0.01%), ZJIT no measurable difference; 291 → 290 allocations; ruby-bench shipit 1,811 and lobsters 660 such projections per iteration. Independent of open #45864 (same line). Subagent primary review, then Sol: open after fixes (applied). Lib +1/−1, L1. Head `c4f465b7b2` on main `9cf3693a0a`. Opened 2026-11-04 14:11 UTC from the coordinator orb with Thomas's OK ([body](../../bench/upstream/ar_write_paths/w3-body.md)). Watched report-only from the round thread.
- [#59626](https://github.com/rails/rails/pull/59626) (F1 from the [Rails 8.2 differential](rails-82-differential.md#f1-to_query-skips-nested-values-that-serialize-to-an-empty-query)), `Array#to_query` and `Hash#to_query` skip a value whose query string is empty, so a value that only holds empty collections no longer adds a stray `&` (`{ q: [[]], page: 2 }.to_query` is `"&page=2"` on main, and `url_for` builds `/search?&page=2`); accident from #57677, unreleased. Correctness fix, no measurement; +4/−2 plus two tests. Sol "open with nits" (nits applied). Head `2750d65efd` on main `8b06b0eb98`. Opened 2026-11-04 by Thomas by hand as a draft (drafts don't count toward the 15-open-PR cap); marked ready for review by the coordinating thread's queue once a slot freed up (head unchanged). Watched every 2 hours, report-only, from the differential thread.
- [#59625](https://github.com/rails/rails/pull/59625) (F2 from the [Rails 8.2 differential](rails-82-differential.md#f2-url-helpers-keep-generating-empty-arguments-with-default-url-options)), the optimized URL helpers fall back to the general path when they can't build the path and default URL options apply, so with `default_url_options[:host]` set an empty-string argument or a record whose `to_param` is empty generates the URL again instead of raising `UrlGenerationError`; accident from #59479, unreleased. Correctness fix, no measurement; +3/−3 plus a boundary test and two comparison cases. Sol "open with nits" (nits applied). Head `2b4a97089a` on main `8b06b0eb98`. Opened 2026-11-04 15:50 UTC by the coordinating thread (PR creation from the orbs is capped at 15 open PRs per repository), ready for review. Watched every 2 hours, report-only, from the differential thread.
- [#59611](https://github.com/rails/rails/pull/59611) (R1 from the [Ruby 4.1 readiness round](ruby-4.1-readiness.md#r1-declare-prism-as-a-dependency)), declares `prism` without a version in the Action View and Railties gemspecs (+4 lines with `Gemfile.lock`). Ruby master, targeting 4.1, makes prism a bundled gem (Feature #22379) and #56631 removed the Ripper fallbacks, so without another gem bringing prism in, `ActionView.eager_load!`, Ruby-based dependency tracking, the test runner and `bin/rails notes` raise `LoadError`. Correctness, not speed; no measurement. L0; correctness and maintainability subagent reviews approve, Sol review "open after fixes" (body and message rewritten to it). Head `4a837183ea` on main `1ca7528bac` (rebased; merge-tree clean, no overlapping PR or issue). Opened 2026-11-04 with Thomas's OK, ready for review. Watched every 2 hours, report-only, from the readiness thread (the Amp GitHub App cannot subscribe to rails/rails).
- [#59621](https://github.com/rails/rails/pull/59621) (P1, follow-up to #59609 from the [issue triage](rails-issue-fixes.md#p1-plucked-columns-unknown-to-the-schema-2026-11-04)), `pluck`/`pick` cast a column whose type is the placeholder `ActiveRecord::Type.default_value` (subquery aliases, CTEs, columns of an unrecognised type) with the result's column type when the adapter reports one: subquery dates come back as `Date` instead of Strings, SQLite booleans as `true` instead of `1`. Not a regression (same on 7.0.4.3). Lib +8/−1, tests (mixed known/unknown pluck plus `pick`; an explicit `ActiveModel::Type::Value` stays raw and fails if `equal?` becomes `==`; a result without column types keeps the placeholder, as on MySQL), CHANGELOG. Plain description and cold read L1; Sol: open after fixes, all applied. AR suite: PostgreSQL 11,205 runs 0 failures; SQLite 10,284 runs 0 failures, 4 `sqlite3`-CLI errors. Only the CHANGELOG conflicts with #59609; whichever lands second needs a rebase. Head `8d29f4b6f0` on main `6c23cb8f2a`. Opened 2026-11-04 14:54 UTC, ready for review; watched with #59609 every 2 hours, report-only.
- [#59609](https://github.com/rails/rails/pull/59609) (I1, bug fix from the [issue triage](rails-issue-fixes.md); fixes [#48420](https://github.com/rails/rails/issues/48420)), grouped calculations cast the keys of a column whose type is the placeholder `ActiveRecord::Type.default_value` (subquery aliases, CTEs, columns of an unrecognised type) from the result's column types, as before 7.0.5: `group("ranges.range").count` keys are `Range` again instead of String on PostgreSQL, and SQLite subqueries selecting a typed column give `true`/`Date` instead of `1`/`"2020-01-01"`. Lib +4/−1 (one comment), three tests (PostgreSQL range and mixed two-column grouping, a SQLite/PostgreSQL CTE, an explicit `ActiveModel::Type::Value` that must stay), CHANGELOG. Primary review approve on both rubrics (L1); adversarial round: two low differences accepted (a `from` subquery replacing a column of unrecognised type; a type registered late for an unknown OID); Sol approve, its nits applied (identity-check comment, the three tests, body wording). AR suite: PostgreSQL 11,205 runs 0 failures; SQLite 10,283 runs 0 failures, 4 errors from the missing `sqlite3` CLI; MySQL not run. Head `2e9fc7c4b4`, rebased unchanged onto main `fa03095c6f` on 2026-11-04 after an infrastructure-killed RuboCop job in Buildkite 136128 (136145 passed; before that head `82d7ba5d4b` on main `9b116f1fed`: CHANGELOG limited "as before Rails 7.0.5" to PostgreSQL, and the body's first sentence now names PostgreSQL; before that, the readability rewrite after opening: one `if / elsif / else`, cold read L1, AR suite green again; [record](rails-issue-fixes.md#readability-record-decisions-readability-gate-and-plain-description-applied-after-opening)). Opened 2026-11-04 12:42 UTC under Thomas's standing OK for bug fixes; watched every 2 hours, report-only.
- [#59606](https://github.com/rails/rails/pull/59606) (TH-1 from the [census backlog](census-backlog.md#th-1-restore-the-template-handler-lookup-methods)), restores `ActionView::Template.registered_template_handler`, `template_handler_extensions` and `register_default_template_handler`, which #57874 dropped before release; maildown 3.3.1's handler raises `NoMethodError` on main the first time a `.md` template compiles (CodeTriage's mails in census 4). Compatibility fix, no performance claim (render path within A/A in Callgrind). Differential identical to 8-1-stable under the 4.0.9 interpreter and YJIT and the master interpreter and ZJIT, including a stateful `to_sym` (one call, as 8.1). Reviews: subagent primary approve / approve-with-nits (L0); Sol in the coordinating thread approved with one exactness fix (`register_default_template_handler` converted the extension twice; now `extension.to_sym`) and stronger tests; a separate re-review of the final diff and body approve / approve-with-nits (body wording fixed). Action View `rake test` 2,950 + 251 + 177 runs, 0 failures. Head `5b24d5490e` on main `9b116f1fed` (merge-tree clean, main unchanged at opening); no open PR restores these methods. Opened 2026-11-04 with Thomas's OK, ready for review; initial CI: labeler pass, Buildkite and rails-new-docker pending. Watched report-only from the census-backlog thread (the Amp GitHub App cannot subscribe to rails/rails); any reply is drafted for Thomas first.
- [#59613](https://github.com/rails/rails/pull/59613) (N1 from the [Active Support round](as-request-paths.md#n1-build-the-handles-groups-with-each)), `Fanout#build_handle` builds its group objects with `each` and `<<` instead of `Hash#map` (Enumerable), one internal callback object (IFUNC) fewer per instrumented event with active subscribers, default `Fanout` notifier. `instrument` with one subscriber 4 → 3 objects, −5.1% / −10.8% / −11.3% instructions (interpreter / YJIT / ZJIT; A/A ≤ 0.9%), −10.3% / −25.5% time (quiet rerun); `Post.find` −0.3% / −0.6% / −0.7%; ruby-bench within noise, no request speedup claimed. L1; primary, adversarial, cold-read and outsider subagents, then the coordinator's Sol round (open after body fixes: no absolute exactness claim, standalone benchmark, exact Ruby builds, modest pitch). Head `d6b71f057d` on main `9cf3693a0a` (rebased; merge-tree clean, no commits on the file since `9b116f1fed`). Opened 2026-11-04 under the standing OK (DECISIONS 6aca583), ready for review. Watched report-only every 2 hours from the round's thread.
- [#59614](https://github.com/rails/rails/pull/59614) (H1, same round), `Hash#extract!` iterates its keys with `each` and a local result Hash instead of `each_with_object`, in Sol's `do … end` form (same bytecode as the reviewed braces form). `extract!` with the asset helpers' keys on an existing Hash 3 → 2 objects; −18.8% / −43.8% / −23.7% instructions and −24.0% / −40.1% time with the input Hash built per call; `stylesheet_link_tag` −1.6% / −5.1% / −3.5% instructions; ruby-bench within noise. Body lists the calls exactly (receiver `class`, `has_key?`, `delete`; its class `new`; the result `[]=`) and says diagnostic frames change. Head `441ee1f921` on main `9cf3693a0a`. Opened 2026-11-04, ready for review; same watch.
- From [census 5](rails-main-census-5.md) (same nine apps on main 5810776 after the merges), Codex Thermos (GPT-6.1 Sol) approve on both rubrics for each; opened 2026-11-02:
  - [#59557](https://github.com/rails/rails/pull/59557), `Array#index_with` fills `Hash.new(capacity:)` on Ruby 4.1 instead of pair Arrays (stacked on #59555) — revisits #59108/#59203 after ruby/ruby#19537: n+1 → 1 object per call, 0 spills on railsbench/shipit/lobsters, objects −11,993/−60,651/−5,408 (4.1 interpreter), wall time tied, 4.0 unchanged ([record](index-with-capacity.md)). Sol: two request-changes rounds (subclass overrides, RubyGems dependency of the gate), then approve on both; opened 2026-11-03.
- From the [PostgreSQL census](pg-census.md) (nine PG apps incl. Mastodon, Discourse, Docuseal, Lago, Loomio, Sure, CASA; 124 workloads incl. `prepared_statements: false`):
  - [#59564](https://github.com/rails/rails/pull/59564), the preloader builds its per-pass working Arrays in place (`Branch#future_classes`, `runnable_loaders`, `Batch#call`) — `Post.preload(:author)` **287 → 277**, three-level preload **1,029 → 982**; preloading workloads in 17 apps median **−70**. From [census 6](rails-main-census-6.md); C6-2 (`immediate_future_classes`/`target_classes` in place) folded in as one commit `58ad783`. Sol approve on both rubrics for each part; opened 2026-11-03. **Switched 2026-11-03 to the simple variant** `2fb7374` (force-pushed with a lease from `58ad783`): plain `.uniq` instead of six `.tap(&:uniq!)`, lib +10/−6, readability L1. Per call: `Post.preload(:comments)` 384 → 375 objects, Ir −0.14% / −0.34% / −0.24% (4.0.7 interpreter / YJIT / master ZJIT; A/A −0.06 / +0.04 / 0.00%); through preload 757 → 730, −0.20% / −0.52% / −0.49% ([evidence](rails-open-evidence.md)). AR sqlite3 10,270 runs, 0 failures. Body updated through REST, no comment. Reviews on `2fb7374`: Sol approve on both rubrics (L1); Astra request-changes with two findings, **accepted** because the exactness checklist accepts overrides of private (`:nodoc:`) methods: (1) a prepended `likely_reflections` that memoizes or freezes its result breaks `target_classes`' `delete_if`/`map!`; (2) a prepended `immediate_future_classes` that freezes or retains its result sees `future_classes` concat into it. Astra's 16 stock and custom-loader cases (polymorphic, through, nested, already loaded) matched base in SQL sequence, loaded graph and order.
  - [#59565](https://github.com/rails/rails/pull/59565), PostgreSQL adds a cast hint when a bind parameter follows a type name or `IS` (`DATE $1`), anchored on the reported error position — the error #58427 extended to `find_by_sql`/`count_by_sql`; byroot invited such a hint in #55439. Error-message only, no allocation claim. From the Rails main watch (bet R1). Two Sol rounds (whole-SQL regexp matched literals/comments; `$` identifier boundary); opened 2026-11-03.
- From the CPU deep dives (bets V1 and A1; instruction counts with A/A, no timing claim). Sol on both rubrics, then an adversarial Astra round (DECISIONS 2026-11-03). Opened 2026-11-03.
  - [#59569](https://github.com/rails/rails/pull/59569), `AssociationScope` builds its `AliasTracker` only for through chains — `post.author` −6.5% / −5.3% instructions; shipit −2.6% / −1.8%; −2 objects per association scope (36–42 of 56 workloads). Boundary: a direct scope no longer checks out a connection while it is built. Astra P3 (prepends of the private `get_chain` get a Relation) accepted.
  - [#59570](https://github.com/rails/rails/pull/59570), `OutputBuffer#<<` runs the escape steps inline instead of `ERB::Util.unwrapped_html_escape` — per append 141 → 110 ns / 68 → 52 ns; erubi-rails −5.8% / −5–6% instructions. Boundary, left to the reviewer: modules prepended to `ERB::Util`'s singleton class no longer see template appends (Astra showed this also holds for prepends after load, so the description says so).
  - [#59574](https://github.com/rails/rails/pull/59574), `Arel::Table.new` accepts a positional table name again with a deprecation warning (removed without one in #57829; byroot suggested the shim there) — flipper-active_record 1.4.2, Discourse and Docuseal break on main without it. Compatibility fix, not an allocation change; about 40 ns per uncached construction from the optional parameter, which requests do not hit. Sol: request-changes (`name: nil` conflict, standalone `require "arel"`), fixed, approve. Head `79b81aa`. Opened 2026-11-03 ([record](arel-table-positional.md)).
  - [#59584](https://github.com/rails/rails/pull/59584), before Ruby 4.1 `JSONGemCoderEncoder` escapes by searching for each of the five characters with `include?` instead of one `gsub!` over a Regexp union — `posts.to_json` −4.5% / −6.1% instructions (interp / YJIT), jbuilder −2.9% / −6.1%, `render json:` before 8.1 −6.0% / −7.0%, text with `<b>`/`&` −14% / −15%; ruby-bench railsbench YJIT −0.28% and −0.76% in two runs (A/A −0.08% / +0.04%), the rest within noise; Ruby ≤ 4.0 only (4.1 takes `tr!`), so no ZJIT number (bet S1, [record](serialization-cpu.md)). History: the full variant (`e13f3f6`, both encoders, bound-method guards) went through six Sol + adversarial Astra rounds (subclasses, SafeBuffer, singleton `include?`/`equal?`/`force_encoding`, proxies, pre-4.0 Ractor IsolationError) and was held after fatkodima's objection on #59577; replaced by the coder-only variant, which no custom `stringify` can reach. Sol approve on both rubrics; Astra: settings read before `force_encoding` changed error precedence for a frozen String, fixed (main's order); accepted: a prepended `String#gsub!` sees two String-pattern calls instead of one Regexp call (same bytes). Lib +9/−8, L1. Head `8f77e33`, `fa18f3fbf9` on 2026-11-04 (change for amatsuda's request, in flight). Opened 2026-11-03. amatsuda (2026-11-04 00:55 UTC) measured `escape!` slower on small documents with five `include?` scans; our reply (06:11 UTC) kept the single regexp `gsub!` when JS separators are escaped too and his three direct checks only when they are off (the `load_defaults 8.1` default), head `fa18f3fbf9`, title now "Escape HTML entities from JSON::Coder with direct checks". amatsuda (07:23 UTC) suggested applying the same pattern to `JS_SEPARATORS` (two `include?`-guarded `gsub!` for U+2028/U+2029) — measured: separate `gsub!` calls get slower once the document has characters to escape (his version 5,169 vs 2,999 ns on main with YJIT on a short document with `&`, `<b>`, U+2028 and U+2029). Head `fc24e18ab8` (2026-11-04) keeps main's single `gsub!` and skips it only when `include?` finds none of `<`, `>`, `&`, with JS separators off: `{"id":1,"name":"x"}` 354 → 278 ns, 11-column record 759 → 328 ns (YJIT); a short document with characters to escape is the same in the interpreter and 10% slower with YJIT (2,316 → 2,550 ns; Callgrind +2.7% / +2.3%); JS separators on unchanged. CI green; [reply](https://github.com/rails/rails/pull/59584#issuecomment-6627536108) posted 09:34 UTC.
  - [#59608](https://github.com/rails/rails/pull/59608), `prepend_formats` skips `formats | current` when the template's single format already leads the lookup formats; `formats=` still expands `*/*`, removes duplicates, validates and adds the JS→HTML fallback — `prepend_formats(:html)` with the 36 default formats 4,667 → 3,217 ns / 4,226 → 2,631 ns; erubi-rails −2.2% / −4.1% instructions with fixed heap floors (A/A −0.06% / −0.18%), 4.1dev −1.5% / −2.5%; 2 fewer objects per render. Only renders outside a request without `formats:` gain; requests, partials and Turbo Stream broadcasts (`formats:` given) don't ([record](actionview-cpu.md#c3-prepend_formats-skips-the-union-when-the-format-already-leads)). Sol: sound, one fix (empty lookup formats with `[nil]` skipped validation; `!current.empty?` added, regression test); accepted: the private method now returns the existing Array (duplicates kept) instead of a fresh union, which `TemplateRenderer` ignores. 117-case differential identical to main; Action View 3,385 and Action Pack 4,505 runs green. Rewritten as an explicit `if`/`else` for readability (same logic; take the current formats, keep them if the template's single format already leads, otherwise put it in front), rechecked and force-pushed with a lease before any review. Lib +8/−1. Head `ce95f14`. Opened 2026-11-04.

### Inertia — inertiajs/inertia-rails

- [#441](https://github.com/inertiajs/inertia-rails/pull/441), the renderer reads `X-Inertia-*` headers by Rack env key like the middleware — 8 header-key Strings per render → 0; 42/55 workloads across six Inertia apps. Sol approve on both rubrics; opened 2026-11-03.
- [#442](https://github.com/inertiajs/inertia-rails/pull/442), the props resolver asks only prop types for deferred?/once?/rescue? (bug fix: a plain record with a `once` column raised `NoMethodError`, one with `deferred` was dropped), walks hashes with `each` and copies plain values without paths — 23-value page **165 → 40** objects, 73 → 38 µs interpreter; 41/55 Inertia workloads, median **−1.8%** (Hackatime XHR −14%). Three commits in one PR (no stacking). Sol approve / approve-with-nits (spec gap fixed); opened 2026-11-03.

### Importmap — rails/importmap-rails

- [#336](https://github.com/rails/importmap-rails/pull/336), construct modulepreload tags without per-module tuples/options — **2 objects/module** saved on Ruby 4.0.7 (**3** on tested master 4.1), empty control **6 → 6**; seven-package blog `GET /articles` **15.75 fewer objects/request [13.90, 16.20]**, interpreter total Ir **−0.0997% [−0.127, −0.080]**, no-GC **−0.0728%**. Instruction A/A is within ±0.1%, but native CPU A/A failed: **no CPU or JIT speed claim**.

### SQLite — sparklemotion/sqlite3-ruby


### Time zones — tzinfo/tzinfo

- [#171](https://github.com/tzinfo/tzinfo/pull/171), directly decode signed 64-bit TZif transitions — complete synthetic-file reads **288 → 160 objects** for 32 negative transitions and **72 → 60** for six signed boundaries; positive/empty/format-1 controls unchanged. Allocation-only, not speed; oldest MRI/JRuby engine checks ran, but Windows/32-bit/rest of CI matrix did not.


### Lint safety — rubocop/rubocop-performance

- [#550](https://github.com/rubocop/rubocop-performance/pull/550), mark `ChainArrayAllocation` unsafe and document ownership — normal offense identities unchanged; `--safe` excludes the enabled cop (Fizzy **3 → 0**, Campfire **10 → 0** offenses). No autocorrection/performance change; a separate `scan.map!` experiment passed **1,321 examples** yet broke a retained String-subclass result, demonstrating why own-suite success is insufficient.
- [#551](https://github.com/rubocop/rubocop-performance/pull/551), preserve `RedundantStringChars` correction boundaries and mark it unsafe — **10,234** bounded plain-String runtime comparisons match values/classes/encodings or exception classes; this is correctness validation, **not a speed measurement or subclass-safety proof**. SafeBuffer indexing can silently retain HTML safety, so `--safe`/`-a` exclude correction.
- [#552](https://github.com/rubocop/rubocop-performance/pull/552), clarify `Casecmp` ASCII/Unicode safety — documents differing Unicode case folding/conversion and literal normalization; **no behavior/configuration change or performance measurement**. The cop remains disabled by default and unsafe.

### Lint safety — rubocop/rubocop-rails

- [#1670](https://github.com/rubocop/rubocop-rails/pull/1670), stop `SelectMap` correction across record materialization — the bad correction fetches all columns and raises objects/call from A/A **106.005 / 106.000** to **134.000 (+26.4%)** in the Ruby 3.1.2 / AR 7.2.4 fixture; guard prevents that rewrite. Allocation evidence only, not timing; relation-only chains remain eligible.

### Type tooling — Shopify/tapioca

- [#2748](https://github.com/Shopify/tapioca/pull/2748), avoid forcing unused Rails 8.1+ `ActiveSupport::Configurable` while reflecting — real gem generation succeeds with deprecations set to raise, produces **73 RBI files**, and leaves that autoload pending; explicit usage still warns/generates its RBI. Compatibility fix, **no performance measurement**; full hosted Ruby/Rails matrix left to CI.

### Inertia — inertiajs/inertia-rails

- [#435](https://github.com/inertiajs/inertia-rails/pull/435), redact matching DevTools fragment parameters and array URL headers — live **302/409** redirects stay unchanged while recorded copies redact; **no performance measurement**. Malformed parameter names omit query/fragment rather than recording raw input; arbitrary prop/body URL filtering remains limited.
- [#436](https://github.com/inertiajs/inertia-rails/pull/436), resolve nested serializers returned by prop types — **seven new HTTP regressions fail on base and pass with the fix**, preserving partial/Always/metadata/rescue behavior and single evaluation; correctness/privacy boundary, **no performance measurement**. Generator suite was separate and not run locally.
- [#437](https://github.com/inertiajs/inertia-rails/pull/437), duplicate validated controller config and simplify plain-prop scans — synthetic Ruby 4.0.7/YJIT request CPU paired savings **38.6 / 39.6 / 114.3 / 143.3 µs**, objects saved/request **15 / 15 / 15 / 18** (small JSON/partial/dashboard JSON/HTML); corresponding A/A medians **+1.8 / −1.2 / −2.8 / +14.3 µs**. Spread is p25/p75, not confidence intervals; same-process synthetic CPU evidence, **not end-to-end application latency or test-suite speedup**.

### Vite — skryukov/rails_vite

- Issue [#56](https://github.com/skryukov/rails_vite/issues/56) (same change as #57): closed by us on 2026-11-03 20:51 UTC, "Closing in favor of #57, which proposes the same change."
- [#57](https://github.com/skryukov/rails_vite/pull/57), memoize manifest digests only outside local environments — local reloads, missing-manifest recovery and `RailsVite.reset!` remain live; **no performance measurement in the PR body**. Missing manifests are deliberately not cached.

### Campfire — basecamp/once-campfire

- [#350](https://github.com/basecamp/once-campfire/pull/350), native shared fragments plus the retained per-worker hot-path cache, dependent on #345 — previously unwarmed-session room/page/search **98.48 → 44.73 / 84.19 → 28.45 / 159.67 → 46.23 ms** (−55%/−66%/−71%); warm response hits remain **1.8–2.2 ms**, unrelated-commit changes **+1%/+5%/−3%** are within noise, and current-head cold renders **6–10%** faster supersede a prior-head **35–40%** regression. Single-process integration timings, **not universal speedup, HTTP throughput or multiworker-load evidence**; shared-cache contention and JSON throughput remain unmeasured.
- [#352](https://github.com/basecamp/once-campfire/pull/352), skip needless text-message presentation work — 160-message filter/render micro **1.91 → 1.52 ms/message**; cold 80-message room/page/search **112.3 → 103.8 / 114.3 → 101.3 / 235.8 → 201.8 ms** (−7.6%/−11.4%/−14.4%). Single-process, one-machine measurements; workload/environment dependent, not a throughput claim.
- [#374](https://github.com/basecamp/once-campfire/pull/374), parse CSP importmap base URL once/request — with 90 pins, URI parses **180 → 91/call**, method allocations **5,696.1 → 2,306.2/call** and CPU **1,682 → 678 µs** (medians of cohort medians). Request A/A ranges **−4.8% to +10.6%** cached / **−1.9% to +4.7%** uncached preclude a precise end-to-end speedup; fixture time frozen/CSRF disabled, warm fragments retained, **not HTTP throughput**.

## Campfire maintenance

**Checked on 2026-11-02:** merged [#341](https://github.com/basecamp/once-campfire/pull/341) (libvips blocking test), [#342](https://github.com/basecamp/once-campfire/pull/342) (RuboCop), [#343](https://github.com/basecamp/once-campfire/pull/343) (Puma 8), [#344](https://github.com/basecamp/once-campfire/pull/344) (Ruby 4.0.7); open [#345](https://github.com/basecamp/once-campfire/pull/345) (Solid Cache), [#346](https://github.com/basecamp/once-campfire/pull/346) (Solid Queue), [#347](https://github.com/basecamp/once-campfire/pull/347) (Solid Cable, dependent on #345/#346). Maintenance/operational work, not performance claims; #343's local HTTP benchmark was unavailable, and the store/queue cutovers have explicit migration/deployment limits. Also open and not listed before 2026-11-03: [#320](https://github.com/basecamp/once-campfire/pull/320) (Bearer auth for bot API routes with key-free URLs) and [#417](https://github.com/basecamp/once-campfire/pull/417) (retry interrupted jobs that are safe to run again). Codex review findings on #347 from 2026-10-09 (a P1 about `hooks/post-restore` dropping queued cleanup jobs on restore, and three P2s) have no reply.

## Reviews

- **Open; checked on 2026-11-02:** [mikel/mail#1693](https://github.com/mikel/mail/pull/1693), another author's MIME/attachment allocation PR, was [validated rather than duplicated](https://github.com/mikel/mail/pull/1693#pullrequestreview-5620401003). Our Ruby 4.0.8 review measures body-check **201 → 0 objects/call**, missing-header filename **30 → 18**, present-header control **34 → 34**; it finds an **invalid-UTF-8 `IndexError` regression** after a newline, plus a `$/ = nil` compatibility edge. Synthetic in-memory message flows are not SMTP delivery; A/A outliers of **18%/26%** preclude a firm delivery-speed claim. The census's **108 attributed objects/operation** are not 108 proven removable allocations.

## Roundhouse

Compiler/runtime/CI work in Roundhouse, not additional performance
PR measurements. The repository moved from `rubys/roundhouse` to
`roundhouse-rb/roundhouse`; old links redirect. Titles and states only; all
**checked on 2026-11-02** via individual `gh pr view` calls. Includes
merged/open PRs created since 2026-10-19, not closed superseded work.

### Merged

- [#1067](https://github.com/rubys/roundhouse/pull/1067) — Extract #856 typed-update attrs policy from params — merged.
- [#1068](https://github.com/rubys/roundhouse/pull/1068) — Move fresh_when and stale? onto the conditional_get reopen — merged.
- [#1069](https://github.com/rubys/roundhouse/pull/1069) — Share alias copies and extract table-prefix scanners (#823) — merged.
- [#1070](https://github.com/rubys/roundhouse/pull/1070) — Hoist a traced instance Object#extend onto one .new — merged.
- [#1071](https://github.com/rubys/roundhouse/pull/1071) — Run Campfire's room counter through ActiveRecord database tasks — merged.
- [#1072](https://github.com/rubys/roundhouse/pull/1072) — Decide a has_many :through join once — merged.
- [#1073](https://github.com/rubys/roundhouse/pull/1073) — Avoid cloning the full App for Data.define factory emission — merged.
- [#1074](https://github.com/rubys/roundhouse/pull/1074) — Lower the untyped ratchets onto the measured residual — merged.
- [#1076](https://github.com/rubys/roundhouse/pull/1076) — Type a stored lambda's parameters from its .call sites — merged.
- [#1077](https://github.com/rubys/roundhouse/pull/1077) — Wire validates options the lowerer already emits — merged.
- [#1078](https://github.com/rubys/roundhouse/pull/1078) — Meta PR: lowering gaps from a large Rails app — merged.
- [#1079](https://github.com/rubys/roundhouse/pull/1079) — Meta PR: Inertia Rails patterns — merged.
- [#1088](https://github.com/rubys/roundhouse/pull/1088) — Compile BuildTarget on wasm — merged.
- [#1093](https://github.com/rubys/roundhouse/pull/1093) — Meta PR: framework constants the Ruby runtime was missing — merged.
- [#1097](https://github.com/rubys/roundhouse/pull/1097) — Borrow class-side macro methods and copy only included modules — merged.
- [#1106](https://github.com/rubys/roundhouse/pull/1106) — Serve baked Tailwind at the Propshaft digest on JRuby — merged.
- [#1113](https://github.com/rubys/roundhouse/pull/1113) — Fix main-unit reds: relative reload + class-body constant — merged.
- [#1115](https://github.com/rubys/roundhouse/pull/1115) — Spinel lane: honest shapes Spinel can compile — merged.
- [#1116](https://github.com/rubys/roundhouse/pull/1116) — html_escape answers a fresh String when the input is already safe — merged.
- [#1120](https://github.com/rubys/roundhouse/pull/1120) — CI: Spinel optimization meta (reuse bin, compile-once, path-own main) — merged.
- [#1121](https://github.com/rubys/roundhouse/pull/1121) — Schedule Full validation about every three hours — merged.
- [#1131](https://github.com/rubys/roundhouse/pull/1131) — CI: drop advisory campfire-latest tip job — merged.
- [#1132](https://github.com/rubys/roundhouse/pull/1132) — Crystal: stamp Hash return onto empty `{}` tails — merged.
- [#1136](https://github.com/rubys/roundhouse/pull/1136) — Spinel: pin Tep::Response#headers as Hash[String, String] — merged.
- [#1138](https://github.com/rubys/roundhouse/pull/1138) — CI: rename SPINEL11→SPINEL; demote smoke/sidekiq; skip missing docker.tgz — merged.
- [#1194](https://github.com/rubys/roundhouse/pull/1194) — Bump ruby-prism to 2.0.0 and rubydex to v0.4.2 — merged.
- [#1206](https://github.com/rubys/roundhouse/pull/1206) — Use Prism 2 line_offsets, sharper recovery diagnostics, StringQuery audit — merged.
- [#1212](https://github.com/rubys/roundhouse/pull/1212) — Escape control characters in Prism recovery previews — merged.
- [#1231](https://github.com/roundhouse-rb/roundhouse/pull/1231) — Test ownership of emitted truncate results — merged.
- [#1233](https://github.com/roundhouse-rb/roundhouse/pull/1233) — Respect app helper return types in ActionView analysis — merged.
- [#1275](https://github.com/roundhouse-rb/roundhouse/pull/1275) — lower: association-build temps skip a leading underscore — merged.
- [#1438](https://github.com/roundhouse-rb/roundhouse/pull/1438) — ingest: Mentions word index stays single-map when serial — merged.
- [#1442](https://github.com/roundhouse-rb/roundhouse/pull/1442) — ingest: refuse unsafe file-level constant hoists — merged.
- [#1443](https://github.com/roundhouse-rb/roundhouse/pull/1443) — lower: warn on eager find under an aggregate on untyped subclasses — merged.
- [#1444](https://github.com/roundhouse-rb/roundhouse/pull/1444) — lower: quiet non-loading in_batches; keep where.find.count warned — merged.
- [#1451](https://github.com/roundhouse-rb/roundhouse/pull/1451) — ingest: use crate::det hash maps in file_constant_hoist — merged.

### Open

None.

## Held

- **T2, Array tag attribute values joined without `safe_join` (2026-11-04): parked as a lead.** Branch [`thomasklemm/tag-option-array-join`](https://github.com/thomasklemm/rails/tree/thomasklemm/tag-option-array-join) @ `6181372aa1`, exact and reviewed (`class: [a, b]` 13 → 11 objects, −10% instructions in every mode; [record](actionview-render-c10.md#t2-join-array-tag-attribute-values-without-a-safebuffer)). Not opened because it is narrow (only Lobsters renders Array attribute values in any number, about 50 per home page) and it moves the `safe_join` override boundary for a small gain.
- **B1-1, route source locations (2026-11-03):** exact, development-only. It computes `route_source_location`'s
  Action Dispatch directory once instead of per route. Per call: 4.4 → 1.9 µs interpreter, 3.8 → 1.7 µs YJIT,
  2.7 → 1.5 µs master ZJIT. That is 4–5% of a development route redraw and about 1–2% of a dev reload request.
  Branch [`thomasklemm/route-source-location-dir`](https://github.com/thomasklemm/rails/tree/thomasklemm/route-source-location-dir)
  ([`a9c03b098e`](https://github.com/thomasklemm/rails/commit/a9c03b098e76861d8b9d4d2ed51a27fbd95570b2)), with a draft
  in [rails-boot.md](rails-boot.md#b1-1-compute-the-action-dispatch-directory-once-for-route-source-locations).
  Held until the "is it worth it?" discussion on [#59577](https://github.com/rails/rails/pull/59577) is settled; #59577 was closed on 2026-11-04 as superseded by #59590, so B1-1 needed its own decision: parked as a lead (2026-11-04). It is exact but development-only (about 1–2% of a dev reload request), and Rails slots go to production hot paths first.

## Drafted, not opened

- **Gem census (2026-11-03):** two i18n candidates and one connection_pool candidate on `thomasklemm` forks, with
  drafts, in [gem-census.md](gem-census.md#candidates): I1 −0.40% and I2 −0.32% of all census allocations (exact
  versions after Sol review), C1 −4 objects per `ConnectionPool#with`. C1 is open as
  [connection_pool#225](https://github.com/mperham/connection_pool/pull/225) and I1 as
  [i18n#763](https://github.com/ruby-i18n/i18n/pull/763), I2 as [i18n#764](https://github.com/ruby-i18n/i18n/pull/764).

## Investigated, not submitted

- **Active Record read path beyond C11 and #59141 (2026-11-04): no candidate.** In association loading, scoping and record instantiation, every census 8 line above 0.06% is covered by an open or merged PR (#59568, #59554, #59583, #59564, #59612, #59530, #59141), deliberate (`has_default_scope?`'s `method().owner`, #59234), or a single read or guard. One lead was parked: `ThroughReflection#options` goes through `delegate` (96 → 40 ns interpreted, 70 → 30 ns YJIT, at most about 0.07%), but hand-defining only `options` next to the bulk `delegate` needs a comment (L2–L3) in a file with 12 commits since October ([record](ar-read-paths.md)).
- **Active Model per-request paths (2026-11-04): no candidate.** The large lines (`LazyAttributeSet#keys`, `IndexedRow`, `AttributeSet#[]`, `Attribute#hash`/`Type::Value#hash`) are covered by open #58002, #59141 and #59518. The rest are below 0.04% of census 8's interpreted instructions, recently reworked (mutation tracker), or not exact (`sanitize_for_mass_assignment` Hash fast path). CS-1, `Type::String#cast_value` with `dup` instead of `String.new`, was built and rejected: it is 3× faster for unfrozen sources, but for frozen ones, which is how sqlite3 returns values, `String.new` shares the buffer (40 B, 179 ns at any length) where `dup` copies it (640 B, 309 ns at 300 chars). `dup` also copies instance variables ([record](activemodel-request-paths.md)).
- **C12, Action View rendering pipeline beyond tag helpers (2026-11-04): no candidate.** Template lookup, partial and collection rendering, compiled-method dispatch, `OutputBuffer`, form builders, `t`, and Active Model validations and serialization: every site is below 0.03% of census 8's interpreted instructions, reworked on main since September, or already ruled out. `safe_join` (0.08% / 0.11%) has no exact rewrite, and its main caller is parked T2. Two leads were measured and not built: `OutputBuffer.new` without `String.new("")` (−90 ns per call, about 0.015%, needs an identity-check sentinel, L2) and `field_id` skipping `gsub` for plain names (−2 objects, −200 ns, form pages only, about 0.01%) ([record](actionview-render-c12.md)).
- **IW, `index_with` on Array subclasses (2026-11-04): lead, not opened.** Since byroot's 2b88dc1995 (unreleased; our merged #59555 kept `to_h` in `Array#index_with`), an Array subclass that overrides `each` gets its stored elements as keys (`Tens[1, 2].index_with { _1 }` is `{1=>1, 2=>2}` on main, `{10=>10, 20=>20}` on 8.1.4.1). Built as [`thomasklemm/index-with-array-subclass-each`](https://github.com/thomasklemm/rails/tree/thomasklemm/index-with-array-subclass-each) @ `2486c9d447` (subclasses take `super`; test fails on main; Active Support suite green), but it adds +5.3% / +2.7% instructions (interpreter / YJIT) to every plain-Array `index_with`, for a case `Array#map` and `#to_h` ignore too, and it conflicts with our open #59557, whose test pins main's behaviour. Coordinator agreed: don't open ([record](rails-issue-fixes.md#census-backlog-findings-c14)).
- **SafeBuffer.new lead (C10, 2026-11-04): recorded, no ruby/ruby PR or issue.** `new` on a String subclass misses `opt_new` because `String` has its own singleton `new`; `SafeBuffer.new` (every `html_safe`) costs 73–86 ns more per call than with the fast path (interpreter / YJIT 4.0.9, interpreter / ZJIT master). HTML pages make 43–698 per page in 4 of 5 apps (Campfire's cached pages none), 0.1–0.3% of an HTML page with YJIT. Avoidable SafeBuffers in Rails are small (already-safe re-wraps 0.8–4 per op; #17250 rejected returning `self`), except `append_tag_option`'s `safe_join`, which became T2 ([record](actionview-render-c10.md#lead-safebuffernew-misses-the-opt_new-fast-path)).
- **R7-2, `Symbol#name` for `Hash#as_json` keys (2026-11-03): not opened.** On 4.0.9 a direct `as_json` with 4 Symbol keys runs −15.9% / −30.9% Ir (interpreter / YJIT), but on Ruby master `Symbol#to_s` already costs what `Symbol#name` does, so the added type check is pure overhead: +12.5% interpreter, +3.2% ZJIT (A/A ≤ 0.12%). Every exact spelling loses on the master interpreter. It would trade a 4.0 gain for a permanent 4.1 loss, and ruby-bench never reaches it. Branch `thomasklemm/hash-as-json-symbol-names` kept ([opening pass](rails-r7-queue.md#opening-pass-2026-11-03-neither-r7-2-nor-r7-1-opens)).
- **R7-1, nested tag values without intermediate Arrays (2026-11-03): not opened.** L2 (two new helpers, one needing a comment) with no measurable app or ruby-bench effect: `build_tag_values` runs 0 times per request in railsbench and lobsters and 1.32 in shipit (~0.001% of a request). Branch `thomasklemm/tag-values-without-copies` kept.

These dispositions are already public Lowrail evidence, not new candidate
claims. Branch-only documents are pinned explicitly because they are not
on main.

- **Rails-main CPU census 8 (2026-11-03):** ranked by instructions, 22 of the CPU top 30 lines allocate nothing and only 5 are in
  census 7's allocation top 30 ([rails-main-census-8](rails-main-census-8.md)). Not built: `apply_inflections` (CPU rank 1; a
  cache is memoization, a combined regexp was #35459), `IsolatedExecutionState.[]` (call overhead), `handler_for` (L2).
  Rejected after measuring: C8-2, a constant default for the generated `where_clause`/`having_clause` readers (interpreter
  −195 Ir per call, but YJIT +121 and ZJIT +57), and ivar reads in `Arel::Collectors::Composite#<<` (YJIT −3 Ir).

- **Census gems on Ruby master (2026-11-03, bet E2):** 11 of the 13 configurations that did not bundle on master
  `9aa0898240` now install and pass `list` through dependency-only master overlays, so 21 of 23 can run on master.
  Released bumps (redcarpet 3.6.1, commonmarker 2.10.1, stackprof 0.2.28, numo-narray-alt 0.10.7, datadog 2.45.0,
  haml 7.5.2, oga 3.5/ruby-ll 2.2.0, skylight 7.0.0) and git sources at existing fixes: nobu's
  [cabo/cbor-ruby#31](https://github.com/cabo/cbor-ruby/pull/31), our getlago/lago-expression#91,
  [vmg/rinku#97](https://github.com/vmg/rinku/pull/97), and IAPark/tiktoken_ruby main. tokenizers 0.6.4 stays
  vendored (fixed only on ankane/tokenizers-ruby master, outside discourse_ai-tokenizers' `~> 0.6.3`). No PR or
  comment was needed, and nothing was posted. Still blocked: Chatwoot, because gjtorikian declined the commonmarker
  0.x port (gjtorikian/commonmarker#424, #430), and Flow, because temporalio has no 4.1 build and its source gem
  cannot build (temporalio/sdk-ruby#218). C8's "msgpack" failure for Lago was cbor's msgpack-derived type names;
  msgpack builds. Details in [gems-on-master.md](gems-on-master.md).

- **Solid Cable YAML rereads:** already fixed by merged [rails/solid_cable#86](https://github.com/rails/solid_cable/pull/86). The [published workload census](https://github.com/thomasklemm/lowrail/blob/0636db9979d847b47697823e90a0066c6b2f48c6/docs/upstream/workload-census.md#priority-lead-solid-cable-yaml-rereads) confirms repeated 3.0.5 config reads versus zero YAML parses in tested 4.1.0 paths; architecture changed too, so this is not an isolated patch benchmark. No duplicate memoization patch.
- **Cache payload Range removal:** saves one object per signed load but is [rejected for resolved ZJIT regressions](https://github.com/thomasklemm/lowrail/blob/367ab4e8f09f7da3424b584859916f717c21af20/docs/upstream/rails-main-census-2.md#cache-payload-slice--rejected-do-not-submit) in binary-version/compressed cases. No qualifying draft or upstream PR; allocation saving alone does not qualify it.
- **Empty finalization queue shortcut:** returning the empty adapter-owned Array aliases live state; the [executed ownership counterexample](https://github.com/thomasklemm/lowrail/blob/367ab4e8f09f7da3424b584859916f717c21af20/docs/upstream/rails-main-census-2.md#rank-51s-return-ownership-counterexample) makes a later call raise. No timing cohort or fork commit.

- **JIT differential run (2026-11-02):** Rails 8.1.4 and Rails main component suites, plus the Campfire, Writebook and Fizzy suites, ran on ruby/ruby master `e83592ba14` under the interpreter and 17 ZJIT/YJIT modes (low thresholds, inline 0/500, small code memory, auto-compaction), with per-test outcomes compared. There were 503 runs. Only one new divergence was found: YJIT raises `Ractor::IsolationError` while compiling a singleton-class guard from a non-main Ractor (fork branch `thomasklemm/ruby:yjit-attached-object-ractor`). Two known divergences were not resubmitted: Shopify/ruby#976 (fixed by open ruby/ruby#18960, verified) and Bug #22419 (an interpreter crash too). Active Storage needs service credentials and was not run, and Railties was not attempted.
- **ZJIT differential rerun (2026-11-03, bet Z2):** the same corpus on master `90dbced795`, under 13 ZJIT modes
  (four of them new) plus the interpreter, with a release and a debug build. There were 351 runs and 620,279 test
  executions, and no new ZJIT divergence: only Shopify/ruby#976 again, timing flakes, and two crashes that also
  happen without the JIT. Details in [zjit-differential.md](zjit-differential.md).

- **YJIT/ZJIT empty anonymous rest (2026-11-02), opened as parity PR [#19655](https://github.com/ruby/ruby/pull/19655):** the interpreter passes a shared frozen empty Array to an anonymous `*` that receives nothing (43683e1e9d); YJIT `gen_send_iseq` and ZJIT master `plan_send_direct_rest_parameter` allocate a new one per call. This explains the YJIT-only Arrays at `Relation.create(model, ...)`, `SQLString#initialize(*)` and `capture(*, **, &block)`. Fork branch `thomasklemm/ruby:jit-anon-rest-empty-frozen` (`f224bff8f8`, YJIT + ZJIT commits with tests, mirroring merged #9972). ruby-bench allocations: YJIT shipit −1.10%, lobsters −0.56%, railsbench −0.12%; timing within A/A on 16 headline workloads, GC count unchanged, estimated shipit effect ≈0.02%. Below the 0.1% bar as a performance PR; only a parity submission is possible. Separate lead: `where!(opts, *rest)` called with a splat allocates 2 Arrays under YJIT vs 1 in the interpreter.

## Updating this ledger

Read the current body and state, not only a search result or an old receipt:

```sh
gh pr view NUMBER --repo OWNER/REPO --json title,url,state,mergedAt,mergeCommit,body
gh search prs --author thomasklemm --repo roundhouse-rb/roundhouse --created '>=2026-10-19' --limit 100
```

Move entries when state changes, refresh the checked-on date, and preserve
each measurement's scope and unfavorable controls. Search limits are not a
completeness guarantee; paginate if the result reaches the limit. Do not
promote branch measurements to main support or infer missing speed numbers.
