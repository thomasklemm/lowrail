Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `belongs_to load` | 22.32 µs | 21.75 µs | −1.9% |
| `has_one load` | 24.06 µs | 23.29 µs | −3.2% |
| `has_many load` | 31.65 µs | 31.21 µs | −1.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/ASC1-wall-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at 2b46f50bda
- wall belongs_to load: −1.9% [−2.7%, −0.5%] with A/A −0.5% [−2.0%, +1.1%] (1868 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_one load: −3.2% [−4.0%, −2.2%] with A/A +0.2% [−1.4%, +1.0%] (1668 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_many load: −1.7% [−2.5%, −1.0%] with A/A −0.0% [−1.4%, +1.0%] (1280 calls × 30 windows per process), JIT-flat in 90 processes
