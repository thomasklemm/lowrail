benchmark-ips, Ruby 4.0.10, no JIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 2.65M i/s | 3.72M i/s | +40.3% |
| `form key` | 816.4k i/s | 2.72M i/s | +232.8% |
| `form value` | 685.7k i/s | 2.89M i/s | +321.2% |
| `cookie` | 509.0k i/s | 1.11M i/s | +117.7% |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.24 µs | 0.16 µs | −35.1% |
| `form key` | 0.95 µs | 0.26 µs | −72.7% |
| `form value` | 1.16 µs | 0.23 µs | −80.4% |
| `cookie` | 1.78 µs | 0.76 µs | −57.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-cecaed1-4010-time.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-cecaed1 at cecaed123f
- ips hello: +40.3% with A/A 1.70% (best base 2.63M / 2.67M, candidate 3.72M)
- ips form key: +232.8% with A/A 3.09% (best base 803.8k / 829.0k, candidate 2.72M)
- ips form value: +321.2% with A/A 0.15% (best base 686.2k / 685.2k, candidate 2.89M)
- ips cookie: +117.7% with A/A 2.49% (best base 502.6k / 515.3k, candidate 1.11M)
- wall hello: −35.1% [−35.5%, −34.4%] with A/A +0.4% [−1.0%, +1.3%] (211879 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −72.7% [−73.0%, −72.4%] with A/A −0.3% [−2.6%, +1.3%] (48221 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −80.4% [−80.6%, −80.3%] with A/A −0.4% [−1.0%, +0.8%] (42666 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −57.3% [−58.0%, −56.5%] with A/A +0.7% [−1.6%, +3.3%] (27157 calls × 30 windows per process), JIT-flat in 90 processes
