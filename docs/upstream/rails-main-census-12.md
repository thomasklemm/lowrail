# Rails-main census 12: main 088fc0cf61 against 8.1.4.1 and census 11's main

**Result (2026-11-27).** These are census 11's 8 apps and 71 workloads with the same method: Ruby 4.0.9, fixed heap, and census 8's patched Valgrind. Rails main [`088fc0cf61`](https://github.com/rails/rails/commit/088fc0cf61e4ba0c7987decafacc69adb3e22eec) runs a median **−8.54%** of interpreted instructions per request against v8.1.4.1. The second main run gives −8.56%, 69 of 71 workloads are faster beyond 1%, and objects are down 614 per request (71 of 71 lower). Against census 11's main [`cf0325a832`](https://github.com/rails/rails/commit/cf0325a832a1594f01d866da1e4ad23d962d886b) it is a median **−1.72%** (−1.65%), with 54 workloads faster and objects down 19. That is 67 first-parent commits, including the 21 of ours merged on 2026-11-26. Under YJIT, counting only JIT-flat windows, it is **−12.62%** against 8.1 (18 workloads flat in all three labels) and −0.95% against census 11 (20).

* **Unreleased slowdowns since 8.1:** one workload, codetriage `perform SendSingleTriageEmailJob`, +3.42% (second run +3.39%, A/A −0.03%). It is the debug-level event reporter that #56213 enables when `log_level` is `:debug`, and codetriage sets that in production. This is deliberate and was already judged so in [main-regressions](main-regressions.md). Under YJIT the same workload is −4.45% against 8.1. The methods that grew against 8.1 are census 10's list (see below); none is new this round.
* **Since census 11:** the one new cost is `cache_quoted_name` (#59955, #59980): +0.054% of all instructions in 7 apps, at most 0.19% of a workload. redprints-cfp's mailer workload is +2.47% in both runs, but its first-parent bisect is not monotonic and the commits it lands on don't run in that workload. I don't attribute it to a Rails change (see [the mailer bisect](#the-mailer-workload-since-census-11)).
* **Hot work that clears the "moves whole requests" bar** ([ranked below](#hot-work-on-main)), by mean share × reach: notifications fan-out (2.07% mean, 70/71 workloads), tag attribute building (2.43%, 41/71, up to 11.4%), query-cache key hashing (1.09%, 67/71, with two key hashes per lookup), `IsolatedExecutionState.[]` (1.01%, 68/71), connection lookup (0.81%, 68/71), InheritableOptions parent reads (0.73%, up to 2.6%), CSRF token masking (0.76%), parameter filtering (0.50%, up to 3.8%) and `build_request`'s `env_config` merge (0.35%, up to 3.0%). inertia_rails' per-call configuration (up to 9.2% in Inertia apps) is gem-side and already fixed in inertia_rails 3.23.

Nothing was built, queued or posted.

## Census (CPU and allocations)

Labels: `c12m`/`c12m2` are main (A/A), `c12s` is v8.1.4.1 (`3f290b759c`), `c12c11` is census 11's main, and `a12*` are the matching allocation labels (interpreter and YJIT; `a12s` has an A/A twin `a12s2`). Each label ran on its own, one after another on this orb. As in census 11 (SC1), codetriage runs every label without `db/schema_cache.yml`.

Interpreter instructions per request ([vs 8.1](data/rails-main-census-12/cpu-s81-main.txt), [vs census 11](data/rails-main-census-12/cpu-c11-main.txt), [A/A](data/rails-main-census-12/cpu-aa-main.txt)):

| App | Workloads | Main vs 8.1.4.1, median (range) | Main vs c11 main, median (range) | A/A median \|Δ\| | Objects vs 8.1 / vs c11 (median) |
| --- | ---: | --- | --- | ---: | ---: |
| blog | 10 | −14.00% (−26.86% … −5.60%) | −2.69% (−6.17% … −1.80%) | 0.03% | −452 / −3.0 |
| casa | 10 | −10.07% (−24.96% … −0.14%) | −2.06% (−4.08% … −0.02%) | 0.03% | −5868 / −128 |
| codetriage | 7 | −4.95% (−13.03% … +3.42%) | −1.41% (−3.43% … −0.45%) | 0.03% | −683 / −22 |
| hackatime | 12 | −6.37% (−19.27% … −1.84%) | −1.01% (−2.50% … +0.94%) | 0.05% | −1221 / −23 |
| pingcrm | 8 | −6.90% (−8.18% … −6.16%) | −1.65% (−8.04% … −0.32%) | 0.27% | −439 / −11 |
| react-starter-kit | 8 | −9.67% (−11.74% … −6.65%) | −2.59% (−3.82% … −1.54%) | 0.21% | −386 / −9 |
| redprints-cfp | 8 | −8.80% (−10.43% … −3.75%) | −1.18% (−2.67% … +2.47%) | 0.10% | −378 / −12 |
| writebook | 8 | −7.85% (−10.98% … −4.53%) | −1.95% (−3.17% … +0.30%) | 0.07% | −1186 / −55 |
| **All** | **71** | **−8.54%**; 69 faster, 1 slower beyond 1% | **−1.72%**; 54 faster, 1 slower | — | **−614 / −19** |

* **CPU A/A** (`c12m2` vs `c12m`): median −0.02%; 70 of 71 workloads are within ±0.7%. The exception is hackatime `GET dashboard stats (deferred)` at −1.58%, whose comparisons against both bases I don't count for that reason.
* **Allocations** ([vs 8.1](data/rails-main-census-12/alloc-s81-main.md), [vs c11](data/rails-main-census-12/alloc-c11-main.md), [A/A](data/rails-main-census-12/alloc-aa-main.md)): against 8.1 the medians are −614.3 interpreter and −609.9 YJIT (second run −611.4 / −609.8), with 71/71 lower in both modes. The 8.1 A/A median is +0.0. Against c11 the medians are −19.3 / −18.1, with 64 / 65 workloads lower. Three are higher:
  * casa `GET volunteers` is +61 / +99 objects with one SQL query fewer (29 → 28, the only SQL change in either mode), while its instructions fall 1.14%. This is not bisected.
  * blog's `ActionBroadcastJob` is +25.8 under the interpreter but −8.1 under YJIT (second run +20.9 / −8.0), so it is not a consistent growth.

### YJIT instructions (JIT-flat windows only)

cpu-census's YJIT mode warms each workload until three windows in a row compile nothing, then checks that the measured window itself compiled nothing. Every measured window and its four counters are listed in [`jit-gate.tsv`](data/rails-main-census-12/jit-gate.tsv). Rejected windows: **c12m 33/71, c12m2 37/71, c12s 33/71, c12c11 37/70**. They are recorded and were not rerun. A comparison counts a workload only when it is flat in every label compared.

* **Main vs 8.1.4.1** ([output](data/rails-main-census-12/cpu-yjit-s81-main.txt)): 18 workloads are flat in c12s, c12m and c12m2. The median is **−12.62%** (blog −20.44%, pingcrm −11.56%, react-starter-kit −12.50%, redprints-cfp −14.48%, codetriage's job −4.45%), with all 18 faster beyond 1% and an A/A median of 0.01–0.21% per app. casa, hackatime and writebook have no workload that is flat in all three labels. With only the 8.1 base and one main run, `cpu-census compare` gives −12.74% over 25 workloads.
* **YJIT A/A** ([output](data/rails-main-census-12/cpu-yjit-aa-main.txt)): 24 workloads are flat in both main runs, with a median −0.00% and none beyond 1%.
* **Main vs census 11's main** ([output](data/rails-main-census-12/cpu-yjit-c11-main.txt)): 20 flat workloads, median −0.95%, 8 faster and 0 slower beyond 1% ([below](#yjit-against-census-11)).

## Unreleased slowdowns since 8.1

**Workloads.** Only codetriage `perform SendSingleTriageEmailJob` is slower beyond 1% in both main runs: +3.42% / +3.39% (11,204,443 → 11,587,888 Ir/op), with 155 fewer objects. Census 11 measured +4.91% for it; I did not attribute the smaller step since then. The method net for this workload attributes it:

* the debug-mode event reporter's paths account for about +350k of the +383k: `EventReporter#notify` +104k, `ActiveRecord::StructuredEventSubscriber#sql` +92k, `EventReporter#debug` +56k, `emit_debug_event` +52k and `LogSubscriber.subscription_filter` +44k;
* `PG::Connection#get_result` +351k is offset by `perform_query` −329k, which is work that moved between the two methods (census 10 found the same).

The source is [#56213](https://github.com/rails/rails/pull/56213), "Respect config.log_level to emit debug events" by claudiob, merged by gmcgibbon on 2025-12-05. It changed `Rails.event.debug_mode` from `Rails.env.development?` to `log_level == "debug"` ([bootstrap.rb:84](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/railties/lib/rails/application/bootstrap.rb#L84)). This is the deliberate behaviour that [main-regressions](main-regressions.md) already recorded.

**Bisect attempt, rejected:** measuring the merge `38a74b851c` against its first parent would need codetriage to boot on a December 2025 tree with today's lock. On `cb0fd2254a` slim-rails 4.0.0 calls `Rails::CodeStatistics.register_extension`, which doesn't exist there ([log excerpt](data/rails-main-census-12/bisect/codetriage-56213-boot-failure.txt)). The attribution therefore rests on the method net and on #56213's diff, not on a measured step.

**Ownership:** I searched rails/rails issues and PRs for `debug_mode log_level` and for production debug events and found nothing open on this cost. #56213 has no timeline cross-references. Our queue has no item. No one owns it, and nothing needs owning because the behaviour is intended.

**Methods that grew against 8.1** (net self Ir as % of all 8.1 instructions over the 71 workloads; the method A/A is at most ±0.013% in every row; [full list](data/rails-main-census-12/cpu-s81-main.txt)). These are census 10's and 11's rows at nearly the same sizes, all already attributed in those rounds:

| Method | Net vs 8.1 | Apps | Known cause (earlier census) |
| --- | ---: | ---: | --- |
| `PG::Connection#get_result` | +0.646% | 4 | moved out of `perform_query` (shrank in the same apps) |
| `TagBuilder#append_tag_option` | +0.627% | 8 | tag-option split; `tag_option` −0.686% offsets it |
| `RowLayout#initialize`, `LazyIndexedAttributeSet#*`, `IndexedRow.key_at?` | +0.296%, +0.10% to +0.27% each | 8 | #59141's attribute set; `LazyAttributeSet#fetch_value` −0.779% offsets it |
| `OptimizedUrlHelper#call`, `Journey::Format#add_to` | +0.256%, +0.175% | 8 | routing (census 9–11) |
| `AssociationReflection#association_route`, `current_default_association_route?` | +0.198%, +0.146% | 8 | association routes (census 9–11) |
| `csrf_token_hmac` | +0.152% | 8 | #59430, a security fix |
| `start_intent_log`, `QueryIntent#initialize` | +0.125%, +0.096% | 8 | QueryIntent architecture |
| `WeakKeyMap#fetch_or_store`, `LeaseRegistry#lease` | +0.106%, +0.100% | 8 | connection lease registry; LR1 (#59983) removed the mutex share since census 11 |
| `WhereClause#empty?`, `WhereClause#-` | +0.085% each | 8 | lead A1 (census 10) |

No method row is new against census 11's list. I did not bisect method rows this round: census 9–11 attributed them, and none moved by more than about 0.02 points.

## Since census 11's main

**Workloads.** Only redprints-cfp `deliver ProposalMailer#proposal_submitted` is slower beyond 1% in both runs: +2.47% / +2.44% (5,616,786 → 5,755,654 Ir/op), objects −8, A/A −0.04%. hackatime `GET dashboard stats (deferred)` shows +0.94% in one run and −0.66% in the other, inside its own 1.58% A/A.

### The mailer workload since census 11

[`bisect.rb`](../../bench/upstream/census12/bisect.rb) bisects the 67 first parents. A first pass measured the workload alone (`--only`) and found +0.35% (5,999,874 → 6,020,742), which does not reproduce the census step. In this app a workload's cost depends on the workloads run before it, so that pass was stopped after one step ([raw](data/rails-main-census-12/bisect/redprints-cfp-only.tsv)). The bisect was then rerun with the full workload list per step, as the census measures ([raw](data/rails-main-census-12/bisect/redprints-cfp.tsv)):

| First parent | Ir/op | Objects |
| --- | ---: | ---: |
| `cf0325a832` (c11 main) | 5,610,523 | 2093.6 |
| `59388990b1` (#59965) | 5,615,349 | 2101.6 |
| `1b1a809125` (#59956) | 5,741,441 | 2101.3 |
| `5f98db3562` (#59906) | 5,740,068 | 2093.5 |
| `b5a1d7f4af` (#59960) | 5,618,902 | 2101.5 |
| `f785381cca` (#59982) | 5,676,732 | 2102.4 |
| `2a0b79554a` (#59915) | 5,742,254 | — |
| `088fc0cf61` (main) | 5,742,259 | 2093.3 |

The bisect named #59956 (eager-load outer join aliases). That PR changes only `QueryMethods`, which this mailer doesn't run. The series is also not monotonic: `b5a1d7f4af` comes after `5f98db3562` on main's first-parent line, yet it measured the low value. The step is entirely inside unchanged code: `OutputBuffer#safe_concat` (+79k, which is `String#<<` on the raw buffer) and Mail gem header and encoding methods (+21k to +26k each), with objects unchanged. My hypothesis is a memory-layout effect, for example string capacity and reallocation in the mail body build depending on the heap state the earlier workloads leave behind, rather than a Rails code change. It is not verified: I made no layout control. No owner is recorded because there is no attributable commit.

**Methods since census 11** ([full list](data/rails-main-census-12/cpu-c11-main.txt); per-process template and anonymous-class names were normalised):

| Change | Net vs c11 | Apps | Commit | Ownership |
| --- | ---: | ---: | --- | --- |
| `Quoting::ClassMethods#cache_quoted_name` (new helper) | +0.054% (+1.18 M Ir summed; adapter `quote_*` −0.30 M) | 7 | [#59955](https://github.com/rails/rails/pull/59955) (bruno-costanzo, merged by rafaelfranca 2026-11-25) and [#59980](https://github.com/rails/rails/pull/59980) (imattas, 2026-11-26) | Bounding the caches is the purpose. #59955's review was about its test, not cost, and #59980 had no review. Neither has cross-references. No open PR touches `cache_quoted_name`; the 8 open PRs on the quoting files change other methods; no queue item. Max 0.194% of a workload (hackatime `POST heartbeat`), so it doesn't reach the bar. |
| `ActiveSupport::TimeFormats.lookup` | +0.013% | 5 | [#59992](https://github.com/rails/rails/pull/59992) (adityawrk, built-in format overrides) | No reviews or cross-references; no open PR on the format files. Small. |
| `Merger#merge` | −0.216% | 8 | #59810 (ours, merge blank relation) | — |
| `WeakKeyMap#fetch_or_store`, `Mutex#synchronize`; `LeaseRegistry#lease` | −0.150%, −0.109%; +0.016% | 8 | #59983 (LR1, ours) | net −0.24% |
| `WhereClause#merge`, `AliasTracker.create`, `LazyIndexedAttributeSet#keys` | −0.055%, −0.023%, −0.046% | 8 | #59810, #59569, #59800 (ours) | — |

### YJIT against census 11

[Output](data/rails-main-census-12/cpu-yjit-c11-main.txt). 20 workloads are flat in c12c11, c12m and c12m2; 37 of c12c11's 70 YJIT windows were rejected. hackatime's `perform DashboardRollupRefreshJob` recorded no measurement in c12c11 under YJIT, the same gap census 10 saw for that workload. The median is **−0.92% to −0.95%**: 8 workloads are faster beyond 1% in both runs and none is slower. The A/A median is 0.01–0.21% per app.

The redprints-cfp mailer is **−0.01% / +0.15%** under YJIT against census 11 (A/A +0.16%). The interpreter's +2.47% does not appear with the JIT, which fits the layout hypothesis above rather than added work. The only YJIT method that grew is `LeaseRegistry#lease`, +0.071% in 7 apps (A/A −0.019%). That is LR1's lock-free hit taking self cost that moved out of `fetch_or_store` and `Mutex#synchronize`.

## Hot work on main

Self instructions on main (`c12m`) as a share of each whole workload, averaged over all 71 workloads. Reach counts workloads where the work costs at least 0.1%. A cluster groups the methods that do one piece of work ([`clusters.rb`](../../bench/upstream/census12/clusters.rb)). I find callers from one sampled-stack window per peak workload ([`stacks.sh`](../../bench/upstream/census12/stacks.sh), [callers](data/rails-main-census-12/callers/)). Per method and line: [hot methods](data/rails-main-census-12/hot-method-interpreter.txt), [hot lines](data/rails-main-census-12/hot-line-interpreter.txt), [cpu-census rank](data/rails-main-census-12/rank-c12m-interpreter-method.txt) and [open PRs on its lines](data/rails-main-census-12/open-prs-on-hot-lines.txt). The YJIT columns use the 38 JIT-flat workloads of c12m ([clusters](data/rails-main-census-12/clusters-yjit.txt)).

Ranked by score = mean share × reach / 71:

| # | Work | Interp mean / reach / ≥1% | Max (workload) | YJIT mean / reach | What is avoidable | Owner |
| ---: | --- | --- | --- | --- | --- | --- |
| 1 | **Notifications fan-out** (`Fanout#groups_for`, `#build_handle`, `FanoutIteration#iterate_guarding_exceptions`, `Handle`) | 2.07% / 70 / 56 | 6.8% (codetriage `GET home`); per-app medians 1.0% to 5.0% | 1.08% / 37 | `groups_for` recomputes the silenced filter on every event, and `build_handle` allocates group instances even when every silenceable subscriber is silenced. The avoidable part is not yet priced. | Open [#58957](https://github.com/rails/rails/pull/58957) (linyiru, skip handlers nobody consumes; updated 2026-11-25), #58366 (lock order). No queue item. |
| 2 | **Tag attribute building** (`TagBuilder#tag_options`, `append_tag_option`, `ERB::Util.xml_name_escape`, `html_escape`) | 2.43% / 41 / 36 | 11.4% (blog `GET article`); `String#blank?` from tag_helper.rb:1548/1551 and `xml_name_escape` is 76% of that page's `blank?` | 1.74% / 20 | The per-option `blank?` and key escaping of literal keys | Open [#57999](https://github.com/rails/rails/pull/57999) (ikraamg, on those lines since 2026-07). Ours: TO1 held, XNE1 superseded. |
| 3 | **Query-cache key hashing** (`QueryCache::Store#compute_if_absent`, `QueryAttribute#hash`, `Attribute#hash`, `Type::Value#hash`) | 1.09% / 67 / 36 | 2.6% (casa `GET dashboard`) | 1.43% / 34 (26 ≥1%) | [query_cache.rb:90 and :98](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/abstract/query_cache.rb#L85-L99) delete and reinsert the `[sql, binds]` key, so each lookup hashes the key and every bind twice. Those two lines carry 92% of the bind hashing on casa `GET casa case edit`. | Open [#59518](https://github.com/rails/rails/pull/59518) (sampokuokkanen, memoize `QueryAttribute#hash`; covers the bind part). No PR on the double hash; no queue item. |
| 4 | **`IsolatedExecutionState.[]`** | 1.01% / 68 / 39 | 2.1% (blog `PATCH article.json`) | 0.73% / 35 | Per call it does `@scope.current.active_support_execution_state` plus a hash lookup, from about 45 call sites. The top callers are `Base.connected_to_stack` (read again for `current_role`, `current_shard` and `preventing_writes?`; 21% of blog `PATCH article.json`), `Notifications.registry`, `used_pools` and the logger's `local_level`. | No open PR on the file; no queue item. |
| 5 | **Connection lookup** (`ConnectionHandling#connection_specification_name` / `connection_pool`, `connected_to_stack`, `current_role`/`current_shard`, `LeaseRegistry#lease`) | 0.81% / 68 / 23 | 1.9% (writebook `PATCH page`) | 0.47% / 33 | Repeated per query: [connection_handling.rb:397](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_handling.rb#L397) resolves name, role and shard each time | 7 open PRs touch the file (#56850 role pinning, #58731, #59029, #59135 and others); none targets this lookup's cost. Overlaps #4. |
| 6 | **InheritableOptions parent reads** (`InheritableOptions#initialize`'s default proc, `OrderedOptions#[]`/`method_missing`) | 0.73% / 62 / 19 | 2.6% (writebook `GET books`: 80% from `asset_path`'s `config.relative_url_root` and `compute_asset_host`'s `config.asset_host`) | 0.85% / 33 | Asset helpers read missing keys through the controller config chain on every asset; CSRF config readers read through it on every request | Ours: **OO1** (held, below the bar on railsbench). No open PR on `ordered_options.rb`. |
| 7 | **CSRF token masking** (`mask_token`, `per_form_csrf_token`, `csrf_token_hmac`, `xor_byte_strings`) | 0.76% / 52 / 25 | 3.3% (blog `GET article`; `mask_token` 61%) | 0.82% / 27 | Each form masks a fresh token, which is part of the design; the HMAC key dup comes from #59430 (security fix, intended) | 8 open PRs touch the file, none on masking cost; no queue item. |
| 8 | **Parameter filtering** (`ParameterFilter#call`/`value_for_key`) | 0.50% / 58 / 10 | 3.8% (hackatime `PATCH display name`: 62% sentry-rails' log subscriber filtering again, 38% `_perform_parameter_wrapping`'s `filtered_parameters`) | 0.82% / 34 (6.3% max) | Params are filtered once per request in Rails. sentry-rails filters them again (gem-side), and the params wrapper reads `filtered_parameters` before Instrumentation does. | Open [#58958](https://github.com/rails/rails/pull/58958) (rwalters44, on line 198), #55939 (gmcgibbon). sentry-rails is outside Rails. |
| 9 | **inertia_rails configuration per call** (`Hash#extract!` in `Configuration#initialize` from `bind_controller`) | 0.99% / 32 (5 apps) / 21 | 9.2% (react-starter-kit `GET dashboard (Inertia JSON)`) | 1.24% / 18 | `inertia_configuration` rebuilds a Configuration on every read, 4+ times per request (middleware `server_version`, XSRF policy, flash) | **Gem-side and fixed:** inertia_rails 3.23.0+ (our inertiajs/inertia-rails#437) `dup`s instead; the census pins 3.22.0. Nothing to do in Rails. |
| 10 | **`Engine#build_request`'s `env.merge!(env_config)`** | 0.35% / 48 / 4 | 3.0% (blog `GET article.json`) | 0.29% / 28 | Merges the whole `env_config` hash into every request env ([engine.rb:851](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/railties/lib/rails/engine.rb#L851)) | 7 open PRs touch `engine.rb`, none this line; no queue item. |

Single hot methods outside these clusters: `String#blank?` (0.65% mean, 56/71; mostly the tag path of row 2, plus validations), `PostgreSQL::DatabaseStatements#cast_result` (0.87% mean in the 4 PostgreSQL apps, up to 6.3% on pingcrm `GET contact edit`), `Time#change` (0.40%, up to 7.0% on hackatime's rollup job, app-driven), and `Hash#symbolize_keys!` (0.32%, 56/71, from cookie-jar `[]=` on every session write). The ranked lists hold the rest.

Rows 1–8 and 10 have no measured avoidable price yet. A candidate's own claim needs its per-call micro and A/A. The shares here are the ceiling, not the saving.

## Method and pins

* Rails main `088fc0cf61` (2026-11-27), v8.1.4.1 `3f290b759c`, census 11 main `cf0325a832`; 67 first-parent commits since census 11. Ruby 4.0.9 (`3e93b23afc`). Fixed heap `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000` ([`heap.sh`](../../bench/upstream/census12/heap.sh)); census 8's patched Valgrind 3.19.0 built with `script/cpu-census build` (patch sha256 in each label's meta).
* Corpus set up fresh on main with [`setup.sh`](../../bench/upstream/census12/setup.sh). Codetriage needed loopback trust on the disposable PostgreSQL server for its TCP `localhost` connection; its first setup attempt failed on `fe_sendauth` and was redone from scratch.
* Runs: [`run_census.sh`](../../bench/upstream/census12/run_census.sh) (CPU interpreter `c12m --aa`, `c12s`, `c12c11`; allocations `a12m --aa`, `a12s --aa`, `a12c11`; CPU YJIT `c12m --aa`, `c12s`), then [`run_after.sh`](../../bench/upstream/census12/run_after.sh) (bisects, stacks, CPU YJIT `c12c11`), one label at a time, `--jobs 4` across apps.
* Reports: [`net.rb`](../../bench/upstream/census12/net.rb) (per workload and per method net with A/A), [`hot.rb`](../../bench/upstream/census12/hot.rb), [`clusters.rb`](../../bench/upstream/census12/clusters.rb), [`callers.rb`](../../bench/upstream/census12/callers.rb), [`jit_gate.rb`](../../bench/upstream/census12/jit_gate.rb). Compact label copies (Ir/op, objects, JIT counters, methods ≥ 5,000 Ir/op, lines ≥ 20,000) are in [`labels/`](data/rails-main-census-12/labels/) for c12m (both modes), c12m2, c12s and c12c11, so later passes can recompute these tables. Census 11 lacked this for its final labels.
* Ownership: rails/rails PRs and issues by keyword; the introducing PRs' bodies, reviews and timeline cross-references (#59955, #59980, #59992, #56213); all 1,289 open rails/rails PRs by file and changed-line hunk (`cpu-census prs --refresh`); our 148 queue items by method name.
