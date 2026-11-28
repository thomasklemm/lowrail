Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `where(id: 20 ids), miss` | 68.47 µs | 61.08 µs | −10.5% |
| `where(id: 20 ids), hit` | 40.41 µs | 33.76 µs | −16.6% |
| `where(id: 100 ids), miss` | 225.44 µs | 191.15 µs | −15.0% |
| `where(id: 100 ids), hit` | 140.33 µs | 106.81 µs | −23.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-inlist-wall-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- wall where(id: 20 ids), miss: −10.5% [−11.4%, −9.6%] with A/A +0.3% [−0.8%, +0.8%] (650 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 20 ids), hit: −16.6% [−17.1%, −15.8%] with A/A +0.4% [−0.3%, +1.3%] (1104 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 100 ids), miss: −15.0% [−15.6%, −14.3%] with A/A +0.8% [−0.0%, +1.5%] (186 calls × 30 windows per process), JIT-flat in 90 processes
- wall where(id: 100 ids), hit: −23.3% [−24.1%, −22.8%] with A/A +0.3% [−0.2%, +0.7%] (317 calls × 30 windows per process), JIT-flat in 90 processes
