Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read 5 keys as methods` | 5 | 0 | 23,475 | 23,169 | −1.3% |
| `auth.info.email, auth.uid` | 3 | 0 | 14,226 | 14,053 | −1.2% |
| `description = and private?` | 11 | 10 | 28,909 | 28,840 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read 5 keys as methods` | 5 | 0 | 13,441 | 13,092 | −2.6% |
| `auth.info.email, auth.uid` | 3 | 0 | 8,240 | 8,018 | −2.7% |
| `description = and private?` | 11 | 10 | 16,082 | 16,071 | within noise |

Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read 5 keys as methods` | 1.20 µs | 1.15 µs | −3.5% |
| `auth.info.email, auth.uid` | 0.75 µs | 0.72 µs | −4.1% |
| `description = and private?` | 2.05 µs | 2.03 µs | −0.5% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/body/HM3.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-mm at 202c478705
- interp read 5 keys as methods: instructions −1.3% with A/A 0.17% (base 23,455 / 23,495, candidate 23,169)
- interp auth.info.email, auth.uid: instructions −1.2% with A/A 0.03% (base 14,228 / 14,224, candidate 14,053)
- interp description = and private?: instructions −0.2% with A/A 0.31% (base 28,865 / 28,953, candidate 28,840): inside the A/A, no claim
- yjit read 5 keys as methods: instructions −2.6% with A/A 0.09% (base 13,435 / 13,447, candidate 13,092), JIT-flat in 6 windows
- yjit auth.info.email, auth.uid: instructions −2.7% with A/A 0.10% (base 8,244 / 8,236, candidate 8,018), JIT-flat in 6 windows
- yjit description = and private?: instructions −0.1% with A/A 0.20% (base 16,066 / 16,098, candidate 16,071), JIT-flat in 6 windows: inside the A/A, no claim
- wall read 5 keys as methods: −3.5% [−4.2%, −3.2%] with A/A −0.2% [−0.9%, +0.6%] (41648 calls × 30 windows per process), JIT-flat in 60 processes
- wall auth.info.email, auth.uid: −4.1% [−4.8%, −2.3%] with A/A −0.2% [−2.9%, +1.3%] (68476 calls × 30 windows per process), JIT-flat in 60 processes
- wall description = and private?: −0.5% [−0.9%, −0.2%] with A/A −0.1% [−0.7%, +0.5%] (24475 calls × 30 windows per process), JIT-flat in 60 processes
