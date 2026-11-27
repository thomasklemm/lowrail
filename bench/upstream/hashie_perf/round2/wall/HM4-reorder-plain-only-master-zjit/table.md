Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | reorder | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 82.38 µs | 86.44 µs | +6.3% |
| `Mash#merge` | 84.83 µs | 86.43 µs | +1.9% |
| `mash['description'] =` | 0.54 µs | 0.53 µs | −1.8% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-reorder-plain-only-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-f at 9e313f308f (dirty)
- wall Mash.new(repository): +6.3% [+4.5%, +7.6%] with A/A −0.8% [−2.1%, +1.6%] (606 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash#merge: +1.9% [+1.2%, +2.9%] with A/A +0.6% [−1.4%, +1.4%] (591 calls × 30 windows per process), JIT-flat in 60 processes
- wall mash['description'] =: −1.8% [−2.0%, −1.4%] with A/A −0.0% [−0.6%, +0.4%] (91561 calls × 30 windows per process), JIT-flat in 60 processes
