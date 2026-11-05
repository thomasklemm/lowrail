**Title:** The default 15 warmup iterations leave YJIT and ZJIT compiling in the measured window of the Rails benchmarks

With the default harness (15 warmup iterations, then at least 10 measured iterations and 10 seconds), YJIT and ZJIT still compile new code during the measured iterations of railsbench, lobsters, shipit and erubi-rails. I counted compiles per iteration with `YJIT_BENCH_STATS=compiled_block_count,compiled_iseq_count,compile_time_ns` (Ruby 4.0.9, `--yjit`) and `ZJIT_BENCH_STATS=compiled_iseq_count,compile_time_ns` (Ruby master 7f9638f41e, `--zjit`), `WARMUP_ITRS=0 MIN_BENCH_ITRS=60`, on ruby-bench 00f0f8b, two processes each:

| | last iteration with a compile | compile time in iterations 16–25 | 31–40 | 51–60 |
| --- | ---: | ---: | ---: | ---: |
| YJIT railsbench | 59 | 0.01–0.02% | 0.01% | 0.01% |
| YJIT lobsters | 60 (never stops) | 0.88–0.93% | 0.65% | 0.16% |
| YJIT shipit | 60 (never stops) | 0.32% | 0.05% | 0.10% |
| YJIT erubi-rails | 51–56 | 0.01% | 0.01% | 0.01% |
| ZJIT railsbench | 39–42 | 0.01% | 0.01% | 0 |
| ZJIT lobsters | 49 | 0.31–0.34% | 0.27% | 0 |
| ZJIT shipit | 49 | 0.05–0.07% | 0.06% | 0 |
| ZJIT erubi-rails | 31 | 0.02% | 0.02% | 0 |

The percentages are compile time over the wall time of those 10 iterations. In iterations 16–25, YJIT compiles about 2,000 blocks per lobsters process and 1,270 per shipit process.

rubybench already passes `--warmup=30` for JIT runs (rubybench/rubybench#30), and with 50 warmup iterations ZJIT compiles nothing in the window on any of the four. The remaining cost is small; the question is whether `run_benchmarks.rb` should default to a longer JIT warmup for these benchmarks, so local runs and `tool/zjit_diff.rb` measure the same steady state as the published numbers. `benchmarks.yml` has no per-benchmark warmup setting today.
