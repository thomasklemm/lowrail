Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `update! of one column` | – | – | 1,456,136 | 1,395,418 | −4.2% |
| `find, then changed?` | 90 | 90 | 712,038 | 681,893 | −4.2% |
| `serializable_hash` | 32 | 32 | 191,400 | 178,771 | −6.6% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `update! of one column` | – | – | 685,646 | 670,801 | −2.2% |
| `find, then changed?` | 90 | 90 | 359,805 | 351,096 | −2.4% |
| `serializable_hash` | 32 | 32 | 195,191 | 191,768 | −1.8% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead6/body/L6-2026-11-27.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l6 at 8b1c6428ea
- interp update! of one column: objects differ between the two base runs (208, 208)
- interp update! of one column: instructions −4.2% with A/A 0.01% (base 1,456,028 / 1,456,244, candidate 1,395,418)
- interp find, then changed?: instructions −4.2% with A/A 0.04% (base 711,900 / 712,177, candidate 681,893)
- interp serializable_hash: instructions −6.6% with A/A 0.10% (base 191,496 / 191,304, candidate 178,771)
- yjit update! of one column: objects differ between the two base runs (210, 210)
- yjit update! of one column: instructions −2.2% with A/A 0.21% (base 686,369 / 684,922, candidate 670,801), JIT-flat in 6 windows
- yjit find, then changed?: instructions −2.4% with A/A 0.15% (base 360,074 / 359,535, candidate 351,096), JIT-flat in 6 windows
- yjit serializable_hash: instructions −1.8% with A/A 1.23% (base 196,391 / 193,991, candidate 191,768), JIT-flat in 6 windows
