# Frontier census F1: Rails main × Ruby master with ZJIT

Bet F1 of the [measurement matrix](measurement-matrix.md): run the census apps on Rails main and Ruby master,
interpreter and ZJIT, so ZJIT work comes from real Rails code and not only from ruby-bench. Nothing was built, posted
or opened.

**Result.** 21 of 23 configurations (18 apps) ran on Ruby master `9aa0898240` × Rails main `c042aee23a`; Flow
and Chatwoot are gaps. The interpreter and ZJIT allocation A/As are +0.0. ZJIT stats on real apps need
`--zjit-exec-mem-size=512`: at the default 64 MiB the code region filled in 18 of 21 stats runs, and even without
stats in Discourse, Loomio, Sure and Mastodon. With room to compile, **771 fallback and exit reasons pass the
acceptance gate** (≥ 3 apps, ≤ 5% run-to-run drift). The ranking matches ruby-bench's (polymorphism first), and
every queued Z10 lead now reaches all 18 apps. New in the apps: a per-request Hash singleton class from
http_accept_language that causes 94–96% of Mastodon's and Loomio's side exits, not-inlined `Hash#key?`,
`html_escape` and `Fiber.[]`, the too-small default executable region, recompiles in three apps, and an
intermittent ZJIT segfault. Master's interpreter allocates 39 fewer objects/op than 4.0.7, with one bisected
regression (an extra Hash for `super` with a keyword rest). Shortlist at the end of the results.

## Pins

* **Ruby:** ruby/ruby master [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)
  (2026-11-03 12:42 UTC, the same pin as F2), release build (`-O3`, GCC 12.2, Rust 1.99.1),
  `./configure --enable-yjit --enable-zjit --disable-install-doc`, installed to `~/rubies/master-9aa0898240`.
  `ruby 4.1.0dev (2026-11-03T12:42:36Z HEAD 9aa0898240) +PRISM`; RubyGems 4.1.0.beta3, Bundler 4.0.20.
