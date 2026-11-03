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
