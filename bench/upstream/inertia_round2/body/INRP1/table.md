Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, v3.24.0 | Objects, branch | Instructions, v3.24.0 | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `action_xhr` | 379 | 372 | 1,631,687 | 1,633,428 | within noise |
| `action_dashboard_xhr` | 449 | 421 | 1,492,966 | 1,451,733 | −2.8% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, v3.24.0 | Objects, branch | Instructions, v3.24.0 | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `action_xhr` | 381 | 374 | 942,691 | 936,509 | −0.7% |
| `action_dashboard_xhr` | 451 | 423 | 864,446 | 831,213 | −3.8% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/inertia_round2/body/INRP1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-main at 5102d8dba7
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-pp at f934e7c3b2
- interp action_xhr: instructions +0.1% with A/A 1.10% (base 1,622,719 / 1,640,655, candidate 1,633,428): inside the A/A, no claim
- interp action_dashboard_xhr: instructions −2.8% with A/A 0.01% (base 1,492,899 / 1,493,033, candidate 1,451,733)
- yjit action_xhr: instructions −0.7% with A/A 0.15% (base 943,383 / 941,999, candidate 936,509), JIT-flat in 6 windows
- yjit action_dashboard_xhr: instructions −3.8% with A/A 0.44% (base 862,543 / 866,349, candidate 831,213), JIT-flat in 6 windows
