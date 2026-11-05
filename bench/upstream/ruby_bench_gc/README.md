# GC cost in ruby-bench

Scripts and data for [docs/upstream/ruby-bench-gc.md](../../../docs/upstream/ruby-bench-gc.md).

- `build_ruby.sh REV NAME`: build Ruby master at REV into `~/rubies/NAME`.
- `harness_gcsplit.rb`: local harness; per iteration wall, `GC.total_time`, counts and per-collection
  `GC::Profiler` records, then a forced minor/major probe. Writes `$GCSPLIT_OUT`.
- `matrix.sh OUT ROUNDS`: rounds × {base-a, patch, base-b} × modes × benchmarks, two pinned workers.
- `summarize.rb DIR`: per-round and pooled tables (`data/matrix/summary.md`).
- `e2e.sh`: `run_benchmarks.rb --harness=gc --pvalue` with the draft branch (`data/e2e/`).
- `profiler_cost.rb`: GC::Profiler on/off cost per forced minor GC.
- `*-body.md`: draft PR bodies for the two fork branches (not opened).
