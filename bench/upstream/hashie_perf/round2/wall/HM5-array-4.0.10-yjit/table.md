Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Hash#to_hash, one Array of 131,072` | 3.689 ms | 3.709 ms | +0.6% |
| `Mash#to_hash, 100 scalar keys` | 19.62 µs | 16.07 µs | −18.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM5-array-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-th at 6b6f67b39c
- wall Hash#to_hash, one Array of 131,072: +0.6% [+0.4%, +0.9%] with A/A +0.1% [−0.3%, +0.3%] (13 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash#to_hash, 100 scalar keys: −18.3% [−18.5%, −17.6%] with A/A −0.1% [−0.6%, +0.4%] (2421 calls × 30 windows per process), JIT-flat in 90 processes
