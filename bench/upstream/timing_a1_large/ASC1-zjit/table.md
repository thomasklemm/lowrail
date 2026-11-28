Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `belongs_to load` | 46.98 µs | 45.97 µs | −1.8% |
| `has_one load` | 51.59 µs | 50.26 µs | −2.0% |
| `has_many load` | 68.76 µs | 68.00 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/timing_a1_large/ASC1-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at ed1b28c5b9
- wall belongs_to load: −1.8% [−2.1%, −1.1%] with A/A +0.4% [−0.4%, +1.1%] (1072 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_one load: −2.0% [−2.5%, −1.1%] with A/A +0.4% [−0.5%, +1.0%] (990 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_many load: −0.5% [−1.2%, +0.4%] with A/A +0.6% [−0.5%, +1.7%] (727 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
