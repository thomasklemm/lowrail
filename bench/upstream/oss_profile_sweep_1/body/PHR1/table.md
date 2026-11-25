Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `RequestContext#call (73 env keys)` | 369 | 93 | 746,853 | 455,123 | −39.1% |
| `extract_header, header absent` | 161 | 26 | 313,155 | 172,279 | −45.0% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `RequestContext#call (73 env keys)` | 369 | 93 | 543,683 | 265,749 | −51.1% |
| `extract_header, header absent` | 161 | 26 | 237,109 | 101,592 | −57.2% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/PHR1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby-main at 27fbf08b5a
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby at 7e9d743671
- interp RequestContext#call (73 env keys): instructions −39.1% with A/A 0.01% (base 746,813 / 746,893, candidate 455,123)
- interp extract_header, header absent: instructions −45.0% with A/A 0.02% (base 313,192 / 313,118, candidate 172,279)
- yjit RequestContext#call (73 env keys): instructions −51.1% with A/A 0.04% (base 543,586 / 543,781, candidate 265,749), JIT-flat in 6 windows
- yjit extract_header, header absent: instructions −57.2% with A/A 0.06% (base 237,035 / 237,183, candidate 101,592), JIT-flat in 6 windows
