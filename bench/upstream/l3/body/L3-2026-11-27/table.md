Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 319,572 | 260,103 | −18.6% |
| `attributes_for_database` | 4 | 2 | 161,641 | 102,578 | −36.5% |
| `attributes_before_type_cast` | 4 | 1 | 124,157 | 69,743 | −43.8% |
| `MessagePack dump` | 19 | 17 | 190,579 | 131,109 | −31.2% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 259,729 | 213,668 | −17.7% |
| `attributes_for_database` | 4 | 2 | 107,195 | 61,187 | −42.9% |
| `attributes_before_type_cast` | 4 | 1 | 95,343 | 50,911 | −46.6% |
| `MessagePack dump` | 19 | 17 | 129,953 | 84,046 | −35.3% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-2026-11-27.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at f70d3e0917
- interp Marshal.dump: instructions −18.6% with A/A 0.15% (base 319,809 / 319,336, candidate 260,103)
- interp attributes_for_database: instructions −36.5% with A/A 0.02% (base 161,655 / 161,627, candidate 102,578)
- interp attributes_before_type_cast: instructions −43.8% with A/A 0.11% (base 124,089 / 124,226, candidate 69,743)
- interp MessagePack dump: instructions −31.2% with A/A 0.04% (base 190,620 / 190,537, candidate 131,109)
- yjit Marshal.dump: instructions −17.7% with A/A 0.08% (base 259,625 / 259,834, candidate 213,668), JIT-flat in 6 windows
- yjit attributes_for_database: instructions −42.9% with A/A 0.19% (base 107,298 / 107,093, candidate 61,187), JIT-flat in 6 windows
- yjit attributes_before_type_cast: instructions −46.6% with A/A 0.22% (base 95,236 / 95,449, candidate 50,911), JIT-flat in 6 windows
- yjit MessagePack dump: instructions −35.3% with A/A 0.03% (base 129,931 / 129,975, candidate 84,046), JIT-flat in 6 windows
