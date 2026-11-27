Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 84.53 µs | 89.48 µs | +5.8% |
| `quiet.new(repository)` | 83.43 µs | 36.12 µs | −56.6% |
| `quiet.new(auth hash)` | 27.71 µs | 14.05 µs | −49.1% |
| `quiet merge` | 88.15 µs | 38.34 µs | −56.7% |
| `quiet []=` | 0.50 µs | 0.17 µs | −66.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-plain-first-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at f41c3b2b27
- wall Mash.new(repository): +5.8% [+4.6%, +7.1%] with A/A −0.3% [−1.8%, +1.0%] (587 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet.new(repository): −56.6% [−57.0%, −56.2%] with A/A −0.7% [−2.2%, +0.6%] (603 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet.new(auth hash): −49.1% [−49.4%, −48.7%] with A/A −0.3% [−1.8%, +0.4%] (1779 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet merge: −56.7% [−57.0%, −56.3%] with A/A −0.2% [−0.9%, +0.8%] (576 calls × 30 windows per process), JIT-flat in 90 processes
- wall quiet []=: −66.4% [−66.5%, −66.2%] with A/A −0.4% [−1.5%, +0.9%] (97916 calls × 30 windows per process), JIT-flat in 90 processes
