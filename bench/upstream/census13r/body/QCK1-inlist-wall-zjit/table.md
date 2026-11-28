Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `where(id: 20 ids), miss` | 61.88 µs | 53.63 µs | −13.6% |
| `where(id: 20 ids), hit` | 38.02 µs | 30.55 µs | −19.6% |
| `where(id: 100 ids), miss` | 217.19 µs | 177.69 µs | −18.3% |
| `where(id: 100 ids), hit` | 133.01 µs | 96.61 µs | −27.5% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-inlist-wall-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- wall where(id: 20 ids), miss: −13.6% [−14.5%, −12.8%] with A/A −0.3% [−1.4%, +1.0%] (803 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 20 ids), hit: −19.6% [−19.9%, −19.3%] with A/A −0.1% [−1.0%, +0.4%] (1244 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 100 ids), miss: −18.3% [−18.7%, −17.1%] with A/A −0.4% [−1.3%, +0.3%] (202 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 100 ids), hit: −27.5% [−27.8%, −26.9%] with A/A −0.5% [−1.0%, +0.0%] (357 calls × 30 windows per process), JIT-flat in 90 processes