* **Rails:** main [`c042aee23a`](https://github.com/rails/rails/commit/c042aee23a56205c43c9a60219cd1c4d7f7576a8)
  (ls-remote 12:59 UTC).
* **ZJIT memory:** allocations ran at the defaults (`--zjit-exec-mem-size` 64 MiB, `--zjit-mem-size` 128 MiB).
  Every stats and trace pass that is reported ran at `--zjit-exec-mem-size=512 --zjit-mem-size=1024` and has 0
  `compile_error_out_of_memory` in every run (checked by `frontier_rank.rb`); the largest code region was 224 MB
  (Sure, with trace sampling). The first passes at the defaults are kept in the record only as the finding below.
  Warmup `CENSUS_WARMUP=200` operations per workload in every pass.
* **Corpus `censusf1`:** `script/census setup --corpus censusf1 --rails c042aee23a… --ruby ~/rubies/master-9aa0898240
  --ruby-overlays fixtures/corpus/frontier-master`, outputs in `.lowrail/private/censusf1` (not committed).

## Apps

21 of 23 configurations run on master (20 apps; fizzy-mysql, mastodon-nops and lago-nops share their app's copy).
Every one passes `script/census list` on master, 227 workloads in total.

| App | Configurations | Workloads | Master changes ([overlays](../../fixtures/corpus/frontier-master/README.md)) |
| --- | --- | ---: | --- |
| Blog, Campfire, Fizzy (+MySQL), CodeTriage, PingCRM, Redprints CFP, react-starter-kit, CASA, Hackatime | 10 | 100 | source builds only (`force_ruby_platform`) |
| Writebook | 1 | 8 | redcarpet 3.6.0 → 3.6.1 |
| Lobsters | 1 | 11 | stackprof 0.2.27 → 0.2.28, commonmarker 2.10.1 |
| Thinkroom | 1 | 9 | commonmarker 2.10.0 → 2.10.1 |
| Docuseal | 1 | 13 | numo-narray-alt 0.10.3 → 0.10.7 |
| Sure | 1 | 9 | stackprof 0.2.28, skylight 7.0.0; **patched gem** (cbor 0.5.10.2, TypedData) |
| Mastodon (+nops) | 2 | 28 | haml 7.5.1 → 7.5.2; **patched gem** (cbor) |
| Lago (+nops) | 2 | 20 | datadog 2.33.0 → 2.45.0; **patched gem** (lago-expression, cap lifted) |
| Discourse | 1 | 14 | **patched gems** (cbor; rinku `RUBY_EXPORT`; tiktoken_ruby and tokenizers, magnus 0.8.4) |
| Loomio | 1 | 15 | oga 3.5, ruby-ll 2.2.0; **patched gem** (cbor); released prism 1.9.0 vendored |
| **Flow** | gap | | temporalio 1.10.0: binaries cap `< 4.1.dev`, source gem's Cargo manifest does not parse. Not attempted |
| **Chatwoot** | gap | | commonmarker 0.23.12 (vendored, last 0.x): 44 untyped-data calls and `RDATA()->dfree` toggling; needs a real port |

Patched gems are the batch-2 decision: the smallest change that builds, recorded with its patch in
[fixtures/corpus/frontier-master](../../fixtures/corpus/frontier-master/README.md). Upstream status:

* **cbor:** [cabo/cbor-ruby#42](https://github.com/cabo/cbor-ruby/issues/42) (open, 2026-10-19, "Does not build on
  Ruby 4.1.0-preview1") and nobu's open [cabo/cbor-ruby#31](https://github.com/cabo/cbor-ruby/pull/31) ("Use typed
  data API"), which predates ours; our cabo/cbor-ruby#43 duplicated it and is closed. The census patch converts
  `Data_Wrap_Struct`/`Data_Get_Struct` to TypedData and nothing else; it builds, round-trips, and survives
  `GC.stress` and `GC.compact`.
* **lago-expression:** no issue about Ruby 4.1 or the `~> 4.0.2` cap; our
  [getlago/lago-expression#91](https://github.com/getlago/lago-expression/pull/91) (open, 2026-11-03) lifts it. Their
  latest Ruby change (getlago/lago-expression#85, merged 2026-11-01) bumped rb-sys to 0.9.130 and left the cap. With
  only the cap lifted, the extension still does not build on master; it also needs rb-sys's
  `stable-api-compiled-fallback` feature, as commonmarker enables. Its 20 specs pass.
* **tiktoken_ruby:** the merged Dependabot bump IAPark/tiktoken_ruby#130 takes magnus to 0.9.0; our
  magnus 0.8.4 bump IAPark/tiktoken_ruby#132 is closed. **rinku:** [vmg/rinku#97](https://github.com/vmg/rinku/pull/97)
  (open since 2024) replaces `RUBY_EXPORT`, the same fix as the census patch. **tokenizers:** no 4.1 issue or PR
  found. Each census patch is lock-level or one macro (README).

## Method

* **Gate:** `script/census list` passes for all 21 configurations; interpreter A/A (`f12 − f1`) median +0.0 (per-configuration medians −3.3 to +2.5 objects/op),
  ZJIT A/A median +0.0 (−3.6 to +5.3).
* **Allocations:** `script/census run --label f1 --aa --modes interp,zjit` (labels `f1`, `f12`), 200 warmup
  operations, then the census measurement windows.
* **ZJIT stats, default counters:** `CENSUS_DEFAULT_COUNTERS=1 script/census run --stats` (labels `f1d`, `f1db` at
  default memory; `f1dm` at `--zjit-exec-mem-size=512 --zjit-mem-size=1024` for the seven apps that failed the gate
  or filled the region): ZJIT without `--zjit-stats`, counters as the difference of snapshots around 20 operations
  per workload after 200 warmup operations, plus totals (memory). This pass gives the compiled-ISEQ gate.
* **Reasons and traces:** two `--zjit-stats` passes over all 21 configurations with `--zjit-trace-exits
  --zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20 --zjit-exec-mem-size=512
  --zjit-mem-size=1024` (labels `f1u1`, `f1u2`). Reason rates are the windowed `per_op` counters; traces (whole
  process, warmup included) attribute reasons to sites via [`jit_parity_fxt.rb`](../../bench/upstream/jit_parity_fxt.rb).
  The earlier trace passes at default memory (`f1t1`, `f1t2`, `f1t1b`, `superseded/f1t2b`) are not reported.
* **Receipts:** A/A compare, sites, `f1dm`, reasons (text and TSV) and the full trace ranking in
  [data/frontier-census-f1/receipts.tar.gz](data/frontier-census-f1/receipts.tar.gz); raw JSONs stay in the orb.
* **Ranking:** [`frontier_rank.rb`](../../bench/upstream/frontier_rank.rb) `reasons` (apps reached with ≥ 1 per
  operation in both runs; accepted at ≥ 3 apps and ≤ 5% difference between the runs' totals), `sites` (ZJIT minus
  interpreter objects per operation by line, ≥ 1 in both A/A labels) and `traces` (sites by apps sampled in both
  trace runs). Configurations of one app count once.
* **Master × interpreter vs 4.0.7:** the census-command copies (`.corpus/census-*`, 4.0.7, census-4 overlays) ran
  Rails `c042aee23a` with their own A/A (`m407`, `m4072`) on the seven SQLite apps, which use no shared server
  database. Census 7's 4.0.7 run (`c72`, Rails `b084108cf3`) differs from `c042aee23a` in six commits touching three
  files (`relation.rb` `one?`/`many?`, two cache stores) and serves as the 20-app cross-check by rank.

## Compiled-ISEQ gate and code size

Compiled ISEQs per operation after 200 warmup operations, both trace runs (`f1u1` / `f1u2`), with the code region
each app used. Every run has 0 `compile_error_out_of_memory`.

| App | ISEQs/op `f1u1` / `f1u2` | Code region (MB, with stats) | Without stats (`f1d`/`f1dm`) |
| --- | ---: | ---: | ---: |
| Blog | 0.28 / 0.25 | 61 | 21 |
| **Campfire** | **1.54 / 1.58** | 95 | 33 |
| CASA | 0.59 / 0.59 | 136 | 47 |
| **CodeTriage** | **2.14 / 2.16** | 85 | 30 |
| Discourse | 0.20 / 0.25 | 214 | 78 |
| Docuseal | 0.12 / 0.12 | 131 | 47 |
| Fizzy, Fizzy-MySQL | 0.19 / 0.16, 0.22 / 0.21 | 152, 151 | 54, 53 |
| Hackatime | 0.19 / 0.14 | 104 | 37 |
| Lago, Lago-nops | 0.29 / 0.29, 0.26 / 0.26 | 153, 148 | 52, 52 |
| Lobsters | 0.08 / 0.08 | 120 | 43 |
| Loomio | 0.42 / 0.42 | 208 | 76 |
| Mastodon, Mastodon-nops | 0.24 / 0.20, 0.25 / 0.22 | 188, 188 | 67, 67 |
| PingCRM | 0.07 / 0.08 | 59 | 21 |
| react-starter-kit | 0.06 / 0.06 | 50 | 18 |
| Redprints CFP | 0.14 / 0.14 | 68 | 24 |
| **Sure** | 0.43 / **1.75** | 224 | 81 (1.74 ISEQs/op) |
| Thinkroom | 0.14 / 0.17 | 70 | 24 |
| Writebook | 0.41 / 0.43 | 91 | 32 |

* **Gate:** 18 configurations are at or below 0.6 ISEQs/op. Campfire and CodeTriage fail it in every pass; Sure
  fails it in `f1dm` and `f1u2` and passes in `f1u1`. Their reasons below still count, but their rates include
  compilation still in progress. Earlier compile/invalidation traces (`f1c`, CodeTriage) show recompiles of the
  Temple dispatcher, `__callbacks` and `_layout`, invalidated by singleton classes created at runtime
  (`extend_object`).
* **Finding: the default executable region is too small for large Rails apps.** Without stats, Discourse (78 MB),
  Loomio (76), Sure (81) and Mastodon (67) need more than the default 64 MiB `--zjit-exec-mem-size`; at the default
  their compilation stops and compiled ISEQs/op reads ≈ 0. With `--zjit-stats` 18 of 21 configurations filled it (all but Blog, PingCRM and react-starter-kit). Raising
  `--zjit-mem-size` alone doesn't help; the executable region is a separate limit. The ZJIT A/A allocation runs
  ran at the defaults, so their numbers for those five configurations come from a partly compiled ZJIT.

## Reasons, ranked by apps reached

`frontier_rank.rb reasons f1u1 f1u2`: 18 apps (21 configurations). A reason reaches an app when it counts ≥ 1 per
operation in both runs. **771 reasons are accepted** (≥ 3 apps, ≤ 5% drift); 78 more reach ≥ 3 apps but drift more
(for example `complex_arg_pass_caller_splat` 49%, `Time#nsec`, `Integer#**`, `String#===`). Per op is the sum over
the 21 configurations of each configuration's per-operation count, mean of the two runs.

**Side exits (all of them)**

| Exit | Apps | Per op (sum) | Drift | Accepted |
| --- | ---: | ---: | ---: | --- |
| `patchpoint_no_singleton_class` | 9 | 39,371 | 0.0% | yes |
| `guard_type_failure` | 18 | 4,832 | 0.7% | yes |
| `patchpoint_stable_constant_names` | 9 | 4,275 | 3.5% | yes |
| `unhandled_block_arg` | 18 | 1,429 | 0.0% | yes |
| `exception_handler` | 18 | 1,231 | 0.5% | yes |
| `guard_super_method_entry` | 11 | 495 | 4.7% | yes |
| `patchpoint_method_redefined` | 11 | 291 | 3.3% | yes |
| `block_arg_not_nil` | 5 | 289 | 0.4% | yes |
| `guard_shape_failure`, `interrupt`, `guard_less_failure`, `guard_not_shared_failure` | 5, 5, 4, 3 | 33, 17, 31, 16 | ≤ 4.6% | yes |
| `compile_error` (`iseq_version_limit_reached`) | 2 | 14 | 6.0% | no |

**Top fallbacks** (all 18 apps, all accepted, drift ≤ 3.5%)

| Reason | Per op (sum) |
| --- | ---: |
| `send_fallback_send_polymorphic_fallback` | 132,150 |
| `getivar_fallback_no_profile_missing_ic` | 126,432 |
| `getivar_fallback_no_side_exits` | 90,096 |
| `send_fallback_send_megamorphic` | 71,013 |
| `invokeblock_handler_polymorphic` | 64,782 |
| `send_fallback_invokeblock_polymorphic_miss` | 41,376 |
| not inlined / not annotated `Hash#fetch` | 24,524 / 30,195 |
| not annotated `Hash#key?` (not inlined: 17 apps, 18,547) | 24,178 |
| `send_fallback_invokeblock_not_specialized` | 19,844 |
| `send_fallback_one_or_more_complex_arg_pass` | 16,821 |
| `send_fallback_sendforward_not_specialized` | 14,855 |
| `send_fallback_send_block_arg_not_nil` | 12,275 |
| not inlined `String#<<` | 9,648 |
| `send_not_optimized_method_type_optimized` (`Kernel#send`) | 8,358 |
| not inlined `Array#include?`, `String#include?`, `Array#any?`, `String#match?`, `String#==` | 8,175, 7,357, 5,665, 5,662, 5,187 |
| not inlined `Fiber.[]`, `Fiber.current` | 4,727, 3,996 |
| `send_not_optimized_need_permission` | 4,659 |
| `send_fallback_singleton_class_seen` (13 apps) | 24,834 |
| not inlined `ERB::Util.html_escape` (15 apps) | 6,294 |

`FixnumLShiftOverflow` (TZInfo `ZoneinfoReader#make_signed_int64`) does not occur in the measured window: it is a
boot-time exit only.

## Sites, ranked by apps reached

`frontier_rank.rb traces f1u1 f1u2` (sampled 1 in 20, whole process): every one of the top 45 sites reaches all 18
apps, with the two runs within 7% of each other. The top sites are the Z10 queue's leads, now on 18 apps instead
of 10: polymorphic yields in `Array#each`/`map`/`find` and `index_with` (lead 1), `BasicObject#!=` (2),
`_reflections`/`attribute_aliases` (3), protected calls in `InheritableOptions#initialize` and `WhereClause#merge`
(4), `Visitor#visit` and TZInfo `Timestamp.new!` `send` (5), `WhereClause#empty?` and `ScopeRegistry.current_scope`
forwarding (6), `&block` in `mon_synchronize`, Notifications fanout, `ConnectionPool::Queue#synchronize` and
`with_connection` (7), `AssociationRoute::Cache#fetch_or_store` (8). The getivar sites (`IsolatedExecutionState.[]`,
`Association#klass`, `WhereClause#empty?`, `Attribute#value`, `Type::Value#hash`) are the gap census's lead 11.

Two exit sites are concentrated in a few apps:

* **`PatchPoint(NoSingletonClass(Hash))`** (9 apps; Mastodon 13,915 and Mastodon-nops 16,105 per op, 95–96% of
  their side exits; Loomio 9,213, 94%). `HttpAcceptLanguage::Middleware#call` (http_accept_language 2.1.1) runs
  `def env.http_accept_language` on every request, so every request creates a singleton class on a Hash. The exits
  land in hot Hash readers: `AttributeSet#[]`, `IndexedRow::Mutable#fetch`, `LazyAttributeSet#fetch_value!`,
  `association_instance_get`, Concurrent `NonConcurrentMapBackend#[]`, `_load_from_sql`, `HashLookupTypeMap#key?`.
  A method that has used up its four versions keeps its final version and side-exits on every call; the repro
  ([data/frontier-census-f1/zjit-hash-singleton-repro.rb](data/frontier-census-f1/zjit-hash-singleton-repro.rb))
  gives 100,000 exits per 100 requests at `--zjit-max-versions=4` and 0 at 5. The other six apps reach it through
  relation and Array singleton classes (`Merger#merge`, `unscope!`), tens per op.
* **`singleton_class_seen` in `IndexedRow::Mutable#fetch`** (`indexed_row.rb:172`, `UNSET.equal?`): 13 apps, up to
  6,999 per op in Mastodon. This is the Z10 queue's lead 10, which reached 6 of 10 apps there.

## ZJIT minus interpreter allocations

`frontier_rank.rb sites f1 f12` (both A/A labels, ≥ 1 object/op in both): 18 apps, 227 workloads.

| Site | Apps | Workloads | Objects/op (sum) | Owner |
| --- | ---: | ---: | ---: | --- |
| `<internal:array>:289` Array (`map`) | 18 | 227 | 34,327 | attribution of block-inlined builtins; see census 8 |
| `<internal:array>:315` Array | 18 | 218 | 4,573 | same |
| `<internal:array>:271` Array, `:267`/`:285` Enumerator, `:291` String | 13–18 | 98–136 | 3,772 | same |
| `persistence.rb:236` String (`"#{self} Update"`) | 15 | 33 | 92 | interpolation, Shopify/ruby#1091 |
| uri `rfc3986_parser.rb:135` Array (`URI.for(*split(uri), self)`) | 14 | 78 | 3,288 | Shopify/ruby#1095 (census 8 lead C) |
| `abstract_adapter.rb:1426` / `:1432` Array | 12 / 7 | 97 / 66 | 1,254 / 1,012 | ruby/ruby#19655 |
| `arel/visitors/to_sql.rb:18` Array | 10 | 25 | 81 | rest-argument copy, as #19655 |
| `tags/text_field.rb:17` Array (`tag("input", options)`) | 6 | 11 | 40 | rest-argument copy, as #19655 |
| `join_dependency.rb:188` String | 5 | 11 | 1,663 | Shopify/ruby#1091 |

The `<internal:array>` rows are where the allocation-site hook attributes Arrays created while ZJIT runs a block of
an inlined builtin; census 8 found no line beyond its lead C with more than 0.3 extra objects/op on Rails main
`1105756f42`, and these rows don't change that. The five configurations whose code region filled in the A/A runs
(Discourse, Loomio, Sure, Mastodon, Mastodon-nops) contribute to these rows like the rest.

## Against ruby-bench (bets Z1 and Z3)

Same as on railsbench, lobsters and shipit ([zjit-gap-census.md](zjit-gap-census.md),
[zjit-polymorphism.md](zjit-polymorphism.md)): the polymorphism family (getivar without profile, polymorphic and
megamorphic sends and yields) dominates, then complex arguments, `sendforward`, `&block`, `Kernel#send` and protected
calls, with the same top sites. **New in the apps:**

1. **The default 64 MiB executable region** is too small for Discourse, Loomio, Sure and Mastodon even without
   stats. Z1 called the out-of-memory a stats artifact; on these apps it isn't.
2. **`PatchPoint(NoSingletonClass(Hash))` per request** from http_accept_language (Mastodon, Loomio): 94–96% of their
   side exits. ruby-bench's apps don't use the gem.
3. **Not-inlined cfuncs on every request:** `Hash#key?` (17 apps, median 408 per op, Discourse 4,669),
   `ERB::Util.html_escape` (15 apps, median 133, Sure 3,571), `Fiber.[]` and `Fiber.current` (18 apps, medians 53
   and 66, Sure 3,069 and 2,220), plus `String#<<`, `Array#include?`, `String#include?`.
4. **`singleton_class_seen` at 13 apps**, where the 10-app census saw 6.
5. **Recompiles after warmup** in Campfire, CodeTriage and Sure (1.5–2.2 ISEQs/op).
6. **A ZJIT segfault** in CASA (below).

## Ownership (checked 2026-11-04)

Assignees and open PRs, Shopify/ruby issues and the 64 open ruby/ruby PRs with "ZJIT" in the title.

| Item | Owner |
| --- | --- |
| polymorphism, getivar without profile | Shopify/ruby#1099 (unassigned); ruby/ruby#19443 (tekknolagi, open), #18616 (draft) |
| polymorphic yields | Shopify/ruby#1093 (k0kubun, assigned); ruby/ruby#19659 |
| `Hash#fetch` | Shopify/ruby#1086 (assigned) |
| `String#match?`, `Kernel#dup` cfunc fast paths | our bet Z7 |
| protected calls | ours, ruby/ruby#19483 (open) |
| `Kernel#send` | tekknolagi, ruby/ruby#19583 (open) |
| `def m(...)` forwarding | nozomemein, ruby/ruby#18326 (open) |
| `&block` forwarding | Shopify/ruby#1014 (unassigned; Z10 queue rank 1) |
| `super` with a block (`unhandled_block_arg`) | Shopify/ruby#1100; U3 builds the fix |
| constant patch points, final versions | k0kubun, ruby/ruby#19617 (open) |
| `exception_handler` | ruby/ruby#18759 (open) |
| `singleton_class_seen` for module receivers | builds on linyiru's ruby/ruby#19658 (open) |
| Hash singleton class per request | linyiru's iain/http_accept_language#80 (open, opt-out); ruby/ruby#19617 on the ZJIT side |
| allocation sites | ruby/ruby#19655; Shopify/ruby#1091, #1095 |
| default exec region size, `Hash#key?`, `html_escape`, `Fiber.[]`/`Fiber.current`, recompile churn, CASA segfault, zsuper keyword-rest Hash | **free** |

## Shortlist: unowned items

All are recorded in the Z10 queue ([zjit-iseq-leads.md](zjit-iseq-leads.md), F1 rows); no ruby/ruby PR comes from
this census while our open ruby/ruby PRs exceed 15.

| # | Item | Apps | Numbers | Next step |
| --- | --- | ---: | --- | --- |
| 1 | `def m(k: 1, **) = super` allocates an extra Hash on master (regression from ruby/ruby#18344, not covered by #19670) | 7 SQLite apps measured | 2 → 3 objects per call. Rails sites with this shape or the forwarding shape #19670 fixes: `url_for.rb:37`, `structured_event_subscriber.rb:86`, `timestamp.rb:129`, `singular_association.rb:52`, `message_verifier.rb:337` (not yet split by shape) | a fix on top of #19670 |
| 2 | Not-inlined `Hash#key?` | 17 | median 408 per op, Discourse 4,669 | annotate/inline like `Hash#[]`; Z7 decides |
| 3 | Default `--zjit-exec-mem-size` 64 MiB below large Rails apps | 4 of 18 without stats | 67–81 MB needed | data for an issue; Thomas decides |
| 4 | Not-inlined `Fiber.[]` / `Fiber.current` | 18 | medians 53 / 66, Sure 3,069 / 2,220 | Z7 |
| 5 | Not-inlined `ERB::Util.html_escape` | 15 | median 133, Sure 3,571 | Z7 |
| 6 | Recompiles after warmup | 3 | 1.5–2.2 ISEQs/op | hand to J1's Z12 |
| 7 | ZJIT segfault in `vm_lookup_cc` (CASA) | 1 | 1 crash in 2 runs, not reproduced | needs a reproduction |

## Master × interpreter against 4.0.7

The seven SQLite apps ran Rails `c042aee23a` on both Rubies with their own A/A pairs (`m407`/`m4072` on 4.0.7,
`f1`/`f12` on master). Both A/A medians are +0.0. Master allocates **39.0 fewer objects per operation at the median**
than 4.0.7; 63 of 68 workloads moved by ≤ −1, and no SQL count changed. Most of the drop is Ruby-level (fewer
transient Arrays and Hashes in core methods), which the per-line diff attributes across the request path.

**One regression, bisected.** Two call shapes allocate one extra Hash per call on master:

```ruby
class P; def m(k: 1, **) = 1; def n(name, caller_depth: 1, **kw) = 1; end
class C < P
  def m(k: 1, **) = super                                                    # 4.0.7: 2, master: 3
  def e(name, caller_depth: 1, **kw) = n(name, caller_depth: caller_depth + 1, **kw)  # 4.0.7: 2, master: 3
end
```

| Case (objects per call) | 4.0.7 | master `9aa0898240` | ruby/ruby#19670 (`eb01818c3d`) |
| --- | ---: | ---: | ---: |
| `def zk(k: 1, **) = super` | 2 | 3 | **3** |
| `def zk2(k: 1, **kw) = super` | 2 | 3 | **3** |
| `def zkonly(k: 1) = super` | 1 | 2 | 1 |
| `n(name, caller_depth: d + 1, **kw)` | 2 | 3 | 2 |
| `n(name, payload, caller_depth: d + 1, filter: false, **kw)` | 2 | 3 | 2 |

* First bad commit: [`f01bf185f6`](https://github.com/ruby/ruby/commit/f01bf185f6) (ruby/ruby#18344, "Refactor
  core_hash_merge_ptr and core_hash_merge_kw"), by `git bisect` with the micro above.
* Rails sites that hit it in the census: `action_dispatch/routing/url_for.rb:37`,
  `active_support/structured_event_subscriber.rb:86`, `active_record/timestamp.rb:129`,
  `active_record/associations/singular_association.rb:52`, `active_support/message_verifier.rb:337`.
* Our open ruby/ruby#19670 fixes the forwarding and `zkonly` cases. It does **not** fix zsuper with a keyword rest
  (`def m(k: 1, **) = super`), and no open PR covers that. Unowned; see the shortlist.

## RubyGems: `---` YAML loads as nil on master

```sh
ruby -e 'require "rubygems/yaml_serializer"; p Gem::YAMLSerializer.load("---\n")'   # 4.0.x: {}, master: nil
printf -- '---\n' > .bundle/config && bundle _4.0.23_ config                         # master: NoMethodError inject for nil
```

* The change is ruby/rubygems#9379 ([ruby/ruby `f7e6eae3d3`](https://github.com/ruby/ruby/commit/f7e6eae3d3)), intended:
  an empty document is nil, as in Psych. The same PR made Bundler treat nil as `{}` (ruby/rubygems `368fc29ce1`,
  ruby/ruby `5f725bfa01`), but that commit is not on the rubygems `4.0` branch.
* Checked on the released gem: Bundler 4.0.23 `lib/bundler/settings.rb:485` raises `undefined method 'inject' for
  nil` under master's RubyGems 4.1.0.beta3 with a `---` `.bundle/config`.
* Already reported: [ruby/rubygems#10017](https://github.com/ruby/rubygems/issues/10017) (open, 2026-11-03),
  asking for the backport. Nothing more to file.

## CASA: ZJIT segmentation fault (intermittent)

One of two trace passes over CASA crashed (`f1t1`; `f1t2` and the allocation passes passed):
`[BUG] Segmentation fault at 0x0` in `vm_lookup_cc` → `rb_managed_id_table_lookup` (`RTYPEDDATA_GET_DATA`), from the
interpreter's `opt_nil_p` inside the `each_pair` block of `action_view/helpers/tag_helper.rb:1585` (`tag_options`),
rendering `case_contacts/index.html.erb:67` through filterrific's form helpers. Flags: `--zjit --zjit-stats-quiet
--zjit-trace-exits --zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20`, default memory, so the
64 MiB executable region was full by then (CASA's twin run `f1t2` counted 3,514 `compile_error_out_of_memory` per
op). Trimmed report: [data/frontier-census-f1/casa-zjit-segv.log](data/frontier-census-f1/casa-zjit-segv.log).

**What the registers say.** The faulting load reads through `RDI = 0x6361662f63657073`, which is ASCII
(`"spec/fac"` little-endian), not a null pointer. The class pointer of the receiver `opt_nil_p` dispatched on led
into string bytes: the receiver's slot was most likely freed and reused while it was still reachable from the
options Hash or a frame, that is, a missed GC mark or a stale reference after a move. A wrong method-cache lookup
alone would not produce text there. This is an inference from one report; it is not confirmed.

**Reproduction attempts (2026-11-04, about two hours, Ruby `9aa0898240`, Rails `c042aee23a`):** none crashed.

| Attempt | Flags beyond the crash's flags | Result |
| --- | --- | --- |
| CASA, all workloads, 200 warmup + 20 ops | none (same flags) | clean |
| same | `--zjit-exec-mem-size=8` (out of code memory early) | clean |
| same | `--zjit-call-threshold=1` | clean |
| same | full GC every 5 ms from a thread ([gc-pressure.rb](data/frontier-census-f1/gc-pressure.rb)) | clean (25 min timeout) |
| same | full GC every 20 ms | clean (22 min timeout) |
| same | `GC.compact` every 50 ms | clean (25 min timeout) |
| `tag_options` micro ([casa-tag-options-micro.rb](data/frontier-census-f1/casa-tag-options-micro.rb)), threshold 1 | `GC.stress` every 50 iterations | clean |
| micro, 200,000 iterations | full GC every 5 ms; `GC.compact` every 50 ms; 2 MiB code region with GC every 10 ms | clean |

Counted together with the census passes, CASA crashed in 1 of 15 ZJIT processes (9 census passes, 6 attempts). Not reportable without a
reproduction. Next steps if it is picked up again: a debug build of the same SHA (`cppflags=-DRUBY_DEBUG=1`) or
`GC.verify_internal_consistency` around `tag_options`, and repeated CASA runs with the original flags at
default memory, since the one crash had its code region full.

## Overlays after this run

The measurements used the local gem patches in `fixtures/corpus/frontier-master` as written for F1 (cbor TypedData,
lago-expression with the cap lifted, rinku's macro rename, tiktoken_ruby and tokenizers on magnus 0.8.4). Bet E2 has
since replaced those with git sources at the upstream fixes on Lowrail main; a rerun uses E2's overlays.

