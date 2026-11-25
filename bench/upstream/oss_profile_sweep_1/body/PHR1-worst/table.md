Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `every key a target length` | 159 | 160 | 297,651 | 364,752 | +22.5% |
| `every key non-ASCII` | 232 | 233 | 508,269 | 545,054 | +7.2% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/PHR1-worst.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby-main at 27fbf08b5a
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/posthog-ruby at a58f8d2022
- interp every key a target length: instructions +22.5% with A/A 0.00% (base 297,650 / 297,652, candidate 364,752)
- interp every key non-ASCII: instructions +7.2% with A/A 0.00% (base 508,260 / 508,279, candidate 545,054)
