Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `RequestContext#call (73 env keys)` | 369 | 93 | 543,526 | 265,037 | −51.2% |
| `extract_header, header absent` | 161 | 26 | 236,973 | 101,313 | −57.2% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `RequestContext#call (73 env keys)` | 15.2k i/s | 33.6k i/s | +121.5% |
| `extract_header, header absent` | 36.7k i/s | 104.1k i/s | +183.9% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/PHR1-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby-main at 27fbf08b5a
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby at 35428f55b8
- yjit RequestContext#call (73 env keys): instructions −51.2% with A/A 0.03% (base 543,596 / 543,456, candidate 265,037), JIT-flat in 6 windows
- yjit extract_header, header absent: instructions −57.2% with A/A 0.00% (base 236,973 / 236,974, candidate 101,313), JIT-flat in 6 windows
- ips RequestContext#call (73 env keys): +121.5% with A/A 3.39% (best base 14.9k / 15.4k, candidate 33.6k), JIT-flat in 9 windows
- ips extract_header, header absent: +183.9% with A/A 1.51% (best base 36.4k / 37.0k, candidate 104.1k), JIT-flat in 9 windows
