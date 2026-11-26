benchmark-ips, Ruby 4.0.9, YJIT, best of 9 on one core

| | v3.24.0 | branch | Change |
| --- | ---: | ---: | ---: |
| `dashboard props` | 44.1k i/s | 54.0k i/s | +22.7% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/inertia_round2/body/INRP1-resolver-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-main at 5102d8dba7
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-pp at 0362ffcb1f
- ips dashboard props: +22.7% with A/A 0.40% (best base 44.0k / 44.1k, candidate 54.0k), JIT-flat in 27 windows
