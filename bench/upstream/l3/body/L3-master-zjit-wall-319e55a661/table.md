Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 263,960 | 215,642 | −18.3% |
| `attributes_for_database` | 4 | 2 | 106,579 | 57,748 | −45.8% |
| `attributes_before_type_cast` | 4 | 2 | 96,015 | 49,979 | −47.9% |
| `MessagePack dump` | 19 | 17 | 128,147 | 79,189 | −38.2% |

Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `Marshal.dump` | 26.14 µs | 21.81 µs | −16.9% |
| `attributes_for_database` | 10.51 µs | 5.60 µs | −46.6% |
| `attributes_before_type_cast` | 9.43 µs | 4.74 µs | −49.9% |
| `MessagePack dump` | 14.24 µs | 9.31 µs | −34.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-master-zjit-wall-319e55a661.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l3 at 319e55a661
- zjit Marshal.dump: instructions −18.3% with A/A 0.17% (base 264,189 / 263,731, candidate 215,642), JIT-flat in 6 windows
- zjit attributes_for_database: instructions −45.8% with A/A 0.15% (base 106,499 / 106,659, candidate 57,748), JIT-flat in 6 windows
- zjit attributes_before_type_cast: instructions −47.9% with A/A 0.04% (base 96,036 / 95,993, candidate 49,979), JIT-flat in 6 windows
- zjit MessagePack dump: instructions −38.2% with A/A 0.01% (base 128,140 / 128,155, candidate 79,189), JIT-flat in 6 windows
- wall Marshal.dump: −16.9% [−17.3%, −16.5%] with A/A +0.2% [−0.2%, +0.5%] (1863 calls × 30 windows per process), JIT-flat in 90 processes
- wall attributes_for_database: −46.6% [−46.9%, −46.4%] with A/A +0.4% [−0.6%, +1.4%] (4668 calls × 30 windows per process), JIT-flat in 90 processes
- wall attributes_before_type_cast: −49.9% [−50.1%, −49.5%] with A/A +0.6% [−0.3%, +1.4%] (5126 calls × 30 windows per process), JIT-flat in 90 processes
- wall MessagePack dump: −34.3% [−34.6%, −33.9%] with A/A +0.1% [−0.3%, +1.5%] (3330 calls × 30 windows per process), JIT-flat in 90 processes
