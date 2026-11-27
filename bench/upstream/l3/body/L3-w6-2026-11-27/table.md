Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | – | – | 96,710 | 82,635 | −14.6% |
| `attributes_for_database` | 4 | 2 | 35,573 | 21,379 | −39.9% |
| `attributes_before_type_cast` | 4 | 1 | 28,482 | 14,309 | −49.8% |
| `MessagePack dump` | 19 | 17 | 58,868 | 44,638 | −24.2% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-w6-2026-11-27.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at f70d3e0917
- interp Marshal.dump: objects differ between the two base runs (16, 16)
- interp Marshal.dump: instructions −14.6% with A/A 0.01% (base 96,707 / 96,713, candidate 82,635)
- interp attributes_for_database: instructions −39.9% with A/A 0.01% (base 35,570 / 35,575, candidate 21,379)
- interp attributes_before_type_cast: instructions −49.8% with A/A 0.02% (base 28,480 / 28,485, candidate 14,309)
- interp MessagePack dump: instructions −24.2% with A/A 0.04% (base 58,879 / 58,858, candidate 44,638)
