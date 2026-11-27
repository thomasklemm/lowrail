Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | e2 | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 712.62 µs | 725.23 µs | +1.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/wall_noise/yjit-e2.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-e2 at d29055285a
- wall foreign_keys(t): +1.9% [+0.4%, +2.9%] with A/A −0.0% [−1.1%, +1.0%] (68 calls × 30 windows per process), JIT-flat in 90 processes
