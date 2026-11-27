Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | – | – | 319,455 | 259,947 | −18.6% |
| `attributes_for_database` | 4 | 2 | 161,916 | 102,716 | −36.6% |
| `attributes_before_type_cast` | 4 | 2 | 124,061 | 65,797 | −47.0% |
| `MessagePack dump` | 19 | 17 | 190,762 | 131,188 | −31.2% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 259,976 | 213,977 | −17.7% |
| `attributes_for_database` | 4 | 2 | 107,019 | 61,088 | −42.9% |
| `attributes_before_type_cast` | 4 | 2 | 95,748 | 51,169 | −46.6% |
| `MessagePack dump` | 19 | 17 | 130,282 | 84,461 | −35.2% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3b-2026-11-27.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at 41af869c78
- interp Marshal.dump: objects differ between the two base runs (16, 16)
- interp Marshal.dump: instructions −18.6% with A/A 0.04% (base 319,387 / 319,524, candidate 259,947)
- interp attributes_for_database: instructions −36.6% with A/A 0.14% (base 162,029 / 161,803, candidate 102,716)
- interp attributes_before_type_cast: instructions −47.0% with A/A 0.03% (base 124,040 / 124,082, candidate 65,797)
- interp MessagePack dump: instructions −31.2% with A/A 0.08% (base 190,691 / 190,834, candidate 131,188)
- yjit Marshal.dump: instructions −17.7% with A/A 0.03% (base 259,932 / 260,020, candidate 213,977), JIT-flat in 6 windows
- yjit attributes_for_database: instructions −42.9% with A/A 0.15% (base 107,098 / 106,940, candidate 61,088), JIT-flat in 6 windows
- yjit attributes_before_type_cast: instructions −46.6% with A/A 0.59% (base 96,029 / 95,466, candidate 51,169), JIT-flat in 6 windows
- yjit MessagePack dump: instructions −35.2% with A/A 0.09% (base 130,339 / 130,224, candidate 84,461), JIT-flat in 6 windows
