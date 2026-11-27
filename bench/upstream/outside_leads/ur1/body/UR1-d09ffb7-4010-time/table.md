benchmark-ips, Ruby 4.0.10, no JIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 2.68M i/s | 3.50M i/s | +30.9% |
| `form key` | 869.5k i/s | 2.54M i/s | +192.5% |
| `form value` | 720.2k i/s | 2.82M i/s | +291.0% |
| `cookie` | 489.0k i/s | 1.06M i/s | +117.4% |
| `uri hello` | 2.73M i/s | 3.39M i/s | +24.3% |
| `uri user` | 1.13M i/s | 2.82M i/s | +149.9% |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.22 µs | 0.15 µs | −30.6% |
| `form key` | 0.91 µs | 0.25 µs | −72.3% |
| `form value` | 1.08 µs | 0.21 µs | −80.3% |
| `cookie` | 1.83 µs | 0.68 µs | −63.2% |
| `uri hello` | 0.22 µs | 0.15 µs | −30.6% |
| `uri user` | 0.70 µs | 0.22 µs | −69.0% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d09ffb7-4010-time.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-d09ffb7 at d09ffb7376
- ips hello: +30.9% with A/A 1.57% (best base 2.70M / 2.65M, candidate 3.50M)
- ips form key: +192.5% with A/A 3.76% (best base 885.9k / 853.2k, candidate 2.54M)
- ips form value: +291.0% with A/A 3.68% (best base 733.5k / 707.0k, candidate 2.82M)
- ips cookie: +117.4% with A/A 1.64% (best base 485.0k / 493.0k, candidate 1.06M)
- ips uri hello: +24.3% with A/A 5.79% (best base 2.81M / 2.65M, candidate 3.39M)
- ips uri user: +149.9% with A/A 1.69% (best base 1.12M / 1.14M, candidate 2.82M)
- wall hello: −30.6% [−31.2%, −29.4%] with A/A −0.2% [−1.4%, +0.7%] (234143 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −72.3% [−72.6%, −72.0%] with A/A −0.9% [−2.0%, +0.2%] (51562 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −80.3% [−80.6%, −80.1%] with A/A −0.6% [−1.8%, +1.0%] (44609 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −63.2% [−64.2%, −62.6%] with A/A −0.3% [−1.7%, +1.7%] (25966 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri hello: −30.6% [−31.5%, −29.9%] with A/A −0.1% [−1.4%, +0.5%] (225796 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri user: −69.0% [−69.5%, −68.8%] with A/A −0.2% [−1.8%, +0.3%] (64942 calls × 30 windows per process), JIT-flat in 90 processes
