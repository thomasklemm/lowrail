Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | flag-first | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 83.45 µs | 36.85 µs | −55.7% |
| `quiet.new(auth hash)` | 27.78 µs | 14.18 µs | −48.9% |
| `quiet merge` | 84.54 µs | 38.62 µs | −54.3% |
| `quiet []=` | 0.50 µs | 0.17 µs | −65.1% |
| `Mash.new(repository)` | 106.79 µs | 116.50 µs | +9.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-flagfirst-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-g at 9e313f308f (dirty)
- wall quiet.new(repository): −55.7% [−56.1%, −55.3%] with A/A +0.1% [−2.3%, +1.5%] (602 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet.new(auth hash): −48.9% [−49.1%, −48.6%] with A/A +0.4% [−0.7%, +0.5%] (1801 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet merge: −54.3% [−55.0%, −53.7%] with A/A +0.5% [−1.4%, +1.8%] (605 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet []=: −65.1% [−65.3%, −64.8%] with A/A −0.6% [−0.9%, +0.3%] (92049 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash.new(repository): +9.7% [+8.8%, +10.2%] with A/A +0.0% [−0.7%, +0.5%] (478 calls × 30 windows per process), JIT-flat in 90 processes
