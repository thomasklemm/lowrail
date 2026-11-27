Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | level-check | Change |
| --- | ---: | ---: | ---: |
| `Mash.new, Logger.new(nil)` | 30.76 µs | 30.65 µs | within noise |
| `Mash.new, logger at error level` | 30.79 µs | 29.20 µs | −4.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/logger/wall-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-lvl at 9e313f308f (dirty)
- wall Mash.new, Logger.new(nil): −0.1% [−0.5%, +1.3%] with A/A +0.2% [−1.4%, +1.0%] (1612 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
- wall Mash.new, logger at error level: −4.6% [−5.5%, −3.3%] with A/A +0.0% [−0.7%, +1.1%] (1630 calls × 30 windows per process), JIT-flat in 60 processes
