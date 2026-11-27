Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 215.37 µs | 182.25 µs | −15.0% |
| `listener poll, one message` | 503.70 µs | 468.61 µs | −6.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/solid_stack/body/SC1-zjit-wall.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sc-base at 40dd29ffdc
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sc-cand at 155a2fbe98
- wall listener poll, idle: −15.0% [−15.4%, −14.5%] with A/A −0.1% [−0.9%, +0.9%] (244 calls × 30 windows per process), JIT-flat in 90 processes
- wall listener poll, one message: −6.9% [−8.0%, −5.7%] with A/A +0.3% [−1.0%, +1.2%] (92 calls × 30 windows per process), JIT-flat in 90 processes
