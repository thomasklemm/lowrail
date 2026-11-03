# Combined effect of our merged Rails PRs

Lowrail bet R5. Each of our rails/rails PRs claimed allocation counts only, measured on its own. This page measures
all merged ones together, as one before/after: Rails main against the same commit with every one of them reverted.

**Result.** Measured together on Rails main `5810776eec` against the same commit with all eleven merged PRs
reverted (#59533–#59544), our merged Rails PRs remove **1.66% of all allocations (interpreter) and 1.64% (YJIT)**
across 206 request, job and mailer workloads in sixteen open-source apps (19 configurations, SQLite, PostgreSQL and
MySQL): about 195 objects per workload. Every app moves, by 0.8% to 3.0%, and no workload allocates more. Each
tree's A/A pair stays within ±0.12% overall. Wall time on ruby-bench's railsbench and lobsters is **a tie**: their
iterations allocate 0.4% and 1.3% fewer objects, GC runs per iteration do not change, and every timing ratio is
inside its A/A spread. These are allocation savings, not a measured speedup.

**Under ZJIT** (bet F2, [below](#zjit-bet-f2)), on Ruby master and the 22 PRs merged by 2026-11-03 10:43 UTC, the
savings carry over unchanged: −3.21% of allocations under ZJIT and −3.27% interpreted on census 4's nine apps. ZJIT
Ir on ruby-bench falls 0.5%, and no PR adds net ZJIT fallbacks or exits in three or more apps.

## Pins and method

* **Rails, with the PRs:** canonical `rails/rails` main
  [`5810776eec`](https://github.com/rails/rails/commit/5810776eecc5b2e50b58e81ee0c26c02c718fdf0) (merge of #59544;
  `git ls-remote` on 2026-11-03 found main still there).
* **Rails, without:** the same commit with the eleven merges reverted (`git revert -m 1`, newest first): #59544
  `5810776eec`, #59543 `f861e1e0ce`, #59542 `ee16712354`, #59541 `1c4feea25b`, #59534 `090f5408f4`, #59539
  `d9ed22eef0`, #59538 `f4a40dc8a1`, #59537 `45de402637`, #59536 `4740314734`, #59535 `c0cacea4cd`, #59533
  `b5be03636e`. Every revert applied cleanly, so no conflict needed resolving. Main's first-parent history after
  `e77813d4e8` is exactly these eleven merges, and the reverted tree is byte-identical to `e77813d4e8` (`git diff`
  is empty): "without" is main as it was just before #59533. The reverted commit is local (`a4135904ee`, not pushed);
  `e77813d4e8` reproduces it.
* **Not included:** our seven October PRs (#59235, #59236, #59244, #59252, #59270, #59274, #59278) are in both trees,
  and so are open PRs (#59551–#59558). They are not part of this before/after.
* **Ruby 4.0.7**, interpreter and `--yjit`, production environment.
* **Allocations:** [`script/census`](../../script/census) ([census.md](census.md)) on all nineteen configurations:
  census 4's nine apps (ten configurations, with Fizzy on SQLite and MySQL 8.4.10) and the PG census's seven apps
  plus `mastodon-nops` and `lago-nops` ([pg-census.md](pg-census.md)); 206 workloads per mode. All copies were set
  up fresh from the census overlays on `5810776eec`; the reverted tree swaps only the Rails git ref, and `run`'s
  dependency control found no other lock difference. Four full runs in ABBA order
  ([`census_abba.sh`](../../bench/upstream/combined_effect/census_abba.sh)): `with`, `without`, `without2`,
  `with2`, so state that accumulates between runs (write workloads) favours neither tree. Each tree's two runs are
  its A/A pair. Table: [`census_table.rb`](../../bench/upstream/combined_effect/census_table.rb).
* **Objects per workload** is the census's measure: the median of three GC-enabled windows of 20 operations, after 50
  warmups, per workload; the tables give the mean over an app's workloads, averaged over each tree's two runs. The
  **share** is the change over the reverted tree's total.
* **Wall time:** ruby-bench's railsbench and lobsters, Rails pinned to each tree. See [Wall time](#wall-time).
* **Setup notes:** Mastodon's `idn-ruby` needs `libidn-dev`; `script/census setup` stopped on Docuseal, whose
  `db:create` reports the database it has just created as existing (its configurations share one URL). The check now
  ignores databases the same call created.

## Allocations

Interpreter / YJIT in every cell. Without = the PRs reverted, with = Rails main. A/A is each tree's second run
against its first, on the same scale as Share. Moved counts the workloads whose objects per operation fell by at
least one (mean of each pair), with the A/A count (`with2` against `with`) in brackets.

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Workloads moved ≤ −1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1752 → 1728 / 1749 → 1732 | −23.5 / −16.7 | −1.34% / −0.95% | +0.02%, −0.08% / +0.47%, +0.06% | 10 (2) / 9 (1) |
| campfire | 9 | 6396 → 6326 / 6415 → 6345 | −70.5 / −70.2 | −1.10% / −1.10% | −0.00%, +0.00% / −0.00%, +0.00% | 9 (0) / 9 (0) |
| fizzy | 14 | 10562 → 10258 / 10652 → 10342 | −304.2 / −310.2 | −2.88% / −2.91% | −0.10%, −0.00% / −0.10%, +0.01% | 14 (3) / 14 (5) |
| fizzy-mysql | 14 | 10278 → 9978 / 10363 → 10062 | −300.3 / −301.5 | −2.92% / −2.91% | −0.03%, −0.05% / −0.00%, −0.05% | 14 (2) / 14 (1) |
| lobsters | 11 | 11778 → 11651 / 11820 → 11690 | −126.9 / −130.6 | −1.08% / −1.11% | −0.03%, +0.06% / −0.01%, −0.00% | 10 (5) / 10 (4) |
| react-starter-kit | 8 | 1985 → 1969 / 1989 → 1973 | −15.5 / −15.4 | −0.78% / −0.77% | −0.07%, −0.05% / −0.03%, −0.00% | 7 (5) / 7 (2) |
| redprints-cfp | 8 | 2137 → 2113 / 2147 → 2122 | −24.2 / −24.9 | −1.13% / −1.16% | −0.01%, −0.00% / +0.06%, −0.02% | 7 (3) / 7 (1) |
| writebook | 8 | 5546 → 5429 / 5582 → 5467 | −117.0 / −115.9 | −2.11% / −2.08% | +0.01%, +0.01% / +0.00%, +0.00% | 8 (2) / 8 (4) |
| casa | 10 | 14301 → 13933 / 14445 → 14076 | −368.1 / −369.0 | −2.57% / −2.55% | −0.00%, +0.00% / +0.00%, +0.00% | 10 (2) / 10 (3) |
| codetriage | 7 | 2868 → 2841 / 2885 → 2859 | −27.3 / −25.9 | −0.95% / −0.90% | +0.11%, +0.05% / +0.01%, +0.03% | 7 (0) / 7 (4) |
| discourse | 14 | 13483 → 13314 / 13558 → 13406 | −169.8 / −152.1 | −1.26% / −1.12% | +1.25%, −0.86% / +0.14%, −0.05% | 13 (1) / 13 (2) |
| docuseal | 13 | 8249 → 8139 / 8304 → 8197 | −109.5 / −107.6 | −1.33% / −1.30% | −0.00%, −0.01% / −0.01%, +0.00% | 13 (3) / 13 (6) |
| lago | 10 | 7283 → 7063 / 7375 → 7155 | −219.6 / −219.4 | −3.02% / −2.98% | +0.01%, −0.00% / −0.01%, +0.00% | 10 (1) / 10 (2) |
| lago-nops | 10 | 7262 → 7041 / 7352 → 7132 | −221.1 / −219.6 | −3.04% / −2.99% | −0.02%, −0.04% / +0.01%, +0.00% | 10 (2) / 10 (0) |
| loomio | 15 | 10412 → 10199 / 10519 → 10305 | −213.1 / −213.2 | −2.05% / −2.03% | +0.47%, +0.16% / +0.48%, +0.17% | 15 (1) / 15 (4) |
| mastodon | 14 | 19665 → 19463 / 19764 → 19562 | −202.8 / −202.9 | −1.03% / −1.03% | −0.00%, +0.00% / −0.00%, +0.00% | 14 (1) / 14 (0) |
| mastodon-nops | 14 | 19615 → 19412 / 19714 → 19511 | −202.9 / −202.9 | −1.03% / −1.03% | +0.00%, +0.00% / +0.00%, +0.00% | 14 (0) / 14 (0) |
| pingcrm | 8 | 2988 → 2962 / 2999 → 2971 | −26.4 / −27.6 | −0.88% / −0.92% | +0.01%, −0.08% / −0.13%, −0.02% | 8 (3) / 8 (7) |
| sure | 9 | 58250 → 57452 / 58544 → 57746 | −798.3 / −798.4 | −1.37% / −1.36% | +0.00%, +0.00% / −0.00%, −0.00% | 9 (2) / 9 (4) |

| Scope | Workloads | Objects/workload without → with | Δ | Share | A/A with, without | Moved (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Census 4's nine apps (10 configurations) | 97 | 6,368 → 6,241 / 6,406 → 6,278 | −127.7 / −128.4 | **−2.00% / −2.00%** | −0.03%, −0.00% / −0.02%, −0.01% | 94 (25) / 93 (29) |
| PG census (nine PG apps, 11 configurations) | 124 | 14,990 → 14,762 / 15,089 → 14,863 | −228.7 / −226.4 | **−1.53% / −1.50%** | +0.17%, −0.08% / +0.05%, +0.01% | 123 (16) / 123 (32) |
| All 19 configurations | 206 | 11,808 → 11,613 / 11,885 → 11,690 | −195.8 / −194.8 | **−1.66% / −1.64%** | +0.12%, −0.06% / +0.04%, +0.01% | 202 (38) / 201 (50) |

* **Every app moves, in both modes.** Per-app shares run from −0.77% (react-starter-kit) to −3.04% (lago-nops);
  the median app saves 1.33%. Each app's A/A is at most ±0.17%, with three exceptions: the Blog under YJIT (+0.47%,
  one write workload), and Discourse and Loomio, whose state grows from run to run (`GET topic.json`, `POST
  comment`, as in the [PG census](pg-census.md)). Discourse's interpreter A/A (+1.25%) is as large as its effect
  (−1.26%), but 13 of its 14 workloads move, against 1 in the A/A.
* **No workload allocates more.** Across both modes, `script/census compare` of `with` against `without` finds 0
  workloads moved ≥ +1. The A/A pairs move 33–51 workloads in each direction. The handful that do not move
  allocate exactly the same in both trees (for example Lobsters' `EmailReplyMailer#reply` and Discourse's
  `NotifyMailingListSubscribers` job: Δ 0.0).
* **Interpreter and YJIT agree** to within 0.05 points everywhere except the Blog (−1.34% / −0.95%, inside its YJIT
  A/A of +0.47%) and Discourse (cumulative state).
* **Prepared statements on or off** make no difference: mastodon/mastodon-nops and lago/lago-nops save the same.
* **SQL control:** 8 / 6 workloads change their masked SQL digest between `with` and `without`, against 12 / 7 and
  8 / 6 in the two A/A pairs. The PRs change no queries.

## Wall time

ruby-bench (byroot/ruby-bench `bf1afb2` with
[`ruby-bench.patch`](../../bench/upstream/index_with_ruby_bench/ruby-bench.patch), as in
[index-with-capacity](index-with-capacity.md)): two checkouts whose Gemfiles differ only in the Rails path, one per
tree. [`walltime.sh`](../../bench/upstream/combined_effect/walltime.sh) runs ten rounds. Each round runs every app
and mode as four processes, with-A, without-A, without-B and with-B, in an order rotated by round, all pinned to
one CPU on an otherwise idle orb. Each process does 10 warmup and 20 timed iterations through
[`harness.rb`](../../bench/upstream/combined_effect/harness.rb), which also records GC runs and allocated objects
per iteration outside the timed block.

Per process: the median of the 20 timed iterations. Per round: with (mean of A and B) over without. A/A is B over A
within each tree. [`walltime_summary.rb`](../../bench/upstream/combined_effect/walltime_summary.rb) reports the
median and range over the rounds and a 95% t-interval of the mean log ratio. Ruby 4.0.7. Round 1 was redone,
because the receipts were being compressed while its first processes ran; the discarded logs are kept in the
receipts.

| App | Mode | Rounds | without ms | with ms | with / without: median (range) | mean [95% CI] | A/A with | A/A without | GC/iter without → with | major/iter | objects/iter without → with |
| --- | --- | ---: | ---: | ---: | --- | --- | --- | --- | --- | --- | --- |
| lobsters | interpreter | 10 | 1618.8 | 1581.8 | −1.3% (−11.2% … +11.8%) | −0.3% [−5.4%, +5.1%] | +1.3% (−12.5% … +7.4%); [−3.3%, +5.5%] | +2.5% (−13.3% … +7.6%); [−6.6%, +4.8%] | 0.63 → 0.65 | 0.0 → 0.0 | 557199 → 549649 (−1.4%) |
| lobsters | YJIT | 10 | 927.5 | 912.3 | −0.4% (−5.7% … +5.0%) | −0.0% [−2.4%, +2.5%] | −5.1% (−8.4% … +7.9%); [−6.9%, +0.8%] | +1.5% (−11.6% … +9.5%); [−4.5%, +5.3%] | 0.65 → 0.64 | 0.0 → 0.0 | 561327 → 553779 (−1.3%) |
| railsbench | interpreter | 10 | 2273.9 | 2365.8 | +0.6% (−3.7% … +8.4%) | +1.5% [−1.3%, +4.3%] | −0.4% (−13.2% … +22.0%); [−5.7%, +7.2%] | +0.6% (−7.0% … +21.1%); [−3.1%, +7.2%] | 6.37 → 6.27 | 0.79 → 0.73 | 970484 → 966424 (−0.4%) |
| railsbench | YJIT | 10 | 1033.2 | 1031.8 | −0.1% (−3.9% … +5.3%) | +0.6% [−1.6%, +2.8%] | +0.2% (−4.5% … +7.4%); [−2.4%, +3.0%] | +2.1% (−7.1% … +5.2%); [−1.8%, +3.4%] | 6.32 → 6.29 | 0.75 → 0.75 | 975830 → 971770 (−0.4%) |

* **No measurable effect.** Every with/without interval contains zero: lobsters −0.3% [−5.4, +5.1] / −0.0%
  [−2.4, +2.5], railsbench +1.5% [−1.3, +4.3] / +0.6% [−1.6, +2.8] (interpreter / YJIT). Single rounds of the
  same tree differ by up to 22%, and the A/A intervals are as wide as the effect intervals. The narrowest
  intervals (YJIT, about ±2.5%) cannot resolve an effect the size of the allocation saving.
* **The benchmarks allocate little of what changed.** railsbench iterations allocate 0.4% fewer objects (about
  4,060 per iteration) and lobsters 1.3% fewer (about 7,550). Both are stable to within 40 objects across all 20
  processes per tree, app and mode. Both savings are below the census's 1.66%.
* **GC count per iteration is unchanged:** railsbench about 6.3 runs (0.73–0.79 major), lobsters about 0.64 (no
  major), in both trees. Saving 0.4% of the objects does not remove a GC run from a 6-run iteration.

Receipts: [`data/combined-effect/receipts.tar.xz`](data/combined-effect/receipts.tar.xz) holds every census run
JSON, log and `meta.json` for `with`, `with2`, `without` and `without2`.
[`data/combined-effect/walltime.tar.xz`](data/combined-effect/walltime.tar.xz) holds every wall-time process
JSON and log, including the discarded round 1.

## ZJIT (bet F2)

**Result.** On Ruby master with ZJIT, our 22 merged Rails PRs save the same allocations as in the interpreter:
**−3.21% of all allocations under ZJIT and −3.27% interpreted** (−203 / −206 objects per workload) across census 4's
nine apps (10 configurations, 97 workloads). Every workload moves, and none allocates more. Each tree's A/A pair stays
within ±0.06% overall. They also lower ZJIT's work: dynamic sends fall in every app (−1% to −10% per operation), send
and ivar fallbacks fall in nine of ten (the Blog's +0.2% is inside its A/A), and Callgrind Ir per iteration on
ruby-bench under ZJIT drops **0.54% (railsbench) and 0.49% (lobsters)**, well outside the A/A. Three PRs each raise one ZJIT counter, and each
does so by turning other ZJIT work into it: **#59541** adds `SendForward: not yet specialized` fallbacks (five apps, six configurations)
through a `delegate`d `empty?`, **#59537** replaces `concatarray` side exits with splat-argument fallbacks (3 apps),
and **#59568** adds class-guard side exits in Writebook (+36 per operation) while removing 1,274 dynamic sends there.

### Pins and method

* **Ruby:** ruby/ruby master [`9aa0898240`](https://github.com/ruby/ruby/commit/9aa089824003b9fde7ff2de6953d282def364edb)
  (2026-11-03 12:42 UTC), `./configure --enable-yjit --enable-zjit --disable-install-doc`, Rust 1.99.1, release
  build. ZJIT defaults (`--zjit-mem-size` 128 MiB, of which `--zjit-exec-mem-size` 64 MiB of executable code,
  call threshold 30) for the allocation and Callgrind runs. The stats runs used `--zjit-mem-size=128`; Fizzy,
  Fizzy-MySQL and Lobsters were rerun at `--zjit-exec-mem-size=512 --zjit-mem-size=1024` (see the warmup gate). The
  F1 thread was told the pin.
* **Rails, with:** canonical `rails/rails` main
  [`c042aee23a`](https://github.com/rails/rails/commit/c042aee23a56205c43c9a60219cd1c4d7f7576a8) (merge of #59575,
  2026-11-03 10:43 UTC).
* **Rails, without:** the same commit with 23 merges reverted (`git revert -m 1`, newest first), local commit
  `14ac835463` (not pushed). Our 22 merged PRs: #59533–#59539, #59541–#59544, #59551–#59556, #59558, #59560, #59561,
  #59563, #59568. **Confound: kamipo's #59572** ("Skip merging a relation's values into themselves", merge
  `b084108cf3`) is reverted too. It builds on #59556 (`values_for_merge`), so #59556's revert conflicted in
  `merger.rb` and `merging_test.rb` until #59572 was reverted first. No conflict was resolved by hand; after the
  reverts `merger.rb` is identical to pre-wave `e77813d4e8`. #59572 skips self-merges, which these workloads rarely
  do, but its effect is inside these numbers.
* **Not included:** our October PRs (#59235–#59278, #59316, #59329) are in both trees, as in the 4.0.7 measurement
  above. #59571 and #59576 merged after the pin (13:59 and 14:19 UTC) and are in neither.
* **Apps:** census 4's nine apps (Fizzy on SQLite and MySQL), set up fresh as corpus `censusf2` on the master pin
  with the [JIT parity](jit-parity-census.md) overlays (`fixtures/corpus/jit-parity-census`; CodeTriage, PingCRM,
  redprints-cfp and react-starter-kit with census 4's, since the parity CodeTriage patch no longer applies to the
  census source). `run`'s dependency control: every lock outside Rails matches in all runs.
* **Allocations:** `script/census run --modes interp,zjit`, warmup 200 operations (`CENSUS_WARMUP=200`, recorded per
  workload), ABBA (`zw`, `zwo`, `zwo2`, `zw2`):
  [`census_abba.sh`](../../bench/upstream/zjit_combined/census_abba.sh), table
  [`census_table.rb`](../../bench/upstream/zjit_combined/census_table.rb).
* **ZJIT stats:** separate processes, `--stats="--zjit-mem-size=128"` (`--zjit-stats-quiet`; `census_abba.sh` now
  defaults to `--zjit-exec-mem-size=512 --zjit-mem-size=1024`), 200 warmup and 20
  measured operations per workload, twice per tree (`zsw`, `zswo`, `zswo2`, `zsw2`). Tables:
  [`stats_compact.rb`](../../bench/upstream/zjit_combined/stats_compact.rb) and
  [`stats_table.rb`](../../bench/upstream/zjit_combined/stats_table.rb), which lists every fallback, exit and
  argument-passing counter the PRs raise by more than 2× its A/A, 5% and 0.05 per operation. Sites: one traced run per
  tree and app (`--zjit-trace-exits-sample-rate=20 --zjit-trace-fallbacks-sample-rate=20`), diffed with
  [`trace_diff.rb`](../../bench/upstream/zjit_combined/trace_diff.rb). Attribution: main with a single PR reverted,
  stats twice.
* **Callgrind:** ruby-bench railsbench and lobsters (byroot/ruby-bench `bf1afb2` with the
  [index_with patch](../../bench/upstream/index_with_ruby_bench/ruby-bench.patch); two checkouts differing only in
  the Rails path), `--zjit`, Valgrind 3.19.0 built by `script/bench-valgrind` (stock Valgrind hit `brk segment
  overflow`, which [bench.md](../bench.md) treats as invalid; no run reports it). Per process 15 warmup iterations,
  then an empty and a 3-iteration window with GC excluded
  ([`harness.rb`](../../bench/upstream/zjit_combined/harness.rb)); three rounds of with-A, without-A, without-B,
  with-B in rotated order, sequential ([`callgrind.sh`](../../bench/upstream/zjit_combined/callgrind.sh),
  [`callgrind_summary.rb`](../../bench/upstream/zjit_combined/callgrind_summary.rb)).
* **Warmup gate:** after 200 warmups, compiled ISEQs per operation are 0.00–0.35 in seven apps but 1.5 in Campfire
  and 2.1 in CodeTriage, the same in both trees and both runs (±0.04). Those two keep compiling new ISEQs in steady
  state (the gate fails there for both trees alike), so their counters include compilation; the A/A shows it does not
  differ between runs.
* **Code memory.** At the default limits, Fizzy and Fizzy-MySQL fill the 64 MiB executable region in every stats
  run: `compile_error_out_of_memory` 388–552 (Fizzy) and 298–453 (Fizzy-MySQL) per operation, unequal between runs
  of the same tree, so their counters at 128 MiB were not comparable. The other eight configurations report 0 in all
  runs and both single-revert trees, with Lobsters closest to the limit (63.2 MiB). Fizzy, Fizzy-MySQL and Lobsters
  were rerun in ABBA order at `--zjit-exec-mem-size=512 --zjit-mem-size=1024` (`zmw`, `zmwo`, `zmwo2`, `zmw2`), as F1
  does, with the #59541 and #59537 single-revert trees on both Fizzy configurations (`zm41`/`zm41b`,
  `zm37`/`zm37b`): 0 out-of-memory errors in every run; Fizzy's code region then grows to 80 MiB, Lobsters' stays
  at 63 MiB. The table below uses those reruns for the three apps. ruby-bench never comes close: under plain `--zjit`
  with the Callgrind harness's 15 + 3 iterations, the code region is 7.8 MiB (railsbench) and 28.4 MiB (lobsters) in
  both trees, and a `--zjit-stats` pass of the same reports 0 out-of-memory errors, so the Callgrind numbers stand.

### Allocations

Interpreter / ZJIT in every cell, as in [Allocations](#allocations).

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Workloads moved ≤ −1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1710 → 1671 / 1705 → 1668 | −38.4 / −37.2 | −2.24% / −2.18% | −0.14%, +1.00% / −0.02%, +0.13% | 10 (3) / 10 (1) |
| campfire | 9 | 6357 → 6240 / 6498 → 6382 | −116.8 / −116.1 | −1.84% / −1.79% | +0.00%, +0.00% / −0.00%, −0.01% | 9 (0) / 9 (0) |
| fizzy | 14 | 10517 → 10058 / 10532 → 10076 | −458.5 / −455.9 | −4.36% / −4.33% | +0.00%, +0.06% / +0.00%, −0.16% | 14 (2) / 14 (1) |
| fizzy-mysql | 14 | 10271 → 9819 / 10275 → 9839 | −451.2 / −436.5 | −4.39% / −4.25% | −0.00%, −0.10% / +0.00%, −0.10% | 14 (2) / 14 (2) |
| lobsters | 11 | 11534 → 11306 / 11518 → 11290 | −228.2 / −228.4 | −1.98% / −1.98% | −0.03%, +0.01% / −0.00%, −0.00% | 11 (4) / 11 (4) |
| react-starter-kit | 8 | 1950 → 1921 / 1951 → 1922 | −29.6 / −28.3 | −1.52% / −1.45% | +0.01%, +0.04% / −0.03%, +0.02% | 8 (2) / 8 (4) |
| redprints-cfp | 8 | 2089 → 2044 / 2091 → 2046 | −45.1 / −44.9 | −2.16% / −2.15% | +0.00%, −0.05% / −0.01%, −0.03% | 8 (3) / 8 (3) |
| writebook | 8 | 5464 → 5284 / 5536 → 5357 | −180.1 / −178.7 | −3.30% / −3.23% | +0.01%, −0.01% / +0.03%, +0.00% | 8 (1) / 8 (1) |
| codetriage | 7 | 2828 → 2731 / 2839 → 2742 | −96.6 / −96.1 | −3.42% / −3.39% | +0.04%, −0.03% / −0.06%, +0.04% | 7 (1) / 7 (5) |
| pingcrm | 8 | 2953 → 2881 / 2952 → 2881 | −72.1 / −70.9 | −2.44% / −2.40% | +0.01%, +0.20% / −0.01%, −0.10% | 8 (1) / 8 (2) |

| Scope | Workloads | Objects/workload without → with | Δ | Share | A/A with, without | Moved (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Census 4's nine apps (10 configurations) | 97 | 6,306 → 6,100 / 6,326 → 6,123 | −205.9 / −202.8 | **−3.27% / −3.21%** | −0.01%, +0.03% / −0.00%, −0.06% | 97 (19) / 97 (23) |

* **ZJIT keeps the saving.** Per app, ZJIT and the interpreter agree to within 0.15 points (Fizzy-MySQL −4.39% /
  −4.25%). No workload allocates more in either mode.
* **Larger than on 4.0.7** (−2.00% / −2.00% for these apps above): the tree now reverts 22 PRs instead of 11, and the
  master pin is a different Ruby. The two are not comparable as a Ruby 4.0.7 → master change.
* **A/A:** every app is within ±0.20%, except the Blog's reverted pair in the interpreter (+1.00%), which is one
  stateful job (`Turbo::Streams::ActionBroadcastJob`, 618 → 796 objects between runs).

### ZJIT counters

Per operation, mean of each tree's two runs; Δ against the reverted tree, A/A the larger of the two trees' run-to-run
changes, on the same scale. Fallbacks are send, invokeblock, getivar and setivar fallbacks; side exits exclude
compile-error exits (see the warmup gate). Fizzy, Fizzy-MySQL and Lobsters are the 1024 MiB reruns.

| App | Dynamic sends without → with (Δ; A/A) | Fallbacks without → with (Δ; A/A) | Side exits without → with (Δ; A/A) |
| --- | ---: | ---: | ---: |
| blog | 1723 → 1706 (−1.0%; ±1.2%) | 3195 → 3202 (+0.2%; ±1.4%) | 32.0 → 31.5 (−1.5%; ±0.3%) |
| campfire | 7827 → 7568 (−3.3%; ±0.0%) | 12544 → 12155 (−3.1%; ±0.0%) | 208 → 207 (−0.3%; ±0.3%) |
| codetriage | 3246 → 3177 (−2.1%; ±0.0%) | 4970 → 4820 (−3.0%; ±0.0%) | 130 → 130 (−0.0%; ±0.0%) |
| fizzy | 17630 → 16937 (−3.9%; ±0.1%) | 28175 → 27348 (−2.9%; ±0.1%) | 626 → 623 (−0.6%; ±0.2%) |
| fizzy-mysql | 16801 → 16278 (−3.1%; ±0.3%) | 26036 → 25513 (−2.0%; ±0.3%) | 612 → 615 (+0.4%; ±2.9%) |
| lobsters | 16385 → 15708 (−4.1%; ±0.0%) | 26583 → 25454 (−4.2%; ±0.1%) | 572 → 568 (−0.7%; ±0.0%) |
| pingcrm | 2376 → 2272 (−4.4%; ±0.0%) | 3190 → 3086 (−3.3%; ±0.0%) | 26.4 → 26.8 (+1.5%; ±0.2%) |
| react-starter-kit | 1028 → 997 (−2.9%; ±0.0%) | 1307 → 1277 (−2.3%; ±0.0%) | 23.8 → 23.8 (+0.0%; ±0.0%) |
| redprints-cfp | 1610 → 1527 (−5.2%; ±0.0%) | 2314 → 2224 (−3.9%; ±0.1%) | 40.3 → 40.3 (+0.0%; ±0.0%) |
| writebook | 25587 → 23117 (−9.7%; ±0.0%) | 44398 → 40369 (−9.1%; ±0.0%) | 1248 → 1285 (+2.9%; ±0.0%) |

**Counters raised by a PR.** `stats_table.rb` lists 17 (app, counter) pairs. Accepting only reasons that reach ≥ 3 apps
with stable runs leaves two, and both trace to single PRs, confirmed by trees that revert just that PR:

| Counter | Apps | PR | without → with | single revert | What changed |
| --- | --- | --- | --- | --- | --- |
| `send_fallback_sendforward_not_specialized` | Writebook, Fizzy, Fizzy-MySQL, Campfire, redprints-cfp, react-starter-kit | **#59541** | Writebook 768 → 920, Fizzy 705 → 779, Fizzy-MySQL 705 → 779, Campfire 284 → 307, redprints-cfp 113 → 119, rsk 56 → 60 | Writebook 768, Campfire 284, Fizzy 705, Fizzy-MySQL 705 (`42cb27e233`, twice) | `WhereClause#merge` now asks `empty?` first, and `WhereClause#empty?` is `delegate :empty?, to: :predicates`, a `(...)` forwarder ZJIT does not specialize. It replaces the getivar fallbacks of `except_predicates`/`each_attributes` it skips; Writebook's fallbacks still fall 9.1% overall. With #59541 alone reverted, Writebook's dynamic sends are 23,086 against 23,117 with it: +31 per operation (+0.13%); Fizzy +52 (+0.3%), Fizzy-MySQL +26 (+0.2%), Campfire −1. At 128 MiB the Fizzy rise was hidden by the full code region. |
| `complex_arg_pass_caller_splat` | Fizzy, Fizzy-MySQL, Writebook | **#59537** | Fizzy 19.4 → 23.5, Fizzy-MySQL 18.7 → 22.8, Writebook 15.5 → 16.4 | Fizzy 20.1, Fizzy-MySQL 19.4, Writebook 15.5 (`d58e0dddd4`, twice): #59537 is 3.4 of the Fizzy rise of 4.1 | `TagBuilder#method_missing` called `tag_string(name, *args, options, …)`, which compiles to `concatarray`, an instruction ZJIT side-exits on (`exit_unhandled_yarv_insn` 3.4 per operation in Fizzy). With `options, *args` it is an ordinary splat send that ZJIT compiles and counts as a fallback. `exit_unhandled_yarv_insn` drops to 0 in all five apps that had it; complex-argument fallbacks as a whole fall (Fizzy 851 → 841). |

Below the three-app bar:

* **Writebook `exit_guard_type_failure` 326 → 362, #59568.** With #59568 alone reverted (`7e6308f9cc`, twice) it is
  326.3 again. `_load_from_sql` now reads `self.attribute_types` once in the method body, where ZJIT guards the
  receiver's class and Writebook's many model classes fail the guard, instead of in the `reject` block, where the
  same call was a send fallback. The same PR removes 1,274 dynamic sends per operation in Writebook (24,391
  without it, 23,117 with). No other app's guard failures move (largest change −3.5, Lobsters).
* **`send_fallback_send_megamorphic`** rises in Lobsters (+75, A/A 0) and Fizzy (+241, inside twice its A/A of 126
  at 1024 MiB; the +305 at 128 MiB was measured with a full code region). It is a reclassification: `schema_context`
  and `Merger` sends that were polymorphic fallbacks now count as megamorphic. Polymorphic and megamorphic send
  fallbacks together fall in Fizzy (10,532 → 10,419), Lobsters (8,534 → 8,047), Writebook (15,192 → 13,917) and the
  other apps, except Fizzy-MySQL: 10,006 → 10,071 (+0.6%, A/A ±0.4%), while its total fallbacks fall 2.0%.
* **PingCRM `exit_unhandled_block_arg` 3.0 → 3.4** is a new site at `HashWithIndifferentAccess#fetch` <
  `ActionController::Parameters#fetch`, which #59535 rewrote (traced site only; no single-PR tree). The old
  `super(convert_key(key), *extras)` was a `super` complex-argument fallback; the new plain `super` side-exits
  when a block is passed. Elsewhere the same change removes those `super` fallbacks (Fizzy: 1,813 trace samples,
  none left).
* **The Blog's getivar/setivar fallbacks** (+15.6 and +4.9) are single-app, and its total fallbacks stay inside its
  A/A. Codetriage's `getivar_fallback_megamorphic` +0.1 and
  Campfire's `complex_arg_pass_caller_blockarg` +0.9 are below one per operation.

No PR raises a fallback or exit reason in ≥ 3 apps in a way that adds net work: in both cases the new counter replaces
an equal or larger one at the same call.

### Callgrind under ZJIT

| App | Rounds | Ir/iteration without → with | with / without: mean (range over rounds) | A/A with, without: mean (largest) | GC runs per 3-iteration window | Objects/iteration without → with |
| --- | ---: | ---: | --- | --- | --- | --- |
| railsbench | 3 | 2.969 G → 2.953 G | **−0.54%** (−0.62% … −0.41%) | −0.03% (−0.09%), −0.13% (−0.18%) | 12–14 in both trees | 959,488 → 943,430 (−1.67%) |
| lobsters | 3 | 3.053 G → 3.038 G | **−0.49%** (−0.51% … −0.46%) | +0.02% (+0.04%), −0.06% (−0.10%) | 1–2 in both trees | 549,267 → 539,681 (−1.75%) |

* **Outside the A/A.** Every round's with/without ratio is lower than −0.4%, and no A/A ratio of either tree
  exceeds 0.18% in any round. Ir excludes GC (`CG_NO_GC=1`), so this is mutator work: fewer allocations and fewer
  dynamic sends, not fewer collections.
* **CPU is an observation, not a speed claim.** Per [bench.md](../bench.md) the primary evidence is interpreter
  instruction counts with fixed heap; these are ZJIT instruction counts on two benchmarks, without a JIT-flat gate
  or wall time. They say the PRs do not cost ZJIT CPU on these benchmarks, and likely save about half a percent.
* **GC:** objects per iteration fall 1.7% in both benchmarks, but GC runs in the 3-iteration window do not change
  (railsbench 12–14, lobsters 1–2 in both trees).

Receipts: [`data/combined-effect/zjit.tar.xz`](data/combined-effect/zjit.tar.xz) holds the run JSONs, logs and
`meta.json` of every census label (`zw`, `zw2`, `zwo`, `zwo2`, the stats labels `zsw`, `zsw2`, `zswo`, `zswo2`, the
single-revert labels `zs1`/`zs1b` for #59541, `zs37`/`zs37b` for #59537 and `zs68`/`zs68b` for #59568, and the
1024 MiB reruns `zmw`, `zmw2`, `zmwo`, `zmwo2`, `zm41`, `zm41b`, `zm37`, `zm37b`), the summarized
fallback and exit traces per app and tree, the Callgrind logs and totals, and the ruby-bench code-memory check (`oomcheck.txt`).
