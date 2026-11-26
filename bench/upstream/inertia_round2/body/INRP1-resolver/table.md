Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, v3.24.0 | Objects, branch | Instructions, v3.24.0 | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dashboard props` | 118 | 90 | 284,304 | 244,950 | −13.8% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, v3.24.0 | Objects, branch | Instructions, v3.24.0 | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dashboard props` | 118 | 90 | 145,461 | 110,458 | −24.1% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/inertia_round2/body/INRP1-resolver.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-main at 5102d8dba7
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/inr-pp at 0362ffcb1f
- interp dashboard props: instructions −13.8% with A/A 0.03% (base 284,353 / 284,255, candidate 244,950)
- yjit dashboard props: instructions −24.1% with A/A 0.00% (base 145,460 / 145,462, candidate 110,458), JIT-flat in 6 windows
