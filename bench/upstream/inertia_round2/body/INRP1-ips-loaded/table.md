benchmark-ips, Ruby 4.0.9, YJIT, best of 5 on one core

| | v3.24.0 | branch | Change |
| --- | ---: | ---: | ---: |
| `action_xhr` | 3.6k i/s | 3.7k i/s | +4.4% |
| `action_dashboard_xhr` | 3.5k i/s | 3.6k i/s | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/inertia_round2/body/INRP1-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-main at 5102d8dba7
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-pp at f934e7c3b2
- ips action_xhr: +4.4% with A/A 0.73% (best base 3.5k / 3.6k, candidate 3.7k), JIT-flat in 15 windows
- ips action_dashboard_xhr: +1.6% with A/A 5.56% (best base 3.6k / 3.4k, candidate 3.6k), JIT-flat in 15 windows: inside the A/A, no claim
