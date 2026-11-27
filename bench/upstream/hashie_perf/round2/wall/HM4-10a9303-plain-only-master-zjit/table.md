Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 82.73 µs | 84.74 µs | +2.5% |
| `Mash#merge` | 85.15 µs | 84.98 µs | within noise |
| `mash['description'] =` | 0.54 µs | 0.52 µs | −4.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-10a9303-plain-only-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-h at 10a9303397
- wall Mash.new(repository): +2.5% [+0.2%, +3.4%] with A/A −0.1% [−1.1%, +1.2%] (625 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash#merge: −0.2% [−1.1%, +0.9%] with A/A +1.1% [+0.2%, +2.0%] (588 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
- wall mash['description'] =: −4.7% [−4.9%, −4.3%] with A/A −0.1% [−0.6%, +0.3%] (82075 calls × 30 windows per process), JIT-flat in 90 processes
