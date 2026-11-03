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

- [#59235](https://github.com/rails/rails/pull/59235), skip empty notification-group mapping — no-subscriber and fully silenced handle cycles allocate **2 → 0 objects**; micro throughput is **1.59× / 2.46×** interpreter/YJIT without subscribers and **1.34× / 1.77×** fully silenced. Active-case allocations are unchanged and timings fall within reported error; no request-level improvement claimed. [Merge 206f2c9](https://github.com/rails/rails/commit/206f2c927a91226563af383df871aad745a36eb1).
- [#59236](https://github.com/rails/rails/pull/59236), avoid CurrentAttributes default-pair arrays — objects/reset **2 → 1** empty, **5 → 1** three unset/scalar, **8 → 4** mutable, **7 → 3** callable, **17 → 6** ten mixed; the mixed reset micro is **1.31× interpreter / 1.26× YJIT**, not an application request measurement. [Merge 596da00](https://github.com/rails/rails/commit/596da00373ca9606a4d7741289203fe62d6ce12b).
- [#59244](https://github.com/rails/rails/pull/59244), use nested Symbol attribute names without a copy — **one object per processed nested Symbol key** saved: three-key tags **17 → 14**, two-key aria **18 → 16**, links **19 → 16**, buttons **27 → 24**, in interpreter/YJIT. No stable throughput claim: exploratory timings include lower link/button point estimates; Symbol names are shared/frozen, not identity/mutability-preserving. [Merge 9998e98](https://github.com/rails/rails/commit/9998e98857e606c834659ab0be75b8361c2696b6).
- [#59252](https://github.com/rails/rails/pull/59252), append error-translation keys without ancestor-pair arrays — GC-counter objects/lookup **169 → 167 / 246 → 243 / 398 → 393** for one/two/four ancestors; MemoryProfiler instead counts **1 / 2 / 4** fewer Arrays (**40 / 80 / 160 bytes**) because it excludes internal objects. The synthetic validation-error endpoint saves about **18 objects/request**; mixed timings and noisy A/A establish neither speed nor equivalence. [Merge 0213cf5](https://github.com/rails/rails/commit/0213cf5f4103e509e79f042e10a6297bd4ceaf50).
- [#59270](https://github.com/rails/rails/pull/59270), reuse delegated-type helper names — **2 → 1 allocations/call** in interpreter/YJIT/ZJIT; median million helper calls/s **0.977 → 1.181 / 1.358 → 1.594 / 1.371 → 1.748**, respectively. Helper microbenchmarks only, not application-level speedups. [Merge ab5a78a](https://github.com/rails/rails/commit/ab5a78a7c221915cbf09c2824068c4479d144f91).
- [#59274](https://github.com/rails/rails/pull/59274), reuse unique asset-tag source arrays — **one Array/helper call** saved in all nine cases and interpreter/YJIT/ZJIT (default **29 → 28**, three stylesheets **64 → 63**, preload-disabled/deferred **22 → 21**). Allocation-only: two ZJIT A/A timing controls exclude parity; no speedup/application saving claimed. [Merge e4fd6cb](https://github.com/rails/rails/commit/e4fd6cb9678755b209de3fbb79ccb36f4311e4dc).
- [#59278](https://github.com/rails/rails/pull/59278), reuse PostgreSQL result fields while casting — **one Array per column-bearing result**, including zero rows: **11 → 10 / 10 → 9 / 72 → 71 / 16 → 15** objects/cast across the four fixtures; zero-column control unchanged. All 108 preregistered interpreter/YJIT/ZJIT workers retain the delta; noisy CPU intervals support **no speed or Ir claim**. [Merge fb7501a](https://github.com/rails/rails/commit/fb7501ad2d7f77713a7de4ed20db1d1d5b5f1c02).
- [#59533](https://github.com/rails/rails/pull/59533), build `WhereClause#ast` predicates in one pass — one Array fewer per compiled where clause, interpreter and YJIT alike. Allocation-only. **Merged 2026-11-02.** [Merge b5be036](https://github.com/rails/rails/commit/b5be03636e0ac5c3d763411b8be9300e589a0953).

### Ruby — ruby/ruby

**Merged; checked on 2026-11-02.** JIT correctness and diagnostics fixes; none claims a speedup.

- [#19485](https://github.com/ruby/ruby/pull/19485), stop ZJIT send counters accumulating across specialization retries — repro counters **[18, 18, 9] → [9, 9, 9]**; railsbench's first two counters **749,107 → 250,038**, control unchanged. Counter-correctness fix; three stats-off chunky-png comparisons ran 2.3–5.7% longer with identical HIR, cause unexplained, **no performance claim**. [Merge 8258233](https://github.com/ruby/ruby/commit/8258233785195eb92e05e7bd964d0b00d94ed824).
- [#19538](https://github.com/ruby/ruby/pull/19538), exit with the original send's stack on ZJIT stack overflow — master crashed or returned wrong arguments for default-filled/reordered keywords, rest and `&nil` sends at all 12 tested VM stack sizes; the PR passes all of them. Correctness fix, normal path unchanged. [Merge 461085c](https://github.com/ruby/ruby/commit/461085c2c7c23a0c3393223d603d4254f30f6f7c).
- [#19554](https://github.com/ruby/ruby/pull/19554), YJIT falls back for explicit keywords in IFUNC block calls — `enum_for` with `yield [], key: 1` returned `[[[], 1]]` instead of the interpreter's `[[[], {key: 1}]]`. Correctness fix. [Merge 54d0988](https://github.com/ruby/ruby/commit/54d098816777fd29e716746c2adcb3bbe4f88710).
- [#19586](https://github.com/ruby/ruby/pull/19586), ZJIT guards the lookup CME when resolving aliases — re-aliasing a module method could keep calling the old target; regressions for sends and `super` fail without the fix. [Merge 1654a6a](https://github.com/ruby/ruby/commit/1654a6a0fd71ef962635d1322a37cc50f908d91a).
- [#19619](https://github.com/ruby/ruby/pull/19619), backport of #19554 to `ruby_4_0`, requested in review. [Merge 9bebcb4](https://github.com/ruby/ruby/commit/9bebcb455f0f9ddbd4af1d3e5dcf2a96b508a455).

### SQLite — sparklemotion/sqlite3-ruby

- [#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758), avoid a row Array on statement completion — **one Array/completed statement, not per row**: empty SELECT **2 → 1**, one-row SELECT **4 → 3**, empty UPDATE **2 → 1** objects; repeated DONE stays zero. Allocation-only; no speed, latency or CPU no-regression claim. **Merged; checked on 2026-11-02.** [Merge 526d4e1](https://github.com/sparklemotion/sqlite3-ruby/commit/526d4e1d8aea588950850d4a204f298616d95b81).

### Prism — ruby/prism

- [#4298](https://github.com/ruby/prism/pull/4298), add Rust `Version::CRuby4_0`, retaining deprecated `CRuby3_5` — both select the same grammar; naming/API compatibility work, **no performance measurement**. Exhaustive matches need the new arm and old-variant uses warn. [Merge ca888b3](https://github.com/ruby/prism/commit/ca888b3a0e715b36a18fb8da0bd89fc7615e9a18).

### Campfire — basecamp/once-campfire

These performance-related PRs were opened before the October 19–22 census.

- [#318](https://github.com/basecamp/once-campfire/pull/318), query sidebar directs and shared rooms separately instead of loading all memberships then splitting/re-sorting — **no benchmark number in the PR body**. [Merge 0d5998f](https://github.com/basecamp/once-campfire/commit/0d5998f05778bf12c73bec3972e3dfa86a5a3af2).
- [#337](https://github.com/basecamp/once-campfire/pull/337), serve bot-page totals from SQLite-maintained `rooms.messages_count`, including bulk/foreign writers — removes the per-page messages `COUNT(*)`; **no measured speedup in the PR body**. This is the trigger-based revision, not the superseded callback counter cache. [Merge fd49099](https://github.com/basecamp/once-campfire/commit/fd490997290b930585b54aa87bde2a7ce1c69204).
- [#339](https://github.com/basecamp/once-campfire/pull/339), move SQLite WAL checkpoints off the request thread to an elected writer with a dedicated connection — **250 ms** PASSIVE loop, unchanged journal mode/`synchronous=NORMAL`; configuration/design evidence, **no benchmark number in the PR body**. [Merge e55b6dc](https://github.com/basecamp/once-campfire/commit/e55b6dc3e534e6dd884eb74eac387fd576c3e6a9).

## Closed

- **Closed unmerged; checked on 2026-10-23:** [ruby/ruby#19478](https://github.com/ruby/ruby/pull/19478), ZJIT empty keyword-rest direct sends, closed in favor of [#19488](https://github.com/ruby/ruby/pull/19488), which carries both commits, at [k0kubun's suggestion](https://github.com/ruby/ruby/pull/19478#issuecomment-6353913049). This is consolidation, not a merge; the historical microbenchmark remains in the closed PR.
- **Closed unmerged by the author; checked on 2026-11-02:** [ruby/ruby#19488](https://github.com/ruby/ruby/pull/19488), the consolidated ZJIT empty/literal keyword-rest PR, closed 2026-10-26 following k0kubun's complexity concern ([closing comment](https://github.com/ruby/ruby/pull/19488#issuecomment-6423531796)): on ruby-bench the removed literal-keyword fallbacks are about **0.07%** of sends on railsbench and **0.03%** on shipit, the hottest affected callees save roughly 40 ns/call, and headline timings stay within A/A noise for ZJIT and YJIT. Its earlier fallback counts, micros and headline-fallback reply remain in the closed PR; they are not merged work.
- **Closed by the author on 2026-11-02:** [ruby/ruby#19625](https://github.com/ruby/ruby/pull/19625), ZJIT Ruby fast path for `Integer#step`: tekknolagi noted that ZJIT does not inline blocks and that without a measurable difference on any benchmark it is not worth merging; optcarrot showed 1.006 vs 1.001 A/A.
- **Closed unmerged; checked on 2026-11-02:** [ruby/ruby#19555](https://github.com/ruby/ruby/pull/19555), recompile once when a PatchPoint invalidates a ZJIT final version, closed in favor of another author's [#19617](https://github.com/ruby/ruby/pull/19617), which handles the same case.

## Open

All entries in this section are **open, not merged; checked on 2026-11-02**.
Measurements are the PRs' own, from their original dates.

### Ruby — ruby/ruby

- [#19483](https://github.com/ruby/ruby/pull/19483), guard ZJIT protected sends with runtime caller `self` — earlier stacked prototype permission fallbacks/request **87 → 1** blog, **353 → 9** Fizzy; inherited-options micro ZJIT **−36.45% [−38.75, −34.95]**, but YJIT **+3.61% [+1.26, +6.80]**. Not measurements of this independently master-based PR binary; no master-alone or whole-app speed claim.
- [#19484](https://github.com/ruby/ruby/pull/19484), allow Proc arguments for explicit block parameters in ZJIT — **27 final send fallbacks/request removed in Fizzy, none in the blog**; earlier Arel-style forwarding micro ZJIT **−61.41% [−63.78, −59.53]**, interpreter **+1.75% [+0.03, +3.67]**, YJIT unresolved. Nine unrelated yield fallbacks remain; no request-throughput claim.
- [#19487](https://github.com/ruby/ruby/pull/19487), compile YJIT `super` on Class/Module receivers — untimed singleton-super fallbacks/request **141 → 13** blog, **300 → 16** Fizzy; dynamic dispatch attempts **616 → 488 / 1,304 → 1,020**. Escaping micro: **352 fewer Ir/call (32.20% of marginal work)** and **23.12% less YJIT time [−29.82, −17.35]%**, not whole-request speed. Class/module graph retention remains; ordinary singleton receivers stay refused.
- [#19648](https://github.com/ruby/ruby/pull/19648), YJIT no longer raises `Ractor::IsolationError` while compiling a singleton-class guard on another Ractor's unshareable object (e.g. the block param proxy); found by the JIT differential run through Rails main's `DeprecationTest`. Correctness fix with regression test; Codex Thermos review (GPT-6 Astra) approve on both rubrics. Opened 2026-11-02.
- [#19655](https://github.com/ruby/ruby/pull/19655), YJIT and ZJIT pass the shared frozen empty Array to an empty anonymous `*` at non-splat call sites, as the interpreter has since 43683e1e9d (same change as merged #9972 for anonymous kwrest). Submitted as interpreter parity, not as a speed claim: ruby-bench allocations YJIT shipit −1.10%, lobsters −0.56%, railsbench −0.12%; timing within A/A. Head `3db46445ca` on master b51db981f6; `make check`, btest with both JITs at threshold 1, zjit-check pass apart from pre-existing environment failures. Codex Thermos review (GPT-6 Astra): correctness approve, quality approve-with-nits (move the accessor to jit.c; declined, because yjit.c follows #9972 and k0kubun's request on #19648). Opened 2026-11-02.
- [#19659](https://github.com/ruby/ruby/pull/19659), ZJIT yields directly to simple ISEQ blocks that take fewer params than the args passed, dropping the extras like the interpreter and YJIT (resolves Shopify/ruby#1094, which tekknolagi filed after our closed #19625). `200_000.times { }` 25.2 → 4.6 ns/iteration; `invokeblock_not_specialized` −1% on 16 headline benchmarks; headline timing flat vs A/A. Auto-splat and too-few-args cases stay generic. Codex Thermos (GPT-6 Astra) approve on both rubrics. Opened 2026-11-02; replied on #19625.
- [#19664](https://github.com/ruby/ruby/pull/19664), YJIT no longer dups a splat array before slicing it into a rest parameter (every Rails `where(...)` via `where!(*args)`), interpreter parity from the [JIT parity census](jit-parity-census.md); ruby-bench YJIT objects −0.07/−0.10/−0.13% (railsbench/lobsters/shipit). Astra approve on both rubrics; opened 2026-11-03.
- [#19660](https://github.com/ruby/ruby/pull/19660), `Hash.new` redefinition and prepend are no longer ignored: #19537 registered `BOP_NEW` on Hash's singleton class, which `vm_redefinition_check_flag()` didn't map, so `opt_new` kept its Hash fast path after `Hash.new` was redefined. Correctness fix with a regression test; Codex Thermos (GPT-6 Astra) approve on both rubrics. Opened 2026-11-03. Follow-ups opened 2026-11-03 after Astra re-review (approve, test nits fixed):
  - [#19661](https://github.com/ruby/ruby/pull/19661), Hash subclasses keep the `opt_new` fast path again (interp/YJIT/ZJIT `HI.new` back to pre-#19537 speed, no extra `Hash.new` frame; ZJIT shares one predicate for folded and dynamic receivers).
  - [#19662](https://github.com/ruby/ruby/pull/19662), ZJIT specializes `Hash.new` (`HashAlloc`, stock `initialize` elided only for opt_new's own send) — k0kubun's request on #19537; `Hash.new` 78 → 15 ns. Stacked on #19660 and #19661.
  - [#19663](https://github.com/ruby/ruby/pull/19663), YJIT ports the interpreter's `Hash.new` branch; `Hash.new(0)` 67 → 24 ns. Stacked on #19660 and #19661.
- [#19558](https://github.com/ruby/ruby/pull/19558), ZJIT reprofiles shape-polymorphic send misses — across 16 headline workloads, polymorphic fallbacks **20,763,714 → 16,787,818** and dynamic sends **87,940,035 → 84,116,799** (erubi-rails **12,222,068 → 8,921,915**); megamorphic fallbacks rise **8,175,838 → 8,317,469**. Three interleaved headline runs: geomean PR/base **0.986 / 1.006 / 0.997** versus A/A **1.006 / 0.997 / 0.996**, so **no measurable timing effect**.
- [#19620](https://github.com/ruby/ruby/pull/19620), backport of merged #19554 to `ruby_3_4`, requested in review — correctness fix, no measurement.
- [#19492](https://github.com/ruby/ruby/pull/19492), count YJIT dynamic sends before dispatch — for **1,000** raising, throwing or block-break sends, counter **0 → 1,000**; normal-return control **1,000 → 1,000** and results unchanged. Corrects attempt diagnostics only; **no performance claim**.

### Rails — rails/rails

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
  - [#59551](https://github.com/rails/rails/pull/59551), skip `extending!` in `Relation#merge` when there are no extensions — every merge −1 (`author.posts.count` **100 → 98**); 76/97, median **−5.8**; 63/97 still move with open #59212.
  - [#59552](https://github.com/rails/rails/pull/59552), a direct association reflection's `constraints` returns `scopes` — −2 per direct reflection (`post.comments.size` **249 → 246**); 74/97, median **−7.3**. Boundary: a subclass overriding `chain`.
  - [#59553](https://github.com/rails/rails/pull/59553), frozen empty `default_extensions` without a default scope — −1 per association proxy; 58/97, median **−1.6**. Boundary: a caller mutating the result.
  - [#59554](https://github.com/rails/rails/pull/59554), precomputed bang method names in `Merger#merge` — −1 String per merged value (`post.author` **223 → 222**); 66/97, median **−3.0**. Overlaps open #59212 (with it: 51/97 interpreter, median −1; YJIT within noise), stated in the PR. Sol approve on both rubrics; opened 2026-11-03. On #59212 itself (Sol static review: no findings) we posted the nine-app breadth numbers: 75/74 of 97 workloads, median −46/−49.
  - [#59555](https://github.com/rails/rails/pull/59555), `Enumerable#index_with` yields what `each` yields again — fixes an unreleased regression from 2b88dc1995 where Hash/HWIA receivers got only keys and Struct got member names; `Array#index_with` keeps `to_h`. Sol approve on both rubrics; opened 2026-11-03.

### Importmap — rails/importmap-rails

- [#336](https://github.com/rails/importmap-rails/pull/336), construct modulepreload tags without per-module tuples/options — **2 objects/module** saved on Ruby 4.0.7 (**3** on tested master 4.1), empty control **6 → 6**; seven-package blog `GET /articles` **15.75 fewer objects/request [13.90, 16.20]**, interpreter total Ir **−0.0997% [−0.127, −0.080]**, no-GC **−0.0728%**. Instruction A/A is within ±0.1%, but native CPU A/A failed: **no CPU or JIT speed claim**.

### SQLite — sparklemotion/sqlite3-ruby


### Time zones — tzinfo/tzinfo

- [#171](https://github.com/tzinfo/tzinfo/pull/171), directly decode signed 64-bit TZif transitions — complete synthetic-file reads **288 → 160 objects** for 32 negative transitions and **72 → 60** for six signed boundaries; positive/empty/format-1 controls unchanged. Allocation-only, not speed; oldest MRI/JRuby engine checks ran, but Windows/32-bit/rest of CI matrix did not.

### Spreadsheets — caxlsx/caxlsx

- [#550](https://github.com/caxlsx/caxlsx/pull/550), infer native Integer cell types without decimal Strings — **200,000 fewer objects for 200,000 Integer cells**, **40,000** for the 160,000-cell mixed fixture; one object/Integer in all post-warmup samples. A/A wall medians differed **14.9% / 0.5%**, so allocation-only, not a reliable timing percentage; assumes standard native Integer methods.

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

- [#57](https://github.com/skryukov/rails_vite/pull/57), memoize manifest digests only outside local environments — local reloads, missing-manifest recovery and `RailsVite.reset!` remain live; **no performance measurement in the PR body**. Missing manifests are deliberately not cached.

### Campfire — basecamp/once-campfire

- [#350](https://github.com/basecamp/once-campfire/pull/350), native shared fragments plus the retained per-worker hot-path cache, dependent on #345 — previously unwarmed-session room/page/search **98.48 → 44.73 / 84.19 → 28.45 / 159.67 → 46.23 ms** (−55%/−66%/−71%); warm response hits remain **1.8–2.2 ms**, unrelated-commit changes **+1%/+5%/−3%** are within noise, and current-head cold renders **6–10%** faster supersede a prior-head **35–40%** regression. Single-process integration timings, **not universal speedup, HTTP throughput or multiworker-load evidence**; shared-cache contention and JSON throughput remain unmeasured.
- [#352](https://github.com/basecamp/once-campfire/pull/352), skip needless text-message presentation work — 160-message filter/render micro **1.91 → 1.52 ms/message**; cold 80-message room/page/search **112.3 → 103.8 / 114.3 → 101.3 / 235.8 → 201.8 ms** (−7.6%/−11.4%/−14.4%). Single-process, one-machine measurements; workload/environment dependent, not a throughput claim.
- [#374](https://github.com/basecamp/once-campfire/pull/374), parse CSP importmap base URL once/request — with 90 pins, URI parses **180 → 91/call**, method allocations **5,696.1 → 2,306.2/call** and CPU **1,682 → 678 µs** (medians of cohort medians). Request A/A ranges **−4.8% to +10.6%** cached / **−1.9% to +4.7%** uncached preclude a precise end-to-end speedup; fixture time frozen/CSRF disabled, warm fragments retained, **not HTTP throughput**.

## Campfire maintenance

**Checked on 2026-11-02:** merged [#341](https://github.com/basecamp/once-campfire/pull/341) (libvips blocking test), [#342](https://github.com/basecamp/once-campfire/pull/342) (RuboCop), [#343](https://github.com/basecamp/once-campfire/pull/343) (Puma 8), [#344](https://github.com/basecamp/once-campfire/pull/344) (Ruby 4.0.7); open [#345](https://github.com/basecamp/once-campfire/pull/345) (Solid Cache), [#346](https://github.com/basecamp/once-campfire/pull/346) (Solid Queue), [#347](https://github.com/basecamp/once-campfire/pull/347) (Solid Cable, dependent on #345/#346). Maintenance/operational work, not performance claims; #343's local HTTP benchmark was unavailable, and the store/queue cutovers have explicit migration/deployment limits.

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

## Investigated, not submitted

These dispositions are already public Lowrail evidence, not new candidate
claims. Branch-only documents are pinned explicitly because they are not
on main.

- **Solid Cable YAML rereads:** already fixed by merged [rails/solid_cable#86](https://github.com/rails/solid_cable/pull/86). The [published workload census](https://github.com/thomasklemm/lowrail/blob/0636db9979d847b47697823e90a0066c6b2f48c6/docs/upstream/workload-census.md#priority-lead-solid-cable-yaml-rereads) confirms repeated 3.0.5 config reads versus zero YAML parses in tested 4.1.0 paths; architecture changed too, so this is not an isolated patch benchmark. No duplicate memoization patch.
- **Cache payload Range removal:** saves one object per signed load but is [rejected for resolved ZJIT regressions](https://github.com/thomasklemm/lowrail/blob/367ab4e8f09f7da3424b584859916f717c21af20/docs/upstream/rails-main-census-2.md#cache-payload-slice--rejected-do-not-submit) in binary-version/compressed cases. No qualifying draft or upstream PR; allocation saving alone does not qualify it.
- **Empty finalization queue shortcut:** returning the empty adapter-owned Array aliases live state; the [executed ownership counterexample](https://github.com/thomasklemm/lowrail/blob/367ab4e8f09f7da3424b584859916f717c21af20/docs/upstream/rails-main-census-2.md#rank-51s-return-ownership-counterexample) makes a later call raise. No timing cohort or fork commit.

- **JIT differential run (2026-11-02):** Rails 8.1.4 and Rails main component suites, plus the Campfire, Writebook and Fizzy suites, ran on ruby/ruby master `e83592ba14` under the interpreter and 17 ZJIT/YJIT modes (low thresholds, inline 0/500, small code memory, auto-compaction), with per-test outcomes compared. There were 503 runs. Only one new divergence was found: YJIT raises `Ractor::IsolationError` while compiling a singleton-class guard from a non-main Ractor (fork branch `thomasklemm/ruby:yjit-attached-object-ractor`). Two known divergences were not resubmitted: Shopify/ruby#976 (fixed by open ruby/ruby#18960, verified) and Bug #22419 (an interpreter crash too). Active Storage needs service credentials and was not run, and Railties was not attempted.

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
