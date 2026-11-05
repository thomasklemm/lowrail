# What Rails main gains over 8.1, and our share of it (2026-11-05)

Follow-up to [merged-sum](merged-sum.md). Three trees, each run as an A/A pair: 8-1-stable, current main, and
current main with our merged performance PRs reverted ("minus-ours"). The merge base of 8-1-stable and main is
a fourth, reference row. Nothing here is posted upstream.

**Result.** In the interpreter, main runs ruby-bench with **29.3% fewer instructions than 8-1-stable on
railsbench, 11.5% fewer on erubi-rails, 3.9% on lobsters and 2.7% on shipit**. It allocates **18–46% fewer
objects per iteration** on all four. Our PRs account for −3.0% (railsbench), −2.8% (erubi-rails) and −6.5%
(shipit) of instructions; on lobsters ours doesn't pass A/A. The residual, which is mostly everyone else, is
−27.1%, −8.9% and −3.6%, and **+4.1% on shipit**. App GET pages: Writebook −9.1% in total, of which ours is −5.3%.
Blog's total is flat: ours −1.9% and the residual +2.1% cancel. Census allocations (blog and Writebook, the only
two apps that run on 8.1): −22.8% and −18.9% in total, of which ours is −2.7% and −4.4%. YJIT rows are all
rejected by the JIT-flat check. These are instruction and allocation counts, not timings.

**How to read the split.** Total = main − 8.1 (pair means). Ours = main − minus-ours. Residual = minus-ours − 8.1
= total − ours. The residual is not "everyone else" alone. It also contains interactions between our PRs and
theirs; the five PRs of ours whose reverts conflict and were dropped (they stay in minus-ours); our non-perf PRs
such as #59555; the 8-1-stable backports, since 8-1-stable is not an ancestor of main; and, for ruby-bench (whose
apps call `load_defaults` with the running version), the new 8.2 defaults. Ours + residual is therefore not a
clean split between two authors. Percentages are relative to each comparison's old tree, so they don't add exactly.

## Trees and pins

