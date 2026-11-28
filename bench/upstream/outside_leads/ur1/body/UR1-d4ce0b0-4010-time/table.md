benchmark-ips, Ruby 4.0.10, no JIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 2.84M i/s | 3.43M i/s | +20.7% |
| `form key` | 880.8k i/s | 2.49M i/s | +182.4% |
| `form value` | 739.8k i/s | 2.92M i/s | +294.8% |
| `cookie` | 493.9k i/s | 1.08M i/s | +119.3% |
| `uri hello` | 2.83M i/s | 3.40M i/s | +20.1% |
| `uri user` | 1.13M i/s | 2.84M i/s | +151.5% |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.21 µs | 0.15 µs | −29.5% |
| `form key` | 0.88 µs | 0.24 µs | −71.9% |
| `form value` | 1.06 µs | 0.21 µs | −80.0% |
| `cookie` | 1.71 µs | 0.65 µs | −61.4% |
| `uri hello` | 0.22 µs | 0.15 µs | −30.4% |
| `uri user` | 0.68 µs | 0.21 µs | −68.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d4ce0b0-4010-time.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-d4ce0b0 at d4ce0b0376
- ips hello: +20.7% with A/A 2.32% (best base 2.88M / 2.81M, candidate 3.43M)
- ips form key: +182.4% with A/A 1.87% (best base 889.0k / 872.5k, candidate 2.49M)
- ips form value: +294.8% with A/A 0.24% (best base 739.0k / 740.7k, candidate 2.92M)
- ips cookie: +119.3% with A/A 7.87% (best base 513.4k / 474.5k, candidate 1.08M)
- ips uri hello: +20.1% with A/A 1.63% (best base 2.85M / 2.80M, candidate 3.40M)
- ips uri user: +151.5% with A/A 1.77% (best base 1.14M / 1.12M, candidate 2.84M)
- wall hello: −29.5% [−30.9%, −28.3%] with A/A −0.4% [−1.8%, +0.9%] (243634 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −71.9% [−72.3%, −71.4%] with A/A +0.2% [−1.3%, +0.8%] (47441 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −80.0% [−80.3%, −79.7%] with A/A −0.7% [−2.0%, +1.0%] (41681 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −61.4% [−62.0%, −60.8%] with A/A +0.6% [−2.7%, +2.2%] (24232 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri hello: −30.4% [−31.1%, −29.2%] with A/A −0.9% [−2.5%, +0.4%] (230959 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri user: −68.6% [−69.1%, −68.0%] with A/A −0.8% [−1.8%, +0.7%] (63240 calls × 30 windows per process), JIT-flat in 90 processes
