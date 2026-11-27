benchmark-ips, Ruby 4.0.10, no JIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 2.56M i/s | 3.35M i/s | +30.7% |
| `form key` | 777.3k i/s | 2.47M i/s | +218.0% |
| `form value` | 666.4k i/s | 2.70M i/s | +304.9% |
| `cookie` | 483.5k i/s | 1.08M i/s | +124.2% |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.25 µs | 0.17 µs | −32.2% |
| `form key` | 0.97 µs | 0.29 µs | −70.3% |
| `form value` | 1.17 µs | 0.25 µs | −78.3% |
| `cookie` | 1.83 µs | 0.79 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-4010-time.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri at a3b201f05b
- ips hello: +30.7% with A/A 7.41% (best base 2.47M / 2.66M, candidate 3.35M)
- ips form key: +218.0% with A/A 2.71% (best base 787.9k / 766.8k, candidate 2.47M)
- ips form value: +304.9% with A/A 2.31% (best base 674.1k / 658.7k, candidate 2.70M)
- ips cookie: +124.2% with A/A 5.93% (best base 497.8k / 469.1k, candidate 1.08M)
- wall hello: −32.2% [−32.7%, −32.0%] with A/A −0.6% [−1.8%, +0.2%] (205535 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −70.3% [−70.5%, −70.2%] with A/A −1.3% [−2.3%, +0.0%] (47344 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −78.3% [−78.4%, −78.1%] with A/A −0.3% [−1.6%, +0.5%] (40487 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −57.2% [−57.7%, −56.6%] with A/A −3.2% [−4.6%, −1.1%] (25816 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
