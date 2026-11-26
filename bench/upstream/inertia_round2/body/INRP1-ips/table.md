benchmark-ips, Ruby 4.0.9, YJIT, best of 9 on one core

| | v3.24.0 | branch | Change |
| --- | ---: | ---: | ---: |
| `action_xhr` | 4.0k i/s | 4.0k i/s | within noise |
| `action_dashboard_xhr` | 3.7k i/s | 3.8k i/s | +3.1% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/inertia_round2/body/INRP1-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-main at 5102d8dba7
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-pp at f934e7c3b2
- ips action_xhr: −0.4% with A/A 1.53% (best base 4.0k / 4.0k, candidate 4.0k), JIT-flat in 27 windows: inside the A/A, no claim
- ips action_dashboard_xhr: +3.1% with A/A 1.50% (best base 3.8k / 3.7k, candidate 3.8k), JIT-flat in 27 windows
