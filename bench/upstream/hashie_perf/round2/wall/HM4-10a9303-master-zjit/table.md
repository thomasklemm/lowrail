Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 84.39 µs | 37.45 µs | −55.6% |
| `quiet.new(auth hash)` | 27.94 µs | 14.27 µs | −49.0% |
| `quiet merge` | 86.52 µs | 39.42 µs | −54.5% |
| `quiet []=` | 0.51 µs | 0.17 µs | −66.1% |
| `Mash.new(repository)` | 108.93 µs | 117.42 µs | +9.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-10a9303-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-h at 10a9303397
- wall quiet.new(repository): −55.6% [−55.8%, −54.7%] with A/A −0.4% [−3.6%, +1.2%] (568 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet.new(auth hash): −49.0% [−49.2%, −48.6%] with A/A +0.5% [−0.2%, +1.2%] (1712 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet merge: −54.5% [−55.2%, −53.2%] with A/A +0.3% [−2.6%, +4.1%] (546 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet []=: −66.1% [−66.4%, −65.9%] with A/A +0.4% [−0.8%, +0.9%] (100139 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash.new(repository): +9.1% [+7.4%, +9.8%] with A/A +0.2% [−1.2%, +2.6%] (438 calls × 30 windows per process), JIT-flat in 90 processes