* **main:** rails/rails [`7a78da5a55`](https://github.com/rails/rails/commit/7a78da5a5576d7ab7549b10fb13156788478ba35)
  (2026-11-05). This one SHA is the base of both "main" and "minus-ours".
* **minus-ours:** `7a78da5a55` with 44 merges reverted (`git revert -m 1`, newest first in first-parent order). The
  local commit is `c8d917b867`, reproducible from [`reverted.tsv`](../../bench/upstream/rails_82_impact/reverted.tsv).
  Of our 55 merged PRs, 49 are performance work. #7260, #59555, #59606, #59624, #59625 and #59626 are docs, tests
  or bug fixes and stay in both trees.
* **Dropped because the revert conflicts** (not resolved by hand): #59556, #59551, #59554 and #59543 conflict with
  kamipo's later relation-merging commits 873d897d42, 8f71c51c51, bb359be47a and 401f146f41; #59236 conflicts with
  84048ad477 ("Don't store a sentinel in `CurrentAttributes.defaults`"). Their savings sit in the residual.
* **8-1-stable:** [`6e09124217`](https://github.com/rails/rails/commit/6e091242176c322edc5a8907583c01b08b8a60bc)
  (8.1.4.1).
* **Merge base** `git merge-base 8-1-stable main`:
  [`8ae3d84277`](https://github.com/rails/rails/commit/8ae3d84277889ec1c718844550e3aa09ce42a58c) (8.1.0.beta1).
  This is the reference row for the backports.
* **A/A pairs:** two worktrees per tree for ruby-bench (`sum-main`/`sum-main2`, `sum-rev`/`sum-rev2`,
  `imp-81`/`imp-81b`, `mb-a`/`mb-b`). The census and app pages use two runs of the same SHA.
* **Ruby 4.0.9**, production, fixed heap from [bench.md](../bench.md) (`RUBY_GC_HEAP_0..4_INIT_SLOTS` 1,000,000 /
  250,000 / 100,000 / 20,000 / 10,000) for every instruction and allocation run. App YJIT was skipped (it failed
  A/A in merged-sum). The PG apps aren't set up on this orb, so they were skipped.
* **Claim rule:** a row is claimed only when |Δ| exceeds 2 × the larger A/A of its two pairs. Under YJIT, all four
  runs must also be JIT-flat. Rejected rows stay in the tables.

### What could not run, and the lock fix

* **8.1 in the census:** Campfire calls `load_defaults "8.2"`. Fizzy subscribes a Hash listener that 8.1's
  `Notifications::Fanout` can't take. Lobsters returns 500 because a query comes out with an empty table name
  (`FROM ""`). Only blog and Writebook compare against 8.1.
* **The merge base (8.1.0.beta1):** no census app runs. Fizzy's `rails-active_search` needs rails ≥ 8.1, blog's
  `PATCH /articles/1` returns 500, and Writebook fails on connection_pool 3.0's constructor. On ruby-bench, shipit
  doesn't bundle (shipit-engine needs rails ≥ 8.1.1) and lobsters' login returns 500 (an `ArgumentError` in
  `Messages::Rotator`). The merge-base row covers railsbench and erubi-rails only.
* **ruby-bench under YJIT, lobsters and shipit:** the run aborted on `sum-rev2` lobsters with an `ENOENT` from a
  shared `tmp/cache` (parallel workers race on one cache directory). These rows would fail the flat check anyway:
  main's lobsters window compiled about 3,400 new blocks and 200 ISeqs. They were not rerun.
* **Lock fix:** at first, the lobsters and shipit `Gemfile.sum-rev2.lock` came from ruby-bench's generic lock,
  not from `sum-rev`'s (396 and 286 lines of different gem pins), so that pair wasn't an A/A. Both were rebuilt
  from `sum-rev`'s lock (the diff is 0 lines apart from the path). The four allocation results made with the old
  lock are kept in `rejected-lock/` and were rerun. The instruction runs had not reached lobsters or shipit yet.
  Railsbench's pair differs only in `jar-dependencies` (Java-only, never loaded), so it stays.
* **Herb control:** main's 8.2 defaults switch ERB to Herb on railsbench and erubi-rails. A third pair on main
  with `erb_implementation = :erubi` (`erb-a`/`erb-b`) changes instructions by +0.06% and +0.10%, inside A/A. Herb
  is not a driver here.

### JIT-flat check

[`jit_counts.rb`](../../bench/upstream/actionview_cpu/jit_counts.rb) is preloaded under YJIT. It snapshots
`compiled_iseq_count`, `compiled_block_count` and `invalidation_count` in the long run's process, before the
iterations the difference measures and after its last iteration. Flat means equal snapshots. 22 of 24 runs
compiled new blocks inside the window: railsbench gained 183–338 blocks, erubi-rails 4–45, lobsters about 3,400
blocks and about 200 ISeqs. Only erubi-rails `sum-main` and `sum-rev` were flat, and their A/A partners were not.
Every YJIT row is rejected.

## ruby-bench instructions per iteration

[`ir_table.rb`](../../bench/upstream/rails_82_impact/ir_table.rb) over
[`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb) results: cachegrind, the long run
minus the short run. The long runs are 10 iterations for erubi-rails and 4 for the others, after 2 warmup
iterations.

| Benchmark | Mode | Comparison | Ir/iteration old → new | Δ | A/A new, old | Verdict |
| --- | --- | --- | ---: | ---: | ---: | --- |
| erubi-rails | interpreter | total: main vs 8-1-stable | 8.063e+09 → 7.139e+09 | -11.46% | +0.14%, -0.04% | claimed |
| erubi-rails | interpreter | ours: main vs minus-ours | 7.347e+09 → 7.139e+09 | -2.84% | +0.14%, +0.05% | claimed |
| erubi-rails | interpreter | residual (others): minus-ours vs 8-1-stable | 8.063e+09 → 7.347e+09 | -8.88% | +0.05%, -0.04% | claimed |
| erubi-rails | interpreter | 8-1 backports: 8-1-stable vs merge-base | 8.061e+09 → 8.063e+09 | +0.02% | -0.04%, -0.09% | rejected (A/A) |
| erubi-rails | interpreter | Herb control: main+Erubi vs main | 7.139e+09 → 7.143e+09 | +0.06% | +0.01%, +0.14% | rejected (A/A) |
| erubi-rails | yjit | total: main vs 8-1-stable | 4.909e+09 → 4.084e+09 | -16.81% | -0.03%, -0.02% | rejected (not JIT-flat) |
| erubi-rails | yjit | ours: main vs minus-ours | 4.292e+09 → 4.084e+09 | -4.84% | -0.03%, -0.15% | rejected (not JIT-flat) |
| erubi-rails | yjit | residual (others): minus-ours vs 8-1-stable | 4.909e+09 → 4.292e+09 | -12.58% | -0.15%, -0.02% | rejected (not JIT-flat) |
| erubi-rails | yjit | 8-1 backports: 8-1-stable vs merge-base | 4.91e+09 → 4.909e+09 | -0.01% | -0.02%, -0.15% | rejected (not JIT-flat) |
| lobsters | interpreter | total: main vs 8-1-stable | 4.453e+09 → 4.279e+09 | -3.91% | +0.00%, -0.02% | claimed |
| lobsters | interpreter | ours: main vs minus-ours | 4.293e+09 → 4.279e+09 | -0.32% | +0.00%, +0.20% | rejected (A/A) |
| lobsters | interpreter | residual (others): minus-ours vs 8-1-stable | 4.453e+09 → 4.293e+09 | -3.61% | +0.20%, -0.02% | claimed |
| railsbench | interpreter | total: main vs 8-1-stable | 7.414e+09 → 5.242e+09 | -29.29% | -0.13%, +0.07% | claimed |
| railsbench | interpreter | ours: main vs minus-ours | 5.403e+09 → 5.242e+09 | -2.97% | -0.13%, +0.02% | claimed |
| railsbench | interpreter | residual (others): minus-ours vs 8-1-stable | 7.414e+09 → 5.403e+09 | -27.13% | +0.02%, +0.07% | claimed |
| railsbench | interpreter | 8-1 backports: 8-1-stable vs merge-base | 7.352e+09 → 7.414e+09 | +0.85% | +0.07%, +0.09% | claimed |
| railsbench | interpreter | Herb control: main+Erubi vs main | 5.242e+09 → 5.247e+09 | +0.10% | -0.04%, -0.13% | rejected (A/A) |
| railsbench | yjit | total: main vs 8-1-stable | 4.796e+09 → 2.956e+09 | -38.36% | +0.09%, +0.06% | rejected (not JIT-flat) |
| railsbench | yjit | ours: main vs minus-ours | 3.048e+09 → 2.956e+09 | -3.01% | +0.09%, +0.29% | rejected (not JIT-flat) |
| railsbench | yjit | residual (others): minus-ours vs 8-1-stable | 4.796e+09 → 3.048e+09 | -36.44% | +0.29%, +0.06% | rejected (not JIT-flat) |
| railsbench | yjit | 8-1 backports: 8-1-stable vs merge-base | 4.755e+09 → 4.796e+09 | +0.87% | +0.06%, -0.25% | rejected (not JIT-flat) |
| shipit | interpreter | total: main vs 8-1-stable | 6.082e+09 → 5.921e+09 | -2.65% | -0.02%, -0.02% | claimed |
| shipit | interpreter | ours: main vs minus-ours | 6.332e+09 → 5.921e+09 | -6.49% | -0.02%, +0.08% | claimed |
| shipit | interpreter | residual (others): minus-ours vs 8-1-stable | 6.082e+09 → 6.332e+09 | +4.11% | +0.08%, -0.02% | claimed |

**8-1 backports:** on railsbench, 8-1-stable runs +0.85% more instructions than the merge base (A/A ≤ 0.09%),
and part of that sits in the residual. Erubi-rails doesn't move. The cause isn't attributed; 8.1.0.beta1 → 8.1.4.1
includes security and bug-fix backports.

## ruby-bench objects per iteration

From ruby-bench's `harness/sumalloc.rb`: 5 warmup iterations, then the mean of 10 iterations per process, averaged
over each pair (A/A ≤ 0.01% everywhere).

| Benchmark | Mode | 8.1 → minus-ours → main | Total | Ours | Residual | GC/iter 8.1 → main |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 1,790,641 → 1,026,637 → 965,150 | −46.1% | −6.0% | −42.7% | 2.90 → 1.40 |
| railsbench | YJIT | 1,798,026 → 1,031,975 → 970,488 | −46.0% | −6.0% | −42.6% | 3.00 → 1.40 |
| erubi-rails | interpreter | 2,030,001 → 1,650,001 → 1,620,001 | −20.2% | −1.8% | −18.7% | 4.20 → 3.50 |
| erubi-rails | YJIT | 2,060,001 → 1,670,001 → 1,640,001 | −20.4% | −1.8% | −18.9% | 4.20 → 3.50 |
| lobsters | interpreter | 653,056 → 558,932 → 537,578 | −17.7% | −3.8% | −14.4% | 0.60 → 0.50 |
| lobsters | YJIT | 657,563 → 562,435 → 541,058 | −17.7% | −3.8% | −14.5% | 0.60 → 0.40 |
| shipit | interpreter | 1,157,590 → 988,679 → 889,529 | −23.2% | −10.0% | −14.6% | 1.95 → 1.60 |
| shipit | YJIT | 1,173,702 → 1,001,864 → 902,722 | −23.1% | −9.9% | −14.6% | 1.95 → 1.60 |

8-1-stable vs the merge base: railsbench −0.16% and erubi-rails 0.00% objects.

## App GET pages, instructions per round (interpreter)

`census_ir_run.rb`: cachegrind, the 32-round run minus the 2-round run. Only blog and Writebook run on 8.1.

| App | Mode | Comparison | Ir/round old → new | Δ | A/A new, old | Verdict |
| --- | --- | --- | ---: | ---: | ---: | --- |
| blog | interpreter | total: main vs 8-1-stable | 3.04e+07 → 3.047e+07 | +0.23% | +0.16%, +0.44% | rejected (A/A) |
| blog | interpreter | ours: main vs minus-ours | 3.105e+07 → 3.047e+07 | -1.86% | +0.16%, +0.69% | claimed |
| blog | interpreter | residual (others): minus-ours vs 8-1-stable | 3.04e+07 → 3.105e+07 | +2.13% | +0.69%, +0.44% | claimed |
| campfire | interpreter | ours: main vs minus-ours | 5.338e+07 → 5.334e+07 | -0.07% | -0.27%, -0.23% | rejected (A/A) |
| fizzy | interpreter | ours: main vs minus-ours | 3.748e+08 → 3.637e+08 | -2.98% | +0.18%, +0.01% | claimed |
| lobsters | interpreter | ours: main vs minus-ours | 4.737e+08 → 4.563e+08 | -3.67% | -0.06%, -0.12% | claimed |
| writebook | interpreter | total: main vs 8-1-stable | 1.219e+08 → 1.109e+08 | -9.08% | +0.06%, +0.11% | claimed |
| writebook | interpreter | ours: main vs minus-ours | 1.171e+08 → 1.109e+08 | -5.34% | +0.06%, +0.08% | claimed |
| writebook | interpreter | residual (others): minus-ours vs 8-1-stable | 1.219e+08 → 1.171e+08 | -3.95% | +0.08%, +0.11% | claimed |

## Census allocations (interpreter)

[`census_table.rb`](../../bench/upstream/rails_82_impact/census_table.rb): objects per workload, the mean over
workloads of the median GC-enabled objects per operation, averaged over each pair. ABBA order: `imp-81`,
`imp-main`, `imp-rev`, `imp-rev2`, `imp-main2`, `imp-812`.

| App | Workloads | Objects/workload old → new | Δ | Δ % | A/A new, old | Workloads ≤ −1 / ≥ +1 | Verdict |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| **Total: main vs 8-1-stable** | | | | | | | |
| blog | 10 | 2214.0 → 1710.4 | -503.6 | -22.75% | -10.52, -2.32 | 10 / 0 | claimed |
| writebook | 8 | 6524.1 → 5288.6 | -1235.5 | -18.94% | -0.40, -2.29 | 8 / 0 | claimed |
| **Ours: main vs minus-ours** | | | | | | | |
| blog | 10 | 1757.7 → 1710.4 | -47.3 | -2.69% | -10.52, +3.31 | 9 / 1 | claimed |
| campfire | 9 | 6377.4 → 6243.5 | -134.0 | -2.10% | -0.02, +0.31 | 9 / 0 | claimed |
| fizzy | 14 | 10465.3 → 9894.8 | -570.5 | -5.45% | -11.54, +6.19 | 14 / 0 | claimed |
| lobsters | 11 | 11895.2 → 11456.4 | -438.7 | -3.69% | +0.53, -0.64 | 11 / 0 | claimed |
| writebook | 8 | 5533.0 → 5288.6 | -244.5 | -4.42% | -0.40, -0.21 | 8 / 0 | claimed |
| **Residual: minus-ours vs 8-1-stable** | | | | | | | |
| blog | 10 | 2214.0 → 1757.7 | -456.3 | -20.61% | +3.31, -2.32 | 10 / 0 | claimed |
| writebook | 8 | 6524.1 → 5533.0 | -991.1 | -15.19% | -0.21, -2.29 | 8 / 0 | claimed |

## Drivers: ours

[`attribute.rb`](../../bench/upstream/merged_sum/attribute.rb) with `LABELS` and `SPLIT=1`. Allocation sites are
blamed to a revert or PR commit. PRs that share a file are grouped; "/ N" is the blame split inside the group, and
"/ ?" means lines neither tree blames on one PR. Only allocations are attributed; instructions are not attributed
by PR.

| # | PR (group / blame) | Census Δ objects (sum over 52 workloads) | ruby-bench Δ objects (one traced iteration, all four) |
| ---: | --- | ---: | ---: |
| 1 | #59533 + #59541 + #59576 (WhereClause) | −2,849 | −27,221 |
| 2 | #59278 + #59536 + #59542 + #59558 + #59596 (adapter, warnings, intents) | −1,918 | −29,816 |
| 3 | #59316 (HTTP URLs) | −923 | −14,180 |
| 4 | #59561 (`thread_mattr_accessor` key) | −1,049 | −12,000 |
| 5 | #59620 (renderers Set per render) | 0 | −12,172 |
| 6 | #59608 (`prepend_formats`) | 0 | −12,135 |
| 7 | #59235 + #59613 (notification handles) | −329 | −8,247 |
| 8 | #59552 (direct association scopes) | −667 | −7,104 |
| 9 | #59534 (Arel project/order in place) | −613 | −4,991 |
| 10 | #59562 (`Subscriber#call` event name) | −642 | −4,544 |
| | #59244 + #59537 + #59603 | −570 | — |
| | #59618 (star projection) | −381 | −2,501 |
| | unblamed file `array/extract.rb` | −947 | −9,781 |
| | **all of ours** | **−12,887** | **−155,679** |

Our only costs are inside groups: #59613 +1,122 (census) and +11,880 (ruby-bench), and #59576 +225 and +1,226.
These are lines that moved inside their group and net out with #59235 and #59533. Per app, census ours: fizzy
−6,628, lobsters −3,223, writebook −1,602, campfire −1,000, blog −434. Per ruby-bench iteration: shipit −80,926,
railsbench −39,830, erubi-rails −20,000, lobsters −14,923.

## Drivers: residual (others), for the record only

[`others.rb`](../../bench/upstream/rails_82_impact/others.rb) compares minus-ours with 8-1-stable per Rails method,
keyed by file plus the nearest `def` (lines shift between trees). The method's lines are blamed on main, with our
revert commits ignored, and mapped to the first-parent merge that brought them in. Blame names who last touched
the method, not what caused the change. Docs-only or test PRs that show up (#59339 Markdown docs, #58335 tests)
are blame artifacts. "Unchanged lines" means the cost moved through callers or callees. #59329 is ours, and shows
up only because ignoring revert commits maps its lines back. A/A for every row below is ≤ 6 objects.

**Savings**, census (blog + Writebook) and per traced ruby-bench iteration (all four):

| # | Method | Blamed PR(s) | Census Δ | ruby-bench Δ |
| ---: | --- | --- | ---: | ---: |
| 1 | `structured_event_subscriber.rb from_rails_root` | #58476 (gmcgibbon: ractor-safe Action View subscribers) | — | −89,682 |
| 2 | `static.rb file_readable?` | #59053 (amatsuda: skip static candidates) | −260 | −77,740 |
| 3 | `tag_helper.rb tag_option` | #59117 (amatsuda: tag attributes without a String each) | −1,327 | −32,522 |
| 4 | `journey/visitors.rb evaluate` | #59058 (amatsuda: URL generation), #59619 | — | −32,304 |
| 5 | `http/request.rb initialize` / `url.rb host` | #59104, #59088 (amatsuda: memoized host, lazy Rack::Request) | −533 | −29,653 |
| 6 | `fanout.rb build_handle`, `groups_for` | #58335, #59095 (and our #59235 lines) | — | −55,913 |
| 7 | `attribute_set/builder.rb initialize` | #59083 (tenderlove: read-only attributes) | −196 | −24,828 |
| 8 | `layouts.rb _include_layout?`, `rendering.rb` options | #59271 (sampokuokkanen: render option keys) | — | −48,580 |
| 9 | `template_renderer.rb resolve_layout`, `resolver.rb` | #57783 (etiennebarrie: split template lookup); resolver: unchanged lines | −368 | −70,664 |
| 10 | `predicate_builder.rb references`, `convert_dot_notation_to_hash` | #59208 (kamipo) | −437 | — |
| | `asset_url_helper.rb asset_path` | #58270 (nuclearspike) | −302 | — |
| | `integration.rb to_param` | #59087 (amatsuda: single-key `to_param`) | −184 | — |
| | `journey/formatter.rb generate` | #58412 (carldaws) and others | −300 | — |

`time/conversions.rb` → `time_formats.rb` (−120,100 / +120,100 at top level) is a file move that nets out.

**Costs** (8.1 → minus-ours, more objects):

| # | Method | Blamed PR(s) | Census Δ | ruby-bench Δ |
| ---: | --- | --- | ---: | ---: |
| 1 | `enumerable.rb index_with` | **#59555 (ours, bug fix, not reverted)**, #58217 | +726 | +87,314 |
| 2 | `request_forgery_protection.rb append_sec_fetch_site_to_vary_header` | #59375, f5a1915f1d (new CSRF approach), #58421 | +110 | +23,672 |
| 3 | `action_controller/renderer.rb render` | #50623 (seanpdoyle: render options to `render_in`) | — | +20,000 |
| 4 | `database_statements.rb finalize_remaining_intents`, `start_intent_log`, `select_all` | 635454d310, 5c5683125a, 1277a8f09c (query intents) | +325 | +15,484 |
| 5 | `indexed_row.rb initialize`, `new_empty_mutable_row` | 1fbedade58, 3be318dff8, #58896 (IndexedRow) | +212 | +26,902 |
| 6 | `attribute_set/builder.rb build_from_database` | dc7935b226, #59083 | +98 | +12,414 |
| 7 | `renderers.rb _all_renderers` | #57830 (Edouard-chin: ractor-safe renderers); our #59620 takes it back on main | — | +12,199 |
| 8 | `scoping/default.rb has_default_scope?`, `build_default_scope` | #59237 (kamipo), #57642 | +94 | +8,987 |
| 9 | `navigation_helper.rb convert_options_to_data_attributes` | #55410 (seanpdoyle: NavigationHelper) | — | +8,052 |
| 10 | `abstract_adapter.rb build_retry_budget` | b41b990ce6 (connection retry accounting) | +109 | — |
| | `cookies.rb encryptor` | #59483 (linyiru: lazy cookie verifier) | +96 | — |

**Unattributed instruction costs.** The residual costs **+4.1% instructions on shipit** and **+2.1% on blog's GET
pages**, while both allocate fewer objects (shipit −14.6%, blog −20.6%). So the cost is CPU, not allocation, and
this run doesn't attribute instructions. Candidates for a follow-up callgrind diff, not established: shipit's 8.2
defaults on ruby-bench (`strict_accept_header`, `default_headers`, the `header_only` CSRF strategy, the JSON
message serializer), the new CSRF Vary header path (cost row 2), and query-intent logging (cost row 4). Blog runs
`load_defaults 8.1` on both trees, so its cost is not the defaults.

## Rejected rows

* Every ruby-bench YJIT row (not JIT-flat): railsbench total −38.4%, ours −3.0%, residual −36.4%, backports +0.87%;
  erubi-rails total −16.8%, ours −4.8%, residual −12.6%.
* ruby-bench YJIT for lobsters and shipit: not completed (the cache race above), and not flat where measured.
* Lobsters on ruby-bench, ours: −0.32% instructions against a +0.20% A/A on minus-ours.
* Blog GET pages, total: +0.23% against a +0.44% A/A on 8.1.
* Campfire GET pages, ours: −0.07% against −0.27% A/A.
* Erubi-rails, 8-1-stable vs merge base: +0.02%.
* The Herb control: +0.06% and +0.10%.
* App YJIT: skipped, per the brief (it failed A/A in merged-sum).

## Reproduce

Scripts are in `bench/upstream/rails_82_impact/` (`ir_table.rb`, `census_table.rb`, `others.rb`, `reverted.tsv`),
plus `actionview_cpu/ruby_bench_ir.rb`, which now preloads `jit_counts.rb` under YJIT and prints a flat column.
`merged_sum/attribute.rb` and `alloc_table.rb` now take label arguments. Results are under `.lowrail/private/imp`
and `.lowrail/private/census/imp-*`.
