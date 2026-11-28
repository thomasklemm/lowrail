Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 210.99 µs | 176.64 µs | −16.0% |
| `listener poll, one message` | 492.44 µs | 451.84 µs | −8.0% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/timing_a1_large/SC1-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sc-base at 40dd29ffdc
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sc-cand at 2cb1842043
- wall listener poll, idle: −16.0% [−16.7%, −15.4%] with A/A +0.4% [−0.3%, +1.3%] (249 calls × 30 windows per process), JIT-flat in 90 processes
- wall listener poll, one message: −8.0% [−8.9%, −7.0%] with A/A +0.8% [−0.3%, +2.2%] (103 calls × 30 windows per process), JIT-flat in 90 processes
