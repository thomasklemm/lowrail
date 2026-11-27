Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `update! of one column` | – | – | 2,460,339 | 2,269,276 | −7.8% |
| `find, then changed?` | 186 | 186 | 1,832,522 | 1,731,697 | −5.5% |
| `serializable_hash` | 104 | 104 | 642,937 | 601,183 | −6.5% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead6/body/L6-w102-2026-11-27.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l6 at 8b1c6428ea
- interp update! of one column: objects differ between the two base runs (280, 280)
- interp update! of one column: instructions −7.8% with A/A 0.01% (base 2,460,519 / 2,460,159, candidate 2,269,276)
- interp find, then changed?: instructions −5.5% with A/A 0.03% (base 1,832,221 / 1,832,823, candidate 1,731,697)
- interp serializable_hash: instructions −6.5% with A/A 0.03% (base 642,849 / 643,026, candidate 601,183)
