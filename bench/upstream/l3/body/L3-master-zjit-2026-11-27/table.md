Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 16 | 14 | 265,322 | 214,367 | not JIT-flat, no claim |
| `attributes_for_database` | 4 | 2 | 107,662 | 56,646 | not JIT-flat, no claim |
| `attributes_before_type_cast` | 4 | 1 | 96,130 | 48,082 | not JIT-flat, no claim |
| `MessagePack dump` | 19 | 17 | 129,819 | 78,259 | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-master-zjit-2026-11-27.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l3 at f70d3e0917
- zjit Marshal.dump: instructions −19.2% with A/A 0.27% (base 265,682 / 264,962, candidate 214,367): not JIT-flat (base n0 invalidation_count missing, base n500 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit attributes_for_database: instructions −47.4% with A/A 0.00% (base 107,664 / 107,660, candidate 56,646): not JIT-flat (base n0 invalidation_count missing, base n500 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit attributes_before_type_cast: instructions −50.0% with A/A 0.18% (base 96,216 / 96,045, candidate 48,082): not JIT-flat (base n0 invalidation_count missing, base n500 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit MessagePack dump: instructions −39.7% with A/A 0.33% (base 129,605 / 130,034, candidate 78,259): not JIT-flat (base n0 invalidation_count missing, base n500 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
