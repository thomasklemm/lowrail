Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `find, miss` | 15.23 µs | 14.42 µs | −5.4% |
| `find, hit` | 11.23 µs | 10.50 µs | −6.2% |
| `where with 3 binds, miss` | 26.92 µs | 25.37 µs | −5.0% |
| `where with 3 binds, hit` | 21.21 µs | 20.03 µs | −4.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-wall-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- wall find, miss: −5.4% [−6.4%, −4.5%] with A/A −0.2% [−1.2%, +1.3%] (3164 calls × 30 windows per process), JIT-flat in 90 processes
- wall find, hit: −6.2% [−7.1%, −5.4%] with A/A +0.5% [−0.2%, +1.3%] (3968 calls × 30 windows per process), JIT-flat in 90 processes
- wall where with 3 binds, miss: −5.0% [−5.6%, −4.3%] with A/A +0.6% [−1.5%, +1.7%] (1648 calls × 30 windows per process), JIT-flat in 90 processes
- wall where with 3 binds, hit: −4.4% [−5.9%, −2.4%] with A/A +0.6% [−0.2%, +2.2%] (2419 calls × 30 windows per process), JIT-flat in 90 processes
