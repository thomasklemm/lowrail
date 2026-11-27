Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | flag-first | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 82.37 µs | 85.38 µs | within noise |
| `Mash#merge` | 85.08 µs | 85.77 µs | within noise |
| `mash['description'] =` | 0.54 µs | 0.51 µs | −5.5% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-flagfirst-plain-only-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-g at 9e313f308f (dirty)
- wall Mash.new(repository): +3.5% [+2.7%, +5.1%] with A/A +1.7% [+0.1%, +2.6%] (614 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
- wall Mash#merge: +1.0% [−0.1%, +3.0%] with A/A +0.8% [−1.7%, +2.9%] (584 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall mash['description'] =: −5.5% [−5.8%, −5.2%] with A/A +0.0% [−0.7%, +0.7%] (90843 calls × 30 windows per process), JIT-flat in 90 processes
