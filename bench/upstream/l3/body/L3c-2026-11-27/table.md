Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 319,622 | 268,058 | −16.1% |
| `attributes_for_database` | 4 | 2 | 161,606 | 110,739 | −31.5% |
| `attributes_before_type_cast` | 4 | 2 | 124,089 | 74,278 | −40.1% |
| `MessagePack dump` | 19 | 17 | 190,789 | 139,355 | −27.0% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 259,698 | 215,645 | −17.0% |
| `attributes_for_database` | 4 | 2 | 107,006 | 63,174 | −41.0% |
| `attributes_before_type_cast` | 4 | 2 | 95,368 | 52,537 | −44.9% |
| `MessagePack dump` | 19 | 17 | 130,232 | 86,191 | −33.8% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3c-2026-11-27.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/w/l3 at 319e55a661
- interp Marshal.dump: instructions −16.1% with A/A 0.03% (base 319,678 / 319,567, candidate 268,058)
- interp attributes_for_database: instructions −31.5% with A/A 0.04% (base 161,636 / 161,576, candidate 110,739)
- interp attributes_before_type_cast: instructions −40.1% with A/A 0.00% (base 124,091 / 124,087, candidate 74,278)
- interp MessagePack dump: instructions −27.0% with A/A 0.01% (base 190,798 / 190,780, candidate 139,355)
- yjit Marshal.dump: instructions −17.0% with A/A 0.00% (base 259,702 / 259,694, candidate 215,645), JIT-flat in 6 windows
- yjit attributes_for_database: instructions −41.0% with A/A 0.02% (base 106,993 / 107,019, candidate 63,174), JIT-flat in 6 windows
- yjit attributes_before_type_cast: instructions −44.9% with A/A 0.16% (base 95,445 / 95,290, candidate 52,537), JIT-flat in 6 windows
- yjit MessagePack dump: instructions −33.8% with A/A 0.35% (base 130,003 / 130,461, candidate 86,191), JIT-flat in 6 windows
