Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 983,299 | 787,501 | −19.9% |
| `attributes_for_database` | 4 | 2 | 536,862 | 341,451 | −36.4% |
| `attributes_before_type_cast` | 4 | 1 | 407,575 | 233,421 | −42.7% |
| `MessagePack dump` | 19 | 17 | 583,699 | 388,389 | −33.5% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-w102-2026-11-27.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at f70d3e0917
- interp Marshal.dump: instructions −19.9% with A/A 0.03% (base 983,461 / 983,137, candidate 787,501)
- interp attributes_for_database: instructions −36.4% with A/A 0.03% (base 536,769 / 536,955, candidate 341,451)
- interp attributes_before_type_cast: instructions −42.7% with A/A 0.07% (base 407,726 / 407,425, candidate 233,421)
- interp MessagePack dump: instructions −33.5% with A/A 0.01% (base 583,656 / 583,742, candidate 388,389)
