# What our merged Rails PRs add up to (2026-11-04)

Follow-up to [combined-effect](combined-effect.md) (bet R5, eleven PRs, allocations only). This round reverts every
merged rails/rails performance PR of ours that still reverts cleanly (39 of 44) and measures allocations and
instruction counts against current main. Correctness of the same PRs: [merged-audit](merged-audit.md). Nothing here
is posted upstream.

**Result.** On Ruby 4.0.9, main allocates **3.8% fewer objects per census workload** than main with the 39 PRs
reverted (52 request, job and mailer workloads in five apps; A/A ≤ 0.04%; every workload moves, none allocates
more), and **1.2–9.7% fewer per ruby-bench iteration** (A/A ≤ 0.01%). Instructions: ruby-bench **−2.0% to −7.0%**
where the A/A passes (railsbench, erubi-rails, shipit; both modes); app GET pages −2.0% to −3.4% in the
interpreter for Fizzy, Writebook and Lobsters, flat for Campfire. Lobsters on ruby-bench and the apps under YJIT
fail their A/A and are not claimed. These are instruction and allocation counts, not timings.

## Trees and pins

* **With:** rails/rails main [`6c23cb8f2a`](https://github.com/rails/rails/commit/6c23cb8f2a34b4cb1e10656b492027a4c008f446)
  (2026-11-04, merge of #59615). Two worktrees of the same commit for the A/A pair.
* **Without:** the same commit with 39 merges reverted (`git revert -m 1`, newest first in main's first-parent
  order; local commit `3e5bff6bac`, reproducible from [`reverted.tsv`](../../bench/upstream/merged_sum/reverted.tsv)).
* **Skipped, not performance:** #7260 (2012 docs), #59555 (`index_with` bug fix), #59606 (restored handler methods).
* **Dropped because the revert conflicts** (later commits by others rewrote the same lines, mostly kamipo's merger
  work: 873d897d42, 8f71c51c51, bb359be47a, 401f146f41, 84048ad477): #59556 (merge reads values without a copy),
  #59551 (skip `extending!`), #59554 (bang method names), #59543 (`except`/`only` without a copy), #59236
  (CurrentAttributes defaults). Their savings are in both trees, so the totals below understate ours.
* **Ruby 4.0.9**, interpreter and `--yjit`, production. Fixed heap as in [bench.md](../bench.md): `RUBY_GC_HEAP_0..4_INIT_SLOTS`
  1,000,000 / 250,000 / 100,000 / 20,000 / 10,000 for every instruction and per-iteration allocation run.
* **Census:** `script/census run --ruby 4.0.9` on blog, campfire, fizzy, lobsters, writebook (the five copies set up
  here; the PG/MySQL apps were not set up on this orb), ABBA order `sum-with`, `sum-without`, `sum-without2`,
  `sum-with2`; table by [`census_table.rb`](../../bench/upstream/combined_effect/census_table.rb).
* **ruby-bench** `73918b2` with lobsters and shipit pointed at a local Rails path, the two Rails 8.2 config lines and
  the shipit-engine `ReviewStack` patch from [index_with_ruby_bench](../../bench/upstream/index_with_ruby_bench/README.md).
  Instructions: [`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb) (difference of a long and a
  1-iteration run; erubi-rails 10, the others 4). Per-iteration objects and GC runs:
  [`sumalloc.rb`](../../bench/upstream/merged_sum/sumalloc.rb) (copy to ruby-bench's `harness/`, `HARNESS=sumalloc`),
  5 warmup + 10 measured iterations, two processes per tree.
* **App instructions:** [`census_ir_run.rb`](../../bench/upstream/actionview_cpu/census_ir_run.rb), GET-page rounds
  (2 and 32 rounds, difference over 30) in the census copies; order with, without, with2. Jobs and writes are in the
  allocation census only.

## Allocations

Census, objects per workload (interpreter / YJIT):

| App | Workloads | Objects/workload without → with | Δ | Share | A/A with, without | Moved ≤ −1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1752 → 1707 / 1763 → 1702 | −44.7 / −61.3 | −2.55% / −3.48% | +0.64%, +0.31% / +0.07%, +0.95% | 9 (2) / 10 (0) |
| campfire | 9 | 6377 → 6250 / 6397 → 6269 | −127.5 / −127.7 | −2.00% / −2.00% | ±0.01% | 9 (0) / 9 (0) |
| fizzy | 14 | 10465 → 9931 / 10542 → 10014 | −534.3 / −528.5 | −5.11% / −5.01% | ≤ 0.06% | 14 (2) / 14 (2) |
| lobsters | 11 | 11776 → 11411 / 11809 → 11442 | −365.7 / −366.9 | −3.11% / −3.11% | ≤ 0.02% | 11 (2) / 11 (3) |
| writebook | 8 | 5534 → 5301 / 5567 → 5334 | −232.6 / −232.3 | −4.20% / −4.17% | ≤ 0.03% | 8 (0) / 8 (5) |
| **All five** | 52 | 7601 → 7313 / 7639 → 7350 | −287.7 / −289.6 | **−3.78% / −3.79%** | +0.03%, +0.04% / +0.02%, +0.04% | 51 (6) / 52 (10) |

`script/census compare`: 52 of 52 workloads fall by ≥ 1 object in both modes against the reverted tree, 0 rise; the
reverted tree's own A/A moves 17 / 10 down and 3 / 11 up. SQL digests change on 0 workloads. Blog's A/A (up to
0.95%) comes from its write workloads; its effect (−2.6% / −3.5%) is still several times larger.

ruby-bench, objects per iteration (mean of two processes per tree):

| Benchmark | Mode | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 1,026,639 → 976,242 | **−4.91%** | +0.00%, −0.00% | 1.50 → 1.40 |
| railsbench | YJIT | 1,031,975 → 981,575 | **−4.88%** | +0.00%, +0.00% | 1.50 → 1.50 |
| erubi-rails | interpreter | 1,650,001 → 1,630,001 | **−1.21%** | +0.00%, +0.00% | 3.70 → 3.50 |
| erubi-rails | YJIT | 1,670,001 → 1,650,001 | **−1.20%** | +0.00%, +0.00% | 3.70 → 3.60 |
| lobsters | interpreter | 558,949 → 541,020 | **−3.21%** | −0.01%, +0.01% | 0.40 → 0.40 |
| lobsters | YJIT | 562,425 → 544,479 | **−3.19%** | −0.00%, +0.00% | 0.40 → 0.40 |
| shipit | interpreter | 988,661 → 892,869 | **−9.69%** | −0.00%, +0.00% | 1.65 → 1.60 |
| shipit | YJIT | 1,001,855 → 906,066 | **−9.56%** | +0.00%, −0.00% | 1.70 → 1.50 |

No major GCs in the measured iterations except lobsters' 0.1 per iteration in both trees. With the fixed heap, the
GC count per iteration drops by at most 0.2.

## Instructions

ruby-bench, instructions per iteration, main against the reverted tree (one sample each unless noted):

| Benchmark | Mode | with vs without | A/A (with2 vs with) | Claimed |
| --- | --- | ---: | ---: | --- |
| erubi-rails | interpreter | **−1.98%** | −0.02% | yes |
| erubi-rails | YJIT | **−3.90%** | −0.09% | yes |
| railsbench | interpreter | **−2.19%** | −0.13% | yes |
| railsbench | YJIT | **−2.00%** | −0.54% | yes |
| shipit | interpreter | **−6.33%** | −0.05% | yes |
| shipit | YJIT | **−7.00%** | −0.16% | yes |
| lobsters | interpreter, 2 samples | −2.0%, −2.0% | **+1.94%, +1.87%** | no |
| lobsters | YJIT | −9.0% | **+2.55%** | no |

(The summary reports without vs with; the table inverts it: with/without − 1.) Lobsters' A/A fails twice in the same
direction: the second main tree counts 1.9% more than the first, about as much as the reverted tree. Its effect is
therefore not distinguishable from noise on this harness, although its allocations move cleanly (−3.2%).

App GET pages (instructions per round, with vs without; second column is the second with-tree run, so the gap
between the two is the A/A):

| App | Interpreter: with, with2 | YJIT: with, with2 |
| --- | --- | --- |
| blog | −1.97%, −0.46% | −3.27%, −1.55% |
| campfire | −0.07%, +0.04% | −0.97%, +9.40% |
| fizzy | **−2.78%, −2.84%** | +0.35%, −0.51% |
| lobsters | **−2.87%, −2.02%** | −0.98%, −0.28% |
| writebook | **−3.35%, −3.37%** | −3.35%, −1.85% |

Claimed: Fizzy, Writebook and Lobsters in the interpreter (A/A ≤ 0.85%). Blog's interpreter A/A (1.5%) is as large
as its effect; Campfire is flat. Every YJIT row is inside A/A swings of 0.9–10.4% (campfire's 9.4% included), as in
[actionview-cpu](actionview-cpu.md): app state varies between processes more than Valgrind's count does.

## Which PRs carry it

**Allocations, by site.** [`attribute.rb`](../../bench/upstream/merged_sum/attribute.rb) sums the per-site change
(RAILS/file:line, mean of each A/A pair) and assigns every site to the reverted PRs that touched its file. PRs that
share a file are one group, since a PR can move an allocation from one line to another; inside a group, `git blame`
splits most of it. Census (52 workloads, interpreter, 12,411 objects in total):

| PR(s) | Objects | Share | Mainly |
| --- | ---: | ---: | --- |
| #59533 + #59541 + #59576 (WhereClause / where compile) | −2,849 | 23% | #59533 −1,058 by blame |
| #59278 + #59536 + #59542 + #59558 + #59596 (database statements, result casting) | −1,918 | 15% | #59542 −950, #59536 −722 |
| #59561 (`thread_mattr_accessor` key) | −1,049 | 8.5% | |
| `array/extract.rb` (no reverted PR touches it; called by #59544's ArrayHandler) | −947 | 7.6% | #59544 |
| #59316 (HTTP URLs) | −923 | 7.4% | |
| #59552 (direct association constraints) | −667 | 5.4% | |
| #59562 (Subscriber event name) | −642 | 5.2% | |
| #59534 (Arel project/order in place) | −613 | 4.9% | |
| #59244 + #59537 + #59603 (tag helper, attribute keys) | −570 | 4.6% | |
| #59235 + #59613 (notification handles) | −329 | 2.6% | |
| the rest | −1,904 | 15% | each ≤ 2.4% |

Under YJIT the order is the same (10,973 objects; #59533's group 21%). The top ten groups carry 85%.

ruby-bench (one traced iteration per tree with [`sumsites.rb`](../../bench/upstream/merged_sum/sumsites.rb); the
traced Rails sites cover 75–83% of the measured per-iteration saving, the rest is allocated in gem or app frames):

* **railsbench:** #59561 −12,000 per iteration, the DB statement group −7,940, #59316 −7,800, #59235 −4,000,
  #59562 −4,000, #59608 −2,000.
* **shipit:** the WhereClause group −24,489, the DB statement group −18,858, #59544 (`extract.rb`) −9,022, #59552
  −6,746, #59534 −3,674.
* **lobsters:** #59316 −3,038, the DB statement group −3,018, the WhereClause group −2,732, #59534 −1,287.
* **erubi-rails:** all of it is #59608 (two objects per render × 10,000 renders).

**Instructions, by revert subset** (erubi-rails, railsbench and lobsters; three more trees: only the 22 Active
Record/Arel PRs reverted, only the other 17, only #59608):

| Benchmark | Mode | All 39 | AR/Arel only | Other 17 only | #59608 only |
| --- | --- | ---: | ---: | ---: | ---: |
| erubi-rails | interpreter | +2.02% | −0.30% | +2.05% | +2.07% |
| erubi-rails | YJIT | +4.06% | −0.01% | +4.10% | +3.74% |
| railsbench | interpreter | +2.24% | +1.22% | +0.74% | — |

(Reverted tree against main; positive = the revert costs instructions.) erubi-rails' whole instruction gain is
#59608 (`prepend_formats`). railsbench splits about 60/40 between the Active Record PRs and the rest. Per-iteration
allocations split the same way: railsbench 16% AR / 84% other, lobsters 54 / 46, shipit 78 / 22.

## Noise bounds, in short

* Census allocations: A/A ≤ 0.04% overall, ≤ 0.06% per app except Blog (≤ 0.95%). Effect 2.0–5.1% per app.
* ruby-bench allocations: A/A ≤ 0.01%. Effect 1.2–9.7%.
* ruby-bench instructions: A/A ≤ 0.54% on the claimed rows, one sample each; lobsters fails (+1.9%, +2.6%).
* App instructions: interpreter A/A ≤ 0.85% on the claimed rows; YJIT not claimed.
* Not measured here: wall time (R5 found it unresolvable at this size on this orb), PostgreSQL/MySQL apps, ZJIT,
  and the five PRs whose reverts conflict.

Receipts (private, not committed): `.lowrail/private/census/sum-*`, `.lowrail/private/sum/{ir,appir,alloc,sites}`.
