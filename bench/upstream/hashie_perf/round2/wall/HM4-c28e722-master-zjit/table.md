Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 83.87 µs | 35.49 µs | −57.6% |
| `quiet.new(auth hash)` | 27.84 µs | 13.72 µs | −50.3% |
| `quiet merge` | 85.10 µs | 37.25 µs | −55.8% |
| `quiet []=` | 0.51 µs | 0.17 µs | −67.0% |
| `Mash.new(repository)` | 107.84 µs | 115.33 µs | +8.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at c28e722982
- wall quiet.new(repository): −57.6% [−57.9%, −57.0%] with A/A −0.1% [−1.9%, +1.7%] (600 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −50.3% [−50.8%, −50.1%] with A/A −0.5% [−1.6%, +0.2%] (1554 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet merge: −55.8% [−56.6%, −55.1%] with A/A −0.1% [−5.1%, +2.5%] (589 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −67.0% [−67.3%, −66.9%] with A/A −0.1% [−0.7%, +0.8%] (98820 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash.new(repository): +8.1% [+7.0%, +8.8%] with A/A +0.6% [−2.0%, +1.8%] (474 calls × 30 windows per process), JIT-flat in 60 processes
