Time per call, Ruby 4.0.9, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `Marshal.dump, 1 MiB string` | 328.04 µs | 318.43 µs | within noise |
| `attributes_for_database, 1 MiB serialized every call` | 509.66 µs | 502.05 µs | −0.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-large-yjit-wall-319e55a661.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at 319e55a661
- wall Marshal.dump, 1 MiB string: −0.6% [−0.9%, −0.2%] with A/A +0.3% [+0.1%, +0.8%] (116 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
- wall attributes_for_database, 1 MiB serialized every call: −0.6% [−1.0%, −0.2%] with A/A +0.1% [−0.2%, +0.7%] (98 calls × 30 windows per process), JIT-flat in 90 processes
