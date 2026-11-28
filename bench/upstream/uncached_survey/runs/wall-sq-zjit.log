Time per call, Ruby 4.1.0dev, ZJIT, 8 rounds of fresh processes on one core

| | main | uncached | Change |
| --- | ---: | ---: | ---: |
| `worker poll, idle` | 202.83 µs | 204.58 µs | within noise |
| `dispatcher poll, idle` | 229.90 µs | 237.40 µs | not JIT-flat, no claim |
| `dispatcher poll, 10 due jobs` | 6.721 ms | 6.581 ms | not JIT-flat, no claim |
| `dispatcher poll, 100 due jobs` | 25.941 ms | 24.633 ms | within noise |
| `worker claim, 3 jobs` | 4.483 ms | 4.497 ms | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/wall-sq-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/main/solid_queue at b9c646a848
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/cand/solid_queue at b9c646a848 (dirty)
- wall worker poll, idle: +0.7% [−1.7%, +3.8%] with A/A −0.3% [−4.7%, +2.6%] (240 calls × 30 windows per process), JIT-flat in 24 processes: fewer than 10 rounds, no claim
- wall dispatcher poll, idle: +3.0% [+0.5%, +5.9%] with A/A −0.7% [−3.8%, +0.9%] (216 calls × 30 windows per process): not JIT-flat (r1 candidate compiled_iseq_count +2, r1 candidate compiled_side_exit_count +27, r2 base compiled_iseq_count +2, …), no claim
- wall dispatcher poll, 10 due jobs: −3.2% [−6.9%, +2.0%] with A/A −1.1% [−5.5%, +2.4%] (7 calls × 30 windows per process): not JIT-flat (r5 base compiled_iseq_count +1, r5 base compiled_side_exit_count +13, r6 candidate compiled_iseq_count +2, …), no claim
- wall dispatcher poll, 100 due jobs: −4.4% [−11.8%, +1.7%] with A/A −2.7% [−9.2%, +2.0%] (2 calls × 30 windows per process), JIT-flat in 24 processes: fewer than 10 rounds, no claim
- wall worker claim, 3 jobs: −0.4% [−4.8%, +5.5%] with A/A −1.8% [−6.6%, +2.8%] (11 calls × 30 windows per process), JIT-flat in 24 processes: fewer than 10 rounds, no claim
