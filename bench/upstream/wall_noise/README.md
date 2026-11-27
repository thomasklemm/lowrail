# Wall time under a JIT: noise study and `upstream-bench --wall` validation (2026-11-27)

Why E2's scalar `foreign_keys` cohorts under ZJIT spread by about ±4% around a cost of about 1%, and the measurement
design that resolves ~1% on this orb. Method and conclusions: [bench.md](../../../docs/bench.md#wall-time-under-a-jit-noise-sources-2026-11-27);
the option: [body-numbers](../../../docs/upstream/body-numbers.md).

Rubies: master `42a644f6e0` (ZJIT; also built with YJIT), 4.0.10 `a704b7cd95` (YJIT). Rails main `088fc0cf61`, E2
head `d29055285a`. sqlite3 2.10.2 / SQLite 3.54.1. Workload: [e2_fk.rb](e2_fk.rb), the fixture of E2's `paired.rb`
(1,000 tables with a foreign key and an index, 100 plain tables), public `foreign_keys` on one table per call.

## Noise study

`study-2026-11-27.tar.gz` holds the worker, driver, analysis scripts and every window of every process
(`round*.jsonl`). Each configuration is an A/A (main against main), 16 ABBA pairs of fresh processes, 20 windows
of 200 calls (`round4`/`y-short-gcoff`: 80 × 50) after 3 warm-up windows, one variable changed against `z-base`
(ZJIT, `taskset -c 1`, GC on). `round1-large.jsonl` is the same round 1 on an a1.large orb (8 vCPUs).
`round4-contaminated.jsonl` ran two cohorts on one core by mistake and is not analysed. Thread CPU time per window;
summary from `summary.rb`:

| file | label | processes | windows × calls | sd of process means, observed / window noise only | A/A pair sd: median / p10 / min | JIT moved (windows) |
| --- | --- | ---: | --- | --- | --- | ---: |
| round1.jsonl | z-base | 32 | 20 × 200 | 3.38% / 1.61% | 4.49% / 2.85% / 1.60% | 0 |
| round1.jsonl | z-noaslr | 32 | 20 × 200 | 2.99% / 1.50% | 4.30% / 1.62% / 0.90% | 0 |
| round1.jsonl | z-heap-gcoff | 32 | 20 × 200 | 2.35% / 0.91% | 3.55% / 1.93% / 1.14% | 0 |
| round1.jsonl | z-core0 | 32 | 20 × 200 | 3.69% / 1.05% | 2.42% / 1.74% / 2.51% | 0 |
| round1.jsonl | z-nopin | 32 | 20 × 200 | 2.71% / 1.21% | 3.77% / 1.73% / 1.50% | 0 |
| round1.jsonl | z-execmem | 32 | 20 × 200 | 4.24% / 1.29% | 6.24% / 3.95% / 2.98% | 0 |
| round1.jsonl | interp | 32 | 20 × 200 | 3.07% / 1.06% | 3.73% / 1.97% / 1.44% | 0 |
| round1.jsonl | y-base | 32 | 20 × 200 | 5.16% / 1.94% | 6.99% / 3.70% / 3.42% | 57 |
| round1-large.jsonl | z-base | 32 | 20 × 200 | 3.09% / 1.44% | 4.24% / 2.97% / 3.01% | 0 |
| round1-large.jsonl | z-noaslr | 32 | 20 × 200 | 2.64% / 1.25% | 3.44% / 1.49% / 1.41% | 0 |
| round1-large.jsonl | z-heap-gcoff | 32 | 20 × 200 | 3.89% / 1.59% | 2.75% / 1.64% / 1.41% | 0 |
| round1-large.jsonl | z-nopin | 32 | 20 × 200 | 4.97% / 2.03% | 5.15% / 3.03% / 3.17% | 0 |
| round1-large.jsonl | interp | 32 | 20 × 200 | 5.37% / 1.96% | 5.37% / 3.66% / 2.18% | 0 |
| round1-large.jsonl | y-base | 32 | 20 × 200 | 4.01% / 1.73% | 3.32% / 2.22% / 2.36% | 67 |
| round2.jsonl | z-fixrand | 32 | 20 × 200 | 4.33% / 1.69% | 2.85% / 1.10% / 1.15% | 0 |
| round2.jsonl | z-det | 32 | 20 × 200 | 2.45% / 1.28% | 2.65% / 1.42% / 1.26% | 0 |
| round3.jsonl | z-sibload | 16 | 20 × 200 | 2.78% / 1.52% | 3.89% / 2.85% / 2.15% | 0 |
| round3.jsonl | z-base2 | 16 | 20 × 200 | 3.52% / 1.08% | 3.86% / 2.83% / 1.50% | 0 |
| round4.jsonl | z-short-gcoff | 32 | 80 × 50 | 3.41% / 0.76% | 2.28% / 2.70% / 2.89% | 0 |
| round4.jsonl | z-short | 32 | 80 × 50 | 3.22% / 0.82% | 3.49% / 1.77% / 1.05% | 0 |
| round5.jsonl | y-gcoff | 32 | 20 × 200 | 2.35% / 1.31% | 2.18% / 1.56% / 1.21% | 0 |
| round5.jsonl | y-short-gcoff | 32 | 80 × 50 | 3.92% / 0.86% | 3.68% / 3.60% / 2.23% | 0 |
| round6.jsonl | z-ref | 32 | 20 × 200 | 3.21% / 1.36% | 5.06% / 3.62% / 3.54% | 0 |

`z-noaslr` is `setarch -R`, `z-heap-gcoff` the bench.md heap floors with `GC.start` then GC off per window,
`z-fixrand` LD_PRELOAD of `ruby_bench_round4/fixrand` (fixed hash seed), `z-det` all three, `z-execmem`
`--zjit-exec-mem-size=512 --zjit-mem-size=1024`, `z-sibload` a busy loop on the sibling vCPU 0, `z-ref` GC off plus a
float sort and an integer loop timed before every window. `round2`/`round6` also hold two 300-window processes
(`z-long`, `z-long-ref`) that show the host's slow phases.

## Validation of `--wall` (30 rounds each)

`plant.diff` is the planted regression: 150 `Integer#to_s` per `foreign_keys` call on main, about 6.8 µs, ~1.0% of
a 0.69 ms call under ZJIT (measured standalone: 4.5 µs per 100 under ZJIT, 5.6 µs under YJIT). `rails-aa` is a
second worktree of main. Each directory is one `script/upstream-bench --modes "" --wall 30` run with `table.md`,
`results.json` and `commands.sh`; raw process logs are in `raw-2026-11-27.tar.gz`.

| run | mode | candidate | calls/window | change [95% CI] | A/A [95% CI] | verdict |
| --- | --- | --- | ---: | --- | --- | --- |
| `zjit-aa` | ZJIT | A/A (main vs main) | 72 | +0.7% [−0.2%, +1.3%] | +0.1% [−1.0%, +0.8%] | no claim, JIT-flat true |
| `zjit-plant` | ZJIT | planted ~1% | 70 | +1.3% [+0.7%, +2.2%] | +0.0% [−0.7%, +1.2%] | claimed, JIT-flat true |
| `zjit-e2` | ZJIT | E2 head d29055285a | 74 | −0.0% [−0.7%, +0.5%] | +0.4% [−0.8%, +1.7%] | no claim, JIT-flat true |
| `yjit-aa` | YJIT | A/A (main vs main) | 69 | +0.8% [−0.3%, +1.7%] | +0.5% [−0.5%, +1.4%] | no claim, JIT-flat true |
| `yjit-plant` | YJIT | planted ~1% | 63 | +1.2% [+0.3%, +2.0%] | +0.6% [−0.3%, +1.1%] | claimed, JIT-flat true |
| `yjit-e2` | YJIT | E2 head d29055285a | 68 | +1.9% [+0.4%, +2.9%] | −0.0% [−1.1%, +1.0%] | claimed, JIT-flat true |

`v1-median/` keeps the first estimator's partial runs (median of candidate minus the mean of both bases), stopped
after thermos-sol showed it is biased under skewed process noise; its A/A rescored with the final estimator gives
+0.07% [−0.65%, +0.60%].

Reading: both A/As stay inside their intervals and both planted ~1% regressions are claimed, so on this orb the
cohort resolves about 1% (interval half-widths 0.5–1.2%), not much less. Both A/A point estimates lean positive
(+0.7%, +0.8%) with intervals that include 0; a change near 1% needs its interval, not its point estimate.

E2 head under ZJIT is −0.0% [−0.7%, +0.5%]: no measurable cost, and the earlier +8.1% / +5.0% / +5.5% ZJIT cohorts
(GC on, medians of 6 rounds) were process-level noise of the kind measured above. Under YJIT on 4.0.10 head costs
+1.9% [+0.4%, +2.9%], in line with the 4.0.9 +2.8% (A/A −1.2%) and the 7 extra objects and ~10k instructions per
call; that cost is real and small. Wall time here is GC-off thread CPU time, so the 7 objects' GC share is not in it.
