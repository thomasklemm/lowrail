Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 84.13 µs | 35.73 µs | within noise |
| `quiet.new(auth hash)` | 27.81 µs | 13.78 µs | −50.4% |
| `quiet merge` | 85.83 µs | 37.64 µs | −55.4% |
| `quiet []=` | 0.50 µs | 0.17 µs | −67.0% |
| `Mash.new(repository)` | 108.71 µs | 116.01 µs | +8.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at f41c3b2b27
- wall quiet.new(repository): −57.2% [−57.6%, −56.7%] with A/A −0.8% [−2.5%, −0.0%] (596 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
- wall quiet.new(auth hash): −50.4% [−50.6%, −50.1%] with A/A −0.2% [−0.5%, +0.6%] (1783 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet merge: −55.4% [−56.7%, −54.9%] with A/A −0.4% [−3.0%, +0.9%] (601 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet []=: −67.0% [−67.2%, −66.9%] with A/A −0.3% [−0.9%, +0.5%] (101568 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash.new(repository): +8.4% [+7.3%, +9.2%] with A/A −0.6% [−1.8%, +0.2%] (465 calls × 30 windows per process), JIT-flat in 90 processes
