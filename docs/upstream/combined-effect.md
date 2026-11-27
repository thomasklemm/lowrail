# Combined effect of our merged Rails PRs

Lowrail bet R5. Each of our rails/rails PRs claimed allocation counts only, measured on its own. This page measures
all merged ones together, as one before/after: Rails main against the same commit with every one of them reverted.

**Latest: round 4 (2026-11-27, [below](#round-4-every-merged-pr-on-rails-main-2026-11-27)).** Rails main `088fc0cf61`
against the same commit with 78 of our 85 merged rails/rails PRs reverted: **−6.60% of census allocations
interpreted and −6.53% under YJIT** on Ruby 4.0.10 (105 workloads, eleven apps, A/A ≤ ±0.03%), −7.08% / −6.99%
interpreted / ZJIT on Ruby master (79 workloads, eight apps), ruby-bench −5.1% to −15.6% objects per iteration, and
−2.88% (railsbench), −9.52% (shipit) and −0.92% (lobsters) interpreted instructions per iteration (A/A ≤ 0.10%). Our
merged ruby/ruby commits, reverted as a separate axis, leave interpreted census allocations flat and save 0.12% under
ZJIT. Round 3 (2026-11-17, 56 PRs, Ruby 4.0.9) measured −5.48% / −5.38%. Round 1 (bet R5) and bet F2 follow first;
round 2 is [merged-sum](merged-sum.md).

**Round 1.** Measured together on Rails main `5810776eec` against the same commit with all eleven merged PRs
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

## Round 3: every merged PR on Rails main (2026-11-17)

**Result.** Rails main `4500a94c34` against the same commit with 56 of our 61 merged rails/rails PRs reverted, on
Ruby 4.0.9: the census apps allocate **5.48% fewer objects per workload in the interpreter and 5.38% under YJIT**
(104 request, job and mailer workloads in eleven apps; each tree's A/A within ±0.04% overall). Every workload falls
by at least one object in the interpreter, and all but one under YJIT; none rises in the interpreter. Per app the
saving runs from 2.5% (Campfire) to 8.3% (CASA). ruby-bench iterations allocate **6.2% (railsbench), 4.2% (lobsters)
and 12.5–12.7% (shipit) fewer objects** (A/A ≤ 0.01%). Interpreted instructions per iteration, fixed heap, fall **2.24%
on railsbench and 3.43% on shipit** (A/A ≤ 0.04%); lobsters moves by −0.11% and is not claimed. No YJIT instruction
row passes the JIT-flat gate. On Ruby master the same Rails trees save **5.86% interpreted and 5.79% under ZJIT** in the eight apps
that install there (78 workloads, A/A ≤ ±0.05%), and reverting our 14 merged ruby/ruby commits instead leaves
census allocations flat (+0.02% / −0.04%, inside the A/A) while ZJIT ruby-bench allocates 0.12% (lobsters) and 0.30%
(shipit) fewer objects with them. These are allocation and instruction counts, not a measured speedup.

### Pins

* **Rails, with:** canonical `rails/rails` main
  [`4500a94c34`](https://github.com/rails/rails/commit/4500a94c34d7052b84f81f6d7fd44f5bb8af3fff) (#59845,
  2026-11-17 20:48 UTC), 8.2.0.alpha.
* **Rails, without:** the same commit with 56 reverts, local commit `bb283c942f` (not pushed), reproducible from
  [`reverted.tsv`](../../bench/upstream/combined_r3/reverted.tsv) and the
  [README](../../bench/upstream/combined_r3/README.md). 46 files change under `*/lib/*` (+123/−266).
* **Ruby 4.0.9** (`3e93b23afc`), interpreter and `--yjit`, production environment.
* **Ruby master** [`7919a47d46`](https://github.com/ruby/ruby/commit/7919a47d467ba961b8912fa61e0ee1fe0ff4ef0c)
  (2026-11-17 22:17 UTC) and the same commit with our ruby/ruby commits reverted, `854f34bbac` (local), both
  `--enable-yjit --enable-zjit`, Rust 1.100.0, ZJIT defaults.
* **ruby-bench** `8083f57` with [`ruby-bench.patch`](../../bench/upstream/combined_r3/ruby-bench.patch).
* **Orb:** 2 CPUs, 4 GB, no swap, so census runs used `--jobs 2`.

### Which PRs

The list is every rails/rails PR by `thomasklemm` that GitHub reports merged
(`gh search prs --author thomasklemm --repo rails/rails --merged`, 63 on 2026-11-17), each checked with `gh pr view
--json mergeCommit,mergedAt` and found in main's first-parent history. The ledger's Merged section lists the same PRs
(plus #59713 and #59714, which are byroot's follow-ups, not ours). Two are left out before reverting: #7260 (2012
docs) and #59584, which byroot already reverted on main in #59713.

**Reverted (56):** #59235, #59244, #59252, #59270, #59274, #59278, #59316, #59329, #59533–#59539, #59541–#59544,
#59551–#59554, #59556, #59558, #59560–#59563, #59570, #59571, #59576, #59583, #59585, #59596–#59598, #59603,
#59605–#59608, #59613–#59616, #59618–#59620, #59624–#59626, #59629, #59642, #59676, #59809. Most are performance
changes; the tree also reverts the merged correctness and test fixes that revert cleanly (#59606, #59624–#59626,
#59629, #59676, #59809), because the question is what our merged work does together.

**Reverts that did not apply cleanly, and how they were resolved.** The first pass reverted newest first in main's
first-parent order and aborted every revert that conflicted (13). For those, test and CHANGELOG conflicts keep main's
file; library conflicts were resolved by hand only where the PR's own lines are still on main:

| PR | Conflict | Resolution |
| --- | --- | --- |
| #59642 | `query_methods.rb`: 518784d2e3 changed the same line to `opts.to_s` | the pre-PR `"(#{opts})"` line; CHANGELOG and test keep main |
| #59576, #59533 | `where_clause.rb`, behind #59642 | clean once #59642 is reverted |
| #59556 | `merger.rb`: kamipo's #59572 self-merge check reads `values_for_merge` | `Merger#initialize` reads `other.values` again; the self-merge check compares `other.values_for_merge`, so `values_for_merge` stays |
| #59551 | `merger.rb`: a later `with_values` line next to it | `extending!` unconditional again; the later line stays |
| #59554 | `merger.rb`: later unscope qualification and self-merge check | `NORMAL_VALUES.each` with `:"#{name}!"` again; the later lines stay |
| #59543 | `spawn_methods.rb`: later `with_recursive` lines | `except`/`only` read `values` (the copy) again; the later lines stay |
| #59316 | `url_for_test.rb` only | lib reverts cleanly; the test keeps main |

**Not reverted (5)**, so their effect, if any, is in both trees:

* #59236 (CurrentAttributes defaults) and #59568 (`attribute_types` once): their code is no longer on main.
  kamipo's 84048ad477 rewrote `resolve_defaults`, and tenderlove's #59141 rewrote `_load_from_sql`.
* #59555, #59634 and #59640 (correctness fixes): later commits rewrote their lines (f9fe866f49 in `enumerable.rb`,
  kamipo's `_where!` work in four Active Record files, byroot's #59714 in `local_cache.rb`), and reverting them
  would mean rewriting someone else's code.

**SQL control.** The masked SQL digest differs between the trees on 2 of 104 workloads, both in Lobsters (`POST
story vote toggle`, `POST comment (XHR)`), against 0 in either A/A pair. Dumping the statements shows why: with
#59642 reverted, a bound SQL literal inside an `or` is wrapped once more, `("story"."merged_story_id" = ? OR
("story"."id" = ?))` against main's `... OR "story"."id" = ?)`. That is #59642's intended change (it fixed the extra
parentheses from #58427). Query counts per operation are the same in both trees (19.5 and 57.0). No other workload
changes its SQL.

### Apps

The eleven census apps that set up on Rails main here: blog, Campfire, Writebook, Fizzy, Lobsters, redprints-cfp,
react-starter-kit, CodeTriage, PingCRM, CASA and Hackatime (SQLite and PostgreSQL). `script/census setup --rails
…@4500a94c34` used the default overlays. Fizzy and Lobsters failed `prepare` on current main, as
[ruby-master-round-2](ruby-master-round-2.md#6-railsrails59141-shared-attribute-readers-under-yjit-and-zjit)
recorded: Fizzy's `uuid_primary_keys.rb` recurses in `primary_key`, and activerecord-typedstore 1.6.0 raises "has no
attribute `prefers_color_scheme` to define a reader for" since d74214f745 (#59141). Both were set up again with the
census-4 overlay plus CE2's local workarounds (`fixtures/corpus/ce2/fizzy.patch`, `lobsters.patch`), the same in both
trees. MySQL and the larger PostgreSQL apps (Mastodon, Discourse, Docuseal, Lago, Loomio, Sure, Chatwoot) were not set
up on this orb. `run`'s dependency control reported no lock difference outside Rails for any app.

### Census allocations (Ruby 4.0.9)

[`run_409.sh`](../../bench/upstream/combined_r3/run_409.sh): `script/census run --modes interp,yjit --jobs 2` in ABBA
order `r3w`, `r3wo`, `r3wo2`, `r3w2`, 23:03–23:27 UTC. Table:
`ruby bench/upstream/combined_r3/census_table.rb .lowrail/private/census interpreter,yjit r3w r3w2 r3wo r3wo2`.
Interpreter / YJIT in every cell; the A/A counts in brackets are `r3w2` against `r3w`.

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1769 → 1688 / 1759 → 1708 | −81.4 / −50.5 | −4.60% / −2.87% | −0.50%, −0.40% / +0.12%, +0.80% | 10 (3) / 9 (2) | 0 (2) / 1 (2) |
| campfire | 9 | 6432 → 6273 / 6459 → 6299 | −159.6 / −159.7 | −2.48% / −2.47% | −0.00%, +0.00% / +0.00%, −0.00% | 9 (0) / 9 (0) | 0 (0) / 0 (1) |
| casa | 10 | 13318 → 12207 / 13433 → 12322 | −1111.1 / −1111.7 | −8.34% / −8.28% | +0.00%, −0.01% / −0.00%, −0.00% | 10 (3) / 10 (4) | 0 (4) / 0 (2) |
| codetriage | 7 | 2850 → 2692 / 2866 → 2709 | −158.5 / −157.2 | −5.56% / −5.49% | +0.01%, +0.05% / +0.02%, +0.08% | 7 (2) / 7 (1) | 0 (2) / 0 (3) |
| fizzy | 14 | 10636 → 9957 / 10718 → 10043 | −678.7 / −675.0 | −6.38% / −6.30% | −0.01%, +0.05% / +0.17%, −0.15% | 14 (2) / 14 (1) | 0 (0) / 0 (3) |
| hackatime | 11 | 7522 → 7138 / 7538 → 7154 | −383.4 / −383.5 | −5.10% / −5.09% | −0.02%, −0.01% / +0.00%, −0.00% | 11 (7) / 11 (3) | 0 (1) / 0 (4) |
| lobsters | 11 | 11568 → 11085 / 11601 → 11125 | −483.0 / −476.5 | −4.18% / −4.11% | +0.18%, +0.08% / −0.03%, −0.01% | 11 (1) / 11 (7) | 0 (7) / 0 (2) |
| pingcrm | 8 | 2909 → 2797 / 2917 → 2806 | −111.8 / −111.0 | −3.84% / −3.81% | −0.04%, −0.05% / +0.01%, +0.04% | 8 (5) / 8 (3) | 0 (1) / 0 (3) |
| react-starter-kit | 8 | 1993 → 1938 / 1996 → 1941 | −55.6 / −54.9 | −2.79% / −2.75% | +0.03%, −0.04% / +0.07%, −0.00% | 8 (2) / 8 (2) | 0 (2) / 0 (4) |
| redprints-cfp | 8 | 2161 → 2086 / 2169 → 2094 | −75.2 / −75.1 | −3.48% / −3.46% | −0.07%, −0.01% / −0.01%, +0.04% | 8 (4) / 8 (2) | 0 (1) / 0 (1) |
| writebook | 8 | 5518 → 5237 / 5550 → 5269 | −281.6 / −281.1 | −5.10% / −5.06% | +0.01%, +0.02% / +0.00%, +0.02% | 8 (0) / 8 (3) | 0 (3) / 0 (4) |
| **All 11 apps** | 104 | 6618 → 6255 / 6651 → 6293 | −362.5 / −358.1 | −5.48% / −5.38% | +0.02%, +0.01% / +0.04%, −0.01% | 104 (29) / 103 (28) | 0 (23) / 1 (29) |

* **Every app moves, in both modes.** Each app's A/A is within ±0.18%, except the Blog's (up to 0.80%, from its write
  workloads), which is still several times smaller than its effect (−4.60% / −2.87%).
* **One workload rises under YJIT**, in the Blog (it also moves in its own A/A); none rises in the interpreter.
  `script/census compare --base r3wo --aa r3w r3w r3w2 r3wo2`: 104 / 103 workloads fall by at least one object in
  both `with` runs; the reverted tree's own A/A moves 33 / 30 down and 26 / 29 up.
* **Larger than round 2** (−3.78% on five apps, 39 PRs): 17 more PRs are reverted, the five apps that both rounds share
  save more here (Fizzy −6.4% against −5.1%, Writebook −5.1% against −4.2%), and CASA (−8.3%) and Hackatime (−5.1%) are
  new. The two rounds are not one pin, so this is no Rails-version trend.

### ruby-bench (Ruby 4.0.9)

Fixed heap (`RUBY_GC_HEAP_0..4_INIT_SLOTS` 1,000,000 / 250,000 / 100,000 / 20,000 / 10,000). Objects per iteration:
[`sumalloc.rb`](../../bench/upstream/merged_sum/sumalloc.rb), 5 warmup + 10 measured iterations, processes in the
order main-a, without-a, without-b, main-b; table by
[`alloc_table.rb`](../../bench/upstream/merged_sum/alloc_table.rb).

| Benchmark | Mode | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 983,931 → 922,444 | **−6.25%** | +0.00%, +0.00% | 1.30 → 1.20 |
| railsbench | YJIT | 989,269 → 927,782 | **−6.22%** | +0.00%, +0.00% | 1.30 → 1.20 |
| lobsters | interpreter | 541,211 → 518,469 | **−4.20%** | −0.00%, −0.00% | 0.60 → 0.60 |
| lobsters | YJIT | 544,673 → 521,933 | **−4.17%** | +0.01%, +0.01% | 0.60 → 0.60 |
| shipit | interpreter | 981,026 → 856,374 | **−12.71%** | −0.00%, −0.00% | 1.60 → 1.40 |
| shipit | YJIT | 994,230 → 869,556 | **−12.54%** | −0.00%, +0.00% | 1.60 → 1.40 |

No major GC in any measured iteration. Instructions per iteration:
[`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb) (Valgrind 3.19.0 from
`script/bench-valgrind`; a 4-iteration run minus a 1-iteration run, 2 warmups), variants main-a, main-b, without-a.

| Benchmark | Mode | with vs without | A/A (main-b vs main-a) | Claimed |
| --- | --- | ---: | ---: | --- |
| railsbench | interpreter | **−2.24%** | −0.02% | yes |
| shipit | interpreter | **−3.43%** | −0.03% | yes |
| lobsters | interpreter | −0.11% | −0.04% | no: below 3× its A/A |
| railsbench | YJIT | −3.05% | +0.41% | no: not JIT-flat |
| shipit | YJIT | −1.71% | +0.35% | no: not JIT-flat |
| lobsters | YJIT | +0.78% | +0.38% | no: not JIT-flat |

`summary` reports the reverted tree against main-a; the table inverts it (with / without − 1). Under YJIT every
benchmark compiles new blocks in the measured window (main-a: railsbench +184, lobsters +3,187, shipit +4,184 blocks), so
by [bench.md](../bench.md) no YJIT row counts. Lobsters allocates 4.2% fewer objects, but its instructions do not
move beyond noise.

**Wall time** was not measured in this round: rounds 1 and 2 found it unresolvable at this effect size on a quiet
8-CPU orb, and this orb has 2 CPUs shared with the build and census jobs.

### Ruby master and ZJIT

[`run_master.sh`](../../bench/upstream/combined_r3/run_master.sh), `--modes interp,zjit`, 200 warmup operations
(`CENSUS_WARMUP=200`, as in bet F2), 00:55–01:44 UTC. Two axes, each with its own A/A:

* **Rails axis:** Ruby master `7919a47d46`, Rails main against the reverted Rails tree, ABBA `r3zw`, `r3zwo`,
  `r3zwo2`, `r3zw2`.
* **Ruby axis:** Rails main, Ruby master against master with our 14 merged ruby/ruby commits reverted (`854f34bbac`),
  `r3zw2`, `r3rwo`, `r3rwo2`, `r3zw3`.

**Our merged ruby/ruby PRs** (`gh search prs --author thomasklemm --repo ruby/ruby --merged`, 13 on 2026-11-17):
#19484, #19485, #19538, #19554, #19586, #19648, #19660, #19678, #19682, #19699, #19909 land on master as 12 commits
(#19586 as two), plus two of our ruby/date changes synced into master (ruby/date#199 and `Date#step`'s incomparable limit); #19619 and
#19620 are backports to `ruby_4_0` and `ruby_3_4` and are not on master. All 14 commits were reverted newest first;
only #19484's revert conflicts, in the test file `zjit/src/hir/opt_tests.rs` (master's version kept).

**Apps.** Eight of the eleven install on master: Writebook (redcarpet 3.6.0), Lobsters (commonmarker's rb-sys) and
CodeTriage (bluecloth 2.2.0) fail to compile their C extensions against Ruby 4.1's removed APIs, as census 8 and
[Ruby master round 3](ruby-master-round-3.md) recorded. 78 workloads.

**Rails axis, census** (interpreter / ZJIT; `census_table.rb … interpreter,zjit r3zw r3zw2 r3zwo r3zwo2`):

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1705 → 1641 / 1698 → 1643 | −63.4 / −55.5 | −3.72% / −3.27% | +0.17%, +0.06% / +0.54%, +0.01% | 10 (1) / 10 (2) | 0 (2) / 0 (2) |
| campfire | 9 | 6377 → 6217 / 6531 → 6373 | −159.7 / −158.7 | −2.50% / −2.43% | −0.00%, +0.00% / +0.00%, −0.00% | 9 (0) / 9 (0) | 0 (0) / 0 (0) |
| casa | 10 | 13150 → 12038 / 13195 → 12086 | −1111.4 / −1108.3 | −8.45% / −8.40% | −0.01%, +0.01% / +0.00%, −0.00% | 10 (4) / 10 (2) | 0 (3) / 0 (2) |
| fizzy | 14 | 10447 → 9779 / 10466 → 9804 | −668.3 / −662.1 | −6.40% / −6.33% | −0.12%, −0.06% / +0.06%, +0.17% | 14 (4) / 14 (1) | 0 (1) / 0 (2) |
| hackatime | 11 | 7420 → 7038 / 7434 → 7052 | −381.9 / −381.7 | −5.15% / −5.13% | −0.00%, −0.01% / −0.02%, −0.02% | 11 (4) / 11 (6) | 0 (3) / 0 (2) |
| pingcrm | 8 | 2866 → 2755 / 2865 → 2755 | −111.0 / −109.5 | −3.87% / −3.82% | +0.07%, +0.02% / −0.12%, −0.01% | 8 (1) / 8 (6) | 0 (5) / 0 (0) |
| react-starter-kit | 8 | 1942 → 1887 / 1943 → 1890 | −54.4 / −52.8 | −2.80% / −2.72% | −0.06%, +0.08% / +0.06%, −0.02% | 8 (3) / 8 (1) | 0 (2) / 0 (4) |
| redprints-cfp | 8 | 2095 → 2020 / 2097 → 2023 | −75.3 / −74.7 | −3.59% / −3.56% | +0.01%, +0.01% / −0.01%, +0.11% | 8 (2) / 8 (2) | 0 (3) / 0 (2) |
| **All 8 apps** | 78 | 6270 → 5902 / 6298 → 5934 | −367.5 / −364.5 | −5.86% / −5.79% | −0.03%, −0.01% / +0.03%, +0.05% | 78 (19) / 78 (20) | 0 (19) / 0 (14) |

Every workload falls by at least one object in both modes, none rises (`script/census compare --base r3zwo --aa r3zw`:
78 / 78 for both `with` runs; the reverted tree's A/A moves 17 / 15 down and 22 / 20 up), and SQL digests change on
none. ZJIT keeps the interpreter's saving to within 0.45 points per app (the Blog: −3.72% / −3.27%).

**Ruby axis, census** (`census_table.rb … interpreter,zjit r3zw2 r3zw3 r3rwo r3rwo2`):

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1643 → 1642 / 1644 → 1648 | −1.6 / +4.0 | −0.10% / +0.24% | −0.12%, −0.18% / +0.10%, +0.65% | 4 (3) / 4 (1) | 0 (0) / 1 (2) |
| campfire | 9 | 6217 → 6217 / 6373 → 6373 | −0.1 / −0.2 | −0.00% / −0.00% | +0.00%, +0.00% / −0.00%, −0.00% | 0 (0) / 2 (0) | 0 (0) / 0 (0) |
| casa | 10 | 12038 → 12038 / 12110 → 12086 | −0.7 / −23.5 | −0.01% / −0.19% | −0.01%, −0.00% / −0.01%, −0.00% | 6 (4) / 7 (5) | 2 (1) / 1 (5) |
| fizzy | 14 | 9768 → 9773 / 9804 → 9807 | +5.7 / +3.2 | +0.06% / +0.03% | +0.00%, +0.00% / +0.01%, −0.06% | 1 (1) / 8 (1) | 2 (3) / 4 (2) |
| hackatime | 11 | 7038 → 7039 / 7054 → 7052 | +0.2 / −2.7 | +0.00% / −0.04% | +0.00%, −0.01% / +0.00%, +0.01% | 3 (3) / 8 (4) | 3 (4) / 0 (4) |
| pingcrm | 8 | 2752 → 2755 / 2756 → 2756 | +2.8 / −0.3 | +0.10% / −0.01% | −0.07%, −0.17% / +0.15%, +0.16% | 0 (5) / 4 (0) | 8 (1) / 2 (8) |
| react-starter-kit | 8 | 1888 → 1887 / 1890 → 1890 | −0.4 / +0.5 | −0.02% / +0.03% | +0.06%, +0.06% / −0.05%, +0.03% | 2 (1) / 2 (3) | 1 (4) / 4 (3) |
| redprints-cfp | 8 | 2020 → 2020 / 2023 → 2023 | +0.4 / −0.2 | +0.02% / −0.01% | +0.03%, −0.04% / +0.03%, +0.07% | 1 (2) / 3 (2) | 2 (3) / 1 (2) |
| **All 8 apps** | 78 | 5900 → 5901 / 5937 → 5935 | +1.0 / −2.3 | +0.02% / −0.04% | −0.01%, −0.02% / +0.01%, +0.02% | 17 (19) / 38 (16) | 18 (16) / 13 (26) |

**Flat, as expected.** Our ruby/ruby PRs are JIT correctness fixes and ZJIT specializations; they do not change what
the interpreter allocates, and only #19678 (interpolating Integers and Modules without `to_s`) can save objects under
ZJIT. The totals (+0.02% / −0.04%) are inside the A/A. Under ZJIT 38 workloads fall by at least one object against 16
in the A/A, and CASA's −0.19% is the only per-app move outside its A/A (±0.01%).

**ruby-bench objects per iteration under ZJIT** (fixed heap; [`zjit_alloc_table.rb`](../../bench/upstream/combined_r3/zjit_alloc_table.rb)):

| Axis | Benchmark | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |
| --- | --- | ---: | ---: | ---: | ---: |
| Rails | railsbench | 964,946 → 903,458 | −6.37% | +0.00%, −0.00% | 5.00 → 4.55 |
| Rails | lobsters | 533,121 → 510,378 | −4.27% | +0.01%, −0.00% | 0.65 → 0.55 |
| Rails | shipit | 955,856 → 831,187 | −13.04% | +0.00%, +0.00% | 5.25 → 4.20 |
| Ruby | railsbench | 903,458 → 903,458 | −0.00% | −0.00%, +0.00% | 5.00 → 4.45 |
| Ruby | lobsters | 511,015 → 510,389 | −0.12% | −0.00%, +0.01% | 0.50 → 0.55 |
| Ruby | shipit | 833,687 → 831,184 | −0.30% | −0.00%, −0.00% | 4.10 → 4.30 |

On the Ruby axis, lobsters and shipit allocate 626 and 2,503 fewer objects per iteration with our commits, with an
A/A ≤ 0.01%. The [ledger](contributions.md)'s #19678 entry records 645 and 2,474 fewer ZJIT-only objects per iteration on the same
two benchmarks, so that saving is still there. railsbench does not move.
GC runs per iteration vary between processes of the same tree here (railsbench 4.45–5.00), so no GC claim is made.

**Instructions per iteration under ZJIT** (`ruby_bench_ir.rb … --modes zjit`, the same 4-minus-1-iteration
difference with 2 warmups; tags `zm` for Ruby master, `zr` for master with our commits reverted):

| Axis | Benchmark | with vs without | A/A (main-b vs main-a) |
| --- | --- | ---: | ---: |
| Rails | railsbench | −4.78% | −1.53% |
| Rails | lobsters | −1.96% | −0.42% |
| Rails | shipit | −5.24% | +1.29% |
| Ruby | railsbench | −3.5% | −1.53% |
| Ruby | lobsters | −1.0% | −0.42% |
| Ruby | shipit | +0.2% | +1.29% |

(Rails axis: `summary` against main-a, inverted. Ruby axis: the mean of `zm` main-a and main-b against `zr` main-a,
one sample.) **Observed, not claimed.** With 2 warmups ZJIT is still compiling in the measured window, the A/A
reaches 1.5%, and the harness has no ZJIT flat check. The Rails-axis rows sit 3–5× outside their A/A and point the
same way as bet F2's −0.5% (15 warmups, A/A ≤ 0.18%), but a ZJIT instruction claim needs F2's longer harness.


Receipts: [`data/combined-effect/r3.tar.xz`](data/combined-effect/r3.tar.xz) holds every census run JSON, log and
`meta.json` (`r3w`, `r3w2`, `r3wo`, `r3wo2`, `r3zw`, `r3zw2`, `r3zw3`, `r3zwo`, `r3zwo2`, `r3rwo`, `r3rwo2`), the ruby-bench allocation JSONs and logs, the Valgrind
logs and `.ir`/`.jit` files, the revert log and the Lobsters SQL dumps.

## Round 4: every merged PR on Rails main (2026-11-27)

**Result.** Rails main `088fc0cf61` against the same commit with 78 of our 85 merged rails/rails PRs reverted, on
Ruby 4.0.10: the census apps allocate **6.60% fewer objects per workload in the interpreter and 6.53% under YJIT**
(105 request, job and mailer workloads in eleven apps; each tree's A/A within ±0.03% overall). Every workload falls
by at least one object in both modes, and none rises. Per app the saving runs from 3.1% (Campfire) to 10.3% (CASA).
ruby-bench iterations allocate **6.2% (railsbench), 5.1% (lobsters) and 15.4–15.6% (shipit) fewer objects** (A/A ≤
0.01%). Interpreted instructions per iteration, fixed heap, fall **2.88% on railsbench, 9.52% on shipit and 0.92% on
lobsters** (A/A ≤ 0.10%); no YJIT instruction row passes the JIT-flat gate. On Ruby master the same Rails trees save **7.08% interpreted and 6.99% under ZJIT** in the eight apps that install there (79 workloads, A/A ≤ ±0.04%); reverting our 17 merged ruby/ruby commits instead moves census allocations by −0.03% / −0.12% (interpreter / ZJIT). These are allocation and
instruction counts, not a measured speedup.

**What changed from round 3** (−5.48% / −5.38%, 56 PRs on `4500a94c34`, Ruby 4.0.9): 22 more PRs are reverted, Rails
main is ten days newer, and the Ruby pin is 4.0.10, so the two rounds are not one comparison. Every app saves more
(Fizzy −8.3% against −6.4%, CASA −10.3% against −8.3%, Writebook −6.4% against −5.1%), shipit's objects per
iteration fall 15.6% against 12.7% and its instructions 9.5% against 3.4%, and lobsters' instructions now move beyond
3× their A/A. railsbench allocates exactly as many objects per iteration in both trees as in round 3 (983,931 →
922,444), so none of the new PRs reaches its path.

### Pins

* **Rails, with:** canonical `rails/rails` main
  [`088fc0cf61`](https://github.com/rails/rails/commit/088fc0cf61e4ba0c7987decafacc69adb3e22eec) (#59999,
  2026-11-27 09:05 UTC), 8.2.0.alpha.
* **Rails, without:** the same commit with 78 reverts, local commit `20c835cf15` (not pushed), reproducible from
  [`reverted.tsv`](../../bench/upstream/combined_r4/reverted.tsv) and the
  [README](../../bench/upstream/combined_r4/README.md). 64 files change under `*/lib/*` (+175/−368).
* **Ruby 4.0.10** (`a704b7cd95`, mise's precompiled YJIT build, like 4.0.9 in round 3), interpreter and `--yjit`,
  production environment; a new A/A per [DECISIONS](../DECISIONS.md#evidence-and-measurement).
* **Ruby master** [`e8167b0ddd`](https://github.com/ruby/ruby/commit/e8167b0dddfe2f1f8a1459d5a5e7f60d92a4b437)
  (2026-11-25, this week's census pin) and the same commit with our ruby/ruby commits reverted, `4e222eb280` (local),
  both `--enable-yjit --enable-zjit`, Rust 1.100.0, ZJIT defaults.
* **ruby-bench** `8083f57` with round 3's [`ruby-bench.patch`](../../bench/upstream/combined_r3/ruby-bench.patch)
  (Rails paths rewritten).
* **Orb:** 2 CPUs, 4 GB, no swap; census runs used `--jobs 2`.

### Which PRs

`gh search prs --author thomasklemm --repo rails/rails --merged` finds 85 on 2026-11-27: #7260 (2012 docs) and 84
created since 2026-10-19, each checked with `gh pr view --json mergeCommit` and found in main's first-parent history.
22 merged since round 3's pin, 21 of them on 2026-11-26: #59574, #59983, #59627, #59611, #59735, #59800, #59984,
#59985, #59812, #59817, #59804, #59987, #59569, #59661, #59824, #59986, #59832, #59976, #59851, #59810, #59668,
#59617. Several are docs, upgrade-guide notes or correctness fixes; like round 3, the tree reverts every merged PR
that reverts, because the question is what our merged work does together.

**Reverted (78):** round 3's 56 and the 22 above. The first pass reverted newest first in main's first-parent order
and aborted every conflict (15). Test and CHANGELOG conflicts keep main's file; library conflicts were resolved by
hand only where the PR's own lines are still on main, with round 3's resolutions where round 3 had the same conflict
(the reverted `merger.rb` is byte-identical to round 3's):

| PR | Conflict | Resolution |
| --- | --- | --- |
| #59574 | `activerecord/CHANGELOG.md` only | CHANGELOG keeps main |
| #59642 | `query_methods.rb`: 518784d2e3's `opts.to_s` | the pre-PR `"(#{opts})"` line; CHANGELOG and test keep main (as round 3) |
| #59576, #59533 | `where_clause.rb`, behind #59642 | clean once #59642 is reverted |
| #59556, #59551, #59554 | `merger.rb` | as round 3 |
| #59543 | `spawn_methods.rb` | as round 3 |
| #59603 | `tag_helper.rb`: Alexander Senko's 43f969a353 added `Set` to the next `when` | the `String` branch goes; `when Array, Hash, Set` stays |
| #59316 | `url_for_test.rb` only | lib reverts cleanly; the test keeps main |

**Not reverted (5 + 2)**, the same as round 3, so their effect, if any, is in both trees: #59236 and #59568 (their
code is no longer on main), #59555, #59634 and #59640 (correctness fixes whose lines others rewrote later), #59584
(already reverted on main by #59713) and #7260. None of the 22 new PRs conflicts beyond the CHANGELOG.

**SQL control.** The masked SQL digest differs between the trees on 2 of 105 workloads, the same two Lobsters
workloads as in round 3 (#59642's intended parentheses), against 0 in either A/A pair.

### Apps

Round 3's eleven apps, set up fresh on `088fc0cf61` and Ruby 4.0.10 with round 3's overlays (Fizzy and Lobsters with
the census-4 overlay plus CE2's local workarounds). Hackatime's workload file now has 12 workloads instead of 11, so
the total is 105. No census app was added since round 3: the apps the [boot check](rails-main-boot-2026-11-27.md)
runs beyond these eleven (MySQL, and the larger PostgreSQL apps Mastodon, Discourse, Docuseal, Lago, Loomio, Sure,
Chatwoot, Flow, Thinkroom) were already in the census and, as in round 3, were not set up on this orb. `run`'s
dependency control reported no lock difference outside Rails.

### Census allocations (Ruby 4.0.10)

[`run_4010.sh`](../../bench/upstream/combined_r4/run_4010.sh): ABBA order `r4w`, `r4wo`, `r4wo2`, `r4w2`,
13:24–13:47 UTC. Table: `ruby bench/upstream/combined_r3/census_table.rb .lowrail/private/census interpreter,yjit
r4w r4w2 r4wo r4wo2`. Interpreter / YJIT in every cell; the A/A counts in brackets are `r4w2` against `r4w`.

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1757 → 1666 / 1757 → 1676 | −91.0 / −80.8 | −5.18% / −4.60% | +0.47%, −0.52% / −0.77%, −0.71% | 10 (1) / 10 (2) | 0 (3) / 0 (2) |
| campfire | 9 | 6454 → 6257 / 6481 → 6283 | −197.3 / −197.4 | −3.06% / −3.05% | −0.01%, −0.01% / −0.01%, −0.00% | 9 (1) / 9 (0) | 0 (0) / 0 (0) |
| casa | 10 | 13464 → 12080 / 13583 → 12200 | −1383.2 / −1382.5 | −10.27% / −10.18% | +0.00%, −0.01% / −0.01%, +0.00% | 10 (4) / 10 (3) | 0 (5) / 0 (2) |
| codetriage | 7 | 2842 → 2645 / 2859 → 2661 | −197.1 / −198.6 | −6.94% / −6.94% | −0.01%, +0.19% / +0.01%, +0.08% | 7 (3) / 7 (3) | 0 (3) / 0 (3) |
| fizzy | 14 | 10640 → 9758 / 10710 → 9837 | −882.2 / −873.5 | −8.29% / −8.16% | −0.00%, −0.11% / +0.06%, +0.00% | 14 (1) / 14 (1) | 0 (0) / 0 (1) |
| hackatime | 12 | 7960 → 7545 / 7987 → 7572 | −414.9 / −414.3 | −5.21% / −5.19% | −0.00%, −0.01% / +0.01%, +0.01% | 12 (6) / 12 (3) | 0 (3) / 0 (7) |
| lobsters | 11 | 11557 → 11007 / 11574 → 11024 | −550.5 / −549.8 | −4.76% / −4.75% | −0.00%, +0.00% / −0.02%, +0.00% | 11 (3) / 11 (5) | 0 (3) / 0 (2) |
| pingcrm | 8 | 2905 → 2780 / 2914 → 2789 | −124.9 / −125.3 | −4.30% / −4.30% | −0.04%, −0.02% / +0.02%, −0.00% | 8 (3) / 8 (2) | 0 (0) / 0 (3) |
| react-starter-kit | 8 | 1989 → 1924 / 1994 → 1928 | −65.1 / −66.0 | −3.27% / −3.31% | −0.03%, −0.00% / +0.03%, −0.09% | 8 (3) / 8 (2) | 0 (2) / 0 (4) |
| redprints-cfp | 8 | 2159 → 2070 / 2167 → 2078 | −88.5 / −89.1 | −4.10% / −4.11% | −0.05%, +0.05% / −0.01%, +0.04% | 8 (3) / 8 (3) | 0 (4) / 0 (2) |
| writebook | 8 | 5524 → 5171 / 5556 → 5203 | −352.5 / −353.0 | −6.38% / −6.35% | +0.01%, −0.01% / −0.04%, −0.01% | 8 (2) / 8 (6) | 0 (2) / 0 (0) |
| **All 11 apps** | 105 | 6690 → 6248 / 6723 → 6283 | −441.3 / −439.2 | −6.60% / −6.53% | +0.01%, −0.03% / −0.01%, −0.01% | 105 (30) / 105 (30) | 0 (25) / 0 (26) |

* **Every workload falls, in both modes, and none rises.** `script/census compare --base r4wo --aa r4w r4w r4w2
  r4wo2`: 105 / 105 workloads fall by at least one object in both `with` runs; the reverted tree's own A/A moves 28 /
  23 down and 33 / 28 up.
* **A/A:** every app is within ±0.19% except the Blog (up to 0.77%, its write workloads), still several times smaller
  than its effect (−5.18% / −4.60%).

### Which PRs carry it

[`attribute.rb`](../../bench/upstream/merged_sum/attribute.rb) (round 2's method) sums the per-site change
(RAILS/file:line, mean of each A/A pair) over all 105 workloads and assigns every site to the reverted PRs that touched
its file; PRs that share a file are one group, and `git blame` splits a group where it can (`SPLIT=1`). Of the
interpreter's 46,340 fewer objects summed over the workloads, 39,073 (84%) are at Rails sites; the rest is allocated in
gem or app frames. Interpreter (YJIT gives the same order: 35,512 attributed):

| PR(s) | Objects | Share of attributed | Mainly |
| --- | ---: | ---: | --- |
| #59533 + #59541 + #59552 + #59574 + #59576 + #59618 + #59642 + #59851 (WhereClause, where compile, association constraints) | −11,099 | 28% | most not split by blame; #59533 −1,908, #59618 −646 |
| #59278 + #59536 + #59542 + #59558 + #59596 (database statements, result casting) | −4,761 | 12% | #59542 −1,770, #59558 −1,242, #59536 −761 |
| #59538 + #59551 + #59554 + #59556 + #59810 (Merger, spawn) | −4,254 | 11% | #59551 −1,483, #59538 −587 |
| #59560 (PostgreSQL type map lookup) | −4,162 | 11% | PostgreSQL apps only: CASA −2,511, Hackatime −1,066 |
| `array/extract.rb` (#59544's ArrayHandler calls it) | −1,722 | 4.4% | #59544 |
| #59561 (`thread_mattr_accessor` key) | −1,423 | 3.6% | |
| #59244 + #59537 + #59603 + #59804 + #59824 (tag helper, form field names) | −1,413 | 3.6% | #59824 −696, #59804 −157 |
| #59562 (Subscriber event name) | −1,353 | 3.5% | |
| `string/output_safety.rb` (no reverted PR touches it) | −1,210 | 3.1% | |
| #59534 (Arel project/order in place) | −1,185 | 3.0% | |
| #59316 (HTTP URLs) | −966 | 2.5% | |
| `associations/alias_tracker.rb` | −821 | 2.1% | #59569 (builds the tracker only for through chains) |
| #59235 + #59613 (notification handles) | −579 | 1.5% | blame moves −3,048 to #59235 and +2,468 to #59613 on shared lines |
| the rest | −4,125 | 10.6% | each ≤ 1.4% |

The four largest groups carry 62%, as in round 2's ranking (WhereClause first). Of the PRs merged since round 3, the
ones with their own sites are #59569 (−821, via `alias_tracker.rb`), #59824 (−696), #59832 (−360), #59800 (−238) and
#59804 (−157), about 2,300 objects or 5% of the saving; #59851, #59810 and #59574 sit inside groups whose blame does
not split. #59983 (lease lookup) saves instructions, not objects (−5). This is a site attribution on the census, not
single-PR reverts: the jump from round 3 also contains the newer Rails main and Ruby pin, which this does not
separate.

### ruby-bench (Ruby 4.0.10)

Fixed heap as in round 3. Objects per iteration ([`sumalloc.rb`](../../bench/upstream/merged_sum/sumalloc.rb), 5
warmup + 10 measured iterations, main-a, without-a, without-b, main-b), table by
[`alloc_table.rb`](../../bench/upstream/merged_sum/alloc_table.rb) `DIR main-a main-b without-a without-b`:

| Benchmark | Mode | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |
| --- | --- | ---: | ---: | ---: | ---: |
| railsbench | interpreter | 983,931 → 922,444 | **−6.25%** | +0.00%, +0.00% | 1.30 → 1.20 |
| railsbench | YJIT | 989,269 → 927,782 | **−6.22%** | +0.00%, +0.00% | 1.30 → 1.30 |
| lobsters | interpreter | 541,004 → 513,507 | **−5.08%** | +0.00%, +0.00% | 0.60 → 0.60 |
| lobsters | YJIT | 544,353 → 516,866 | **−5.05%** | −0.00%, −0.00% | 0.60 → 0.60 |
| shipit | interpreter | 977,710 → 825,232 | **−15.60%** | −0.00%, −0.00% | 1.50 → 1.35 |
| shipit | YJIT | 990,858 → 838,391 | **−15.39%** | +0.00%, +0.00% | 1.50 → 1.40 |

No major GC in any measured iteration. Instructions per iteration
([`ruby_bench_ir.rb`](../../bench/upstream/actionview_cpu/ruby_bench_ir.rb), Valgrind 3.19.0 from
`script/bench-valgrind`, a 4-iteration run minus a 1-iteration run, 2 warmups; main-a, main-b, without-a; the table
inverts `summary`'s without-against-main-a):

| Benchmark | Mode | with vs without | A/A (main-b vs main-a) | Claimed |
| --- | --- | ---: | ---: | --- |
| railsbench | interpreter | **−2.88%** | −0.10% | yes |
| shipit | interpreter | **−9.52%** | +0.10% | yes |
| lobsters | interpreter | **−0.92%** | +0.07% | yes (round 3's −0.11% was not) |
| railsbench | YJIT | −3.55% | +0.40% | no: not JIT-flat |
| shipit | YJIT | −8.22% | +0.70% | no: not JIT-flat |
| lobsters | YJIT | +1.32% | −0.56% | no: not JIT-flat |

One without sample per row, as in round 3. Every YJIT row compiles new blocks in the measured window, so by
[bench.md](../bench.md) none counts. Wall time was not measured, for round 3's reasons (2-CPU orb).

### Ruby master and ZJIT

[`run_master.sh`](../../bench/upstream/combined_r4/run_master.sh), `--modes interp,zjit`, 200 warmup operations
(`CENSUS_WARMUP=200`), 14:42–15:45 UTC. Two axes, each with its own A/A, as in round 3:

* **Rails axis:** Ruby master `e8167b0ddd`, Rails main against the reverted Rails tree, ABBA `r4zw`, `r4zwo`,
  `r4zwo2`, `r4zw2`.
* **Ruby axis:** Rails main, Ruby master against master with our 17 merged ruby/ruby commits reverted (`4e222eb280`),
  `r4zw2`, `r4rwo`, `r4rwo2`, `r4zw3`.

**Our merged ruby/ruby commits on master** (`git log --author='Thomas Klemm' --since=2026-10-01`, 17): round 3's 14
plus #19680 (`iseq_may_write_block_code` cache), #19976 (refined `super`) and #19982 (objtostring recompile), and
ruby/date's `Date#<=>` NaN change synced into master. #20172 (`Time.new` zone) merged on 2026-11-26, after the pin,
and is in neither tree. Two reverts conflict: #19680 in an import line of `zjit/src/codegen.rs` (master's later
`PendingJITFrame` import kept) and #19484 in the test file `zjit/src/hir/opt_tests.rs` (master's version kept).

**Apps.** Eight of the eleven install on master, as in round 3: Writebook (redcarpet), Lobsters (commonmarker's
rb-sys) and CodeTriage (bluecloth) still fail to compile their C extensions. 79 workloads.

**Rails axis, census** (interpreter / ZJIT; `census_table.rb … interpreter,zjit r4zw r4zw2 r4zwo r4zwo2`):

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1711 → 1635 / 1715 → 1639 | −76.1 / −75.9 | −4.45% / −4.43% | +0.51%, +0.18% / −0.22%, −0.05% | 9 (2) / 10 (3) | 1 (2) / 0 (1) |
| campfire | 9 | 6408 → 6211 / 6561 → 6364 | −197.5 / −196.6 | −3.08% / −3.00% | +0.00%, −0.00% / −0.00%, −0.00% | 9 (0) / 9 (0) | 0 (0) / 0 (0) |
| casa | 10 | 13295 → 11912 / 13339 → 11959 | −1383.1 / −1380.5 | −10.40% / −10.35% | +0.01%, −0.00% / +0.01%, +0.00% | 10 (1) / 10 (4) | 0 (5) / 0 (5) |
| fizzy | 14 | 10483 → 9615 / 10485 → 9634 | −867.5 / −850.9 | −8.28% / −8.12% | +0.01%, −0.17% / −0.00%, +0.00% | 14 (2) / 14 (1) | 0 (1) / 0 (0) |
| hackatime | 12 | 7863 → 7449 / 7869 → 7463 | −414.5 / −405.9 | −5.27% / −5.16% | −0.00%, −0.01% / −0.01%, −0.00% | 12 (5) / 12 (4) | 0 (4) / 0 (4) |
| pingcrm | 8 | 2864 → 2743 / 2869 → 2744 | −121.7 / −126.0 | −4.25% / −4.39% | −0.03%, +0.13% / −0.17%, −0.01% | 8 (5) / 8 (8) | 0 (1) / 0 (0) |
| react-starter-kit | 8 | 1946 → 1882 / 1948 → 1883 | −64.1 / −64.7 | −3.30% / −3.32% | −0.26%, −0.06% / +0.02%, +0.01% | 8 (5) / 8 (3) | 0 (1) / 0 (2) |
| redprints-cfp | 8 | 2096 → 2007 / 2099 → 2010 | −89.4 / −89.2 | −4.26% / −4.25% | −0.02%, +0.02% / −0.00%, +0.03% | 8 (2) / 8 (3) | 0 (2) / 0 (3) |
| **All 8 apps** | 79 | 6381 → 5929 / 6407 → 5959 | −451.8 / −447.6 | −7.08% / −6.99% | +0.01%, −0.04% / −0.01%, −0.00% | 78 (22) / 79 (26) | 1 (16) / 0 (15) |

78 / 79 workloads fall by at least one object in both `with` runs and none rises in ZJIT (`script/census compare
--base r4zwo --aa r4zw`); the reverted tree's A/A moves 16 / 22 down and 22 / 21 up, and SQL digests change on none.
The one interpreter workload that rises in `r4zw2` is the Blog's `Turbo::Streams::ActionBroadcastJob`, which also
moves between the two runs of the same tree (584 → 759 objects), as in round 3 (618 → 796). ZJIT keeps the
interpreter's saving to within 0.16 points per app.

**Ruby axis, census** (`census_table.rb … interpreter,zjit r4zw2 r4zw3 r4rwo r4rwo2`):

| App | Workloads | Objects/workload without → with | Δ objects/workload | Share | A/A with, without | Moved ≤ −1 (A/A) | Moved ≥ +1 (A/A) |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| blog | 10 | 1641 → 1635 / 1626 → 1631 | −5.8 / +4.5 | −0.36% / +0.28% | −0.49%, −1.28% / −0.75%, −0.07% | 3 (2) / 6 (2) | 2 (4) / 1 (2) |
| campfire | 9 | 6211 → 6211 / 6365 → 6364 | −0.0 / −1.2 | −0.00% / −0.02% | +0.00%, +0.00% / +0.00%, −0.00% | 0 (0) / 3 (0) | 0 (0) / 0 (0) |
| casa | 10 | 11912 → 11913 / 11990 → 11960 | +0.1 / −29.6 | +0.00% / −0.25% | −0.00%, −0.00% / +0.00%, +0.01% | 2 (4) / 8 (4) | 3 (3) / 1 (4) |
| fizzy | 14 | 9612 → 9610 / 9640 → 9631 | −2.6 / −8.2 | −0.03% / −0.09% | −0.13%, +0.06% / −0.06%, +0.06% | 1 (4) / 12 (1) | 0 (1) / 0 (1) |
| hackatime | 12 | 7449 → 7449 / 7475 → 7463 | −0.3 / −12.4 | −0.00% / −0.17% | −0.00%, −0.02% / −0.00%, −0.00% | 4 (5) / 8 (5) | 3 (4) / 0 (3) |
| pingcrm | 8 | 2742 → 2742 / 2746 → 2741 | +0.5 / −4.6 | +0.02% / −0.17% | +0.02%, −0.04% / +0.02%, +0.06% | 3 (2) / 8 (2) | 3 (2) / 0 (2) |
| react-starter-kit | 8 | 1882 → 1880 / 1885 → 1883 | −2.8 / −1.7 | −0.15% / −0.09% | −0.01%, −0.09% / −0.01%, +0.01% | 5 (3) / 5 (1) | 0 (2) / 1 (1) |
| redprints-cfp | 8 | 2007 → 2007 / 2011 → 2010 | −0.4 / −1.0 | −0.02% / −0.05% | −0.01%, −0.04% / −0.01%, +0.02% | 3 (3) / 4 (3) | 2 (2) / 1 (2) |
| **All 8 apps** | 79 | 5930 → 5928 / 5965 → 5958 | −1.5 / −7.4 | −0.03% / −0.12% | −0.05%, −0.04% / −0.04%, +0.02% | 21 (23) / 54 (18) | 13 (18) / 4 (15) |

**Flat in the interpreter, a small ZJIT saving.** The interpreter total (−0.03%) is inside its A/A (−0.05%,
−0.04%), as in round 3. Under ZJIT the total is −0.12% against an A/A of −0.04% / +0.02%, and 54 workloads fall by at
least one object against 18 in the A/A (round 3: −0.04%, 38 against 16); CASA (−0.25%), Hackatime and PingCRM
(−0.17%) move most. Our ruby/ruby commits are mostly JIT correctness fixes; #19678 (interpolation without `to_s`) is
the one that saves objects under ZJIT.

**ruby-bench objects per iteration under ZJIT** (fixed heap; [`zjit_alloc_table.rb`](../../bench/upstream/combined_r3/zjit_alloc_table.rb)):

| Axis | Benchmark | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |
| --- | --- | ---: | ---: | ---: | ---: |
| Rails | railsbench | 972,947 → 911,460 | −6.32% | +0.00%, +0.00% | 7.90 → 7.40 |
| Rails | lobsters | 533,273 → 505,794 | −5.15% | −0.00%, −0.00% | 0.65 → 0.55 |
| Rails | shipit | 952,747 → 800,262 | −16.00% | −0.00%, −0.00% | 6.15 → 5.20 |
| Ruby | railsbench | 911,460 → 911,460 | +0.00% | +0.00%, +0.00% | 7.35 → 7.40 |
| Ruby | lobsters | 506,437 → 505,784 | −0.13% | −0.00%, +0.00% | 0.60 → 0.55 |
| Ruby | shipit | 802,738 → 800,263 | −0.31% | +0.00%, +0.00% | 4.85 → 5.25 |

Rails axis: −5.2% to −16.0%, as on 4.0.10. Ruby axis: lobsters and shipit allocate 653 and 2,475 fewer objects per
iteration with our commits (A/A ≤ 0.01%), round 3's #19678 saving (626 and 2,503); railsbench does not move. GC runs
per iteration vary between processes of the same tree (shipit 4.85–6.15), so no GC claim is made.

**Instructions per iteration under ZJIT** (`ruby_bench_ir.rb … --modes zjit`, 4-minus-1 iterations, 2 warmups; tags
`zm` for Ruby master, `zr` for master with our commits reverted):

| Axis | Benchmark | with vs without | A/A (main-b vs main-a) |
| --- | --- | ---: | ---: |
| Rails | railsbench | −2.65% | −0.19% |
| Rails | lobsters | −0.94% | −0.27% |
| Rails | shipit | −7.81% | −2.29% |
| Ruby | railsbench | −0.6% | −0.19% |
| Ruby | lobsters | −1.7% | −0.27% |
| Ruby | shipit | −4.9% | −2.29% |

(Rails axis: `summary` against main-a, inverted. Ruby axis: the mean of `zm` main-a and main-b against `zr` main-a,
one sample, computed from the logged totals.) **Observed, not claimed**, as in round 3: with 2 warmups ZJIT is still
compiling in the measured window, shipit's A/A reaches 2.3%, and the harness has no ZJIT flat check. The Rails-axis
rows point the same way as the interpreter's.


Receipts: [`data/combined-effect/r4.tar.xz`](data/combined-effect/r4.tar.xz) holds every census run JSON, log and
`meta.json` (`r4w`, `r4w2`, `r4wo`, `r4wo2`, `r4zw`, `r4zw2`, `r4zw3`, `r4zwo`, `r4zwo2`, `r4rwo`, `r4rwo2`), the
ruby-bench allocation JSONs and logs, the Valgrind logs and `.json`/`.jit` summaries, the attribution JSON, the PR
list, the revert logs and both tree diffs.
