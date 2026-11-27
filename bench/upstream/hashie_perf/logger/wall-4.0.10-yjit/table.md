Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | level-check | Change |
| --- | ---: | ---: | ---: |
| `Mash.new, Logger.new(nil)` | 24.98 µs | 25.06 µs | within noise |
| `Mash.new, logger at error level` | 24.99 µs | 23.27 µs | −7.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/logger/wall-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-lvl at 9e313f308f (dirty)
- wall Mash.new, Logger.new(nil): +0.3% [−0.1%, +0.7%] with A/A −0.1% [−0.5%, +0.6%] (1951 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
- wall Mash.new, logger at error level: −7.1% [−7.3%, −6.5%] with A/A −0.2% [−0.4%, +0.6%] (1992 calls × 30 windows per process), JIT-flat in 60 processes
