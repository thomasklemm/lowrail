Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `lease_connection` | – | – | 14,465 | 13,201 | −8.7% |
| `with_connection` | 0 | 0 | 15,559 | 14,272 | −8.3% |
| `has_many reset/load` | 119 | 119 | 737,424 | 731,248 | −0.8% |
| `has_one reset/load` | 99 | 99 | 610,958 | 604,654 | −1.0% |
| `belongs_to reset/load` | 99 | 99 | 582,805 | 577,176 | −1.0% |
| `joins to_sql` | 102 | 102 | 351,221 | 349,004 | −0.6% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `lease_connection` | 0 | 0 | 7,012 | 6,283 | not JIT-flat, no claim |
| `with_connection` | 0 | 0 | 8,007 | 7,271 | not JIT-flat, no claim |
| `has_many reset/load` | 119 | 119 | 289,576 | 286,127 | not JIT-flat, no claim |
| `has_one reset/load` | 99 | 99 | 254,957 | 251,837 | not JIT-flat, no claim |
| `belongs_to reset/load` | 99 | 99 | 247,678 | 244,633 | not JIT-flat, no claim |
| `joins to_sql` | 102 | 102 | 137,271 | 135,843 | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census11/body/LR1-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.1.0dev (2026-11-25T11:44:00Z HEAD e8167b0ddd) +PRISM [x86_64-linux], /home/user/lr1/rails-base at cf0325a832
- candidate: ruby 4.1.0dev (2026-11-25T11:44:00Z HEAD e8167b0ddd) +PRISM [x86_64-linux], /home/user/lr1/rails-head at 7e342de11f
- interp lease_connection: objects differ between the two base runs (0, 0)
- interp lease_connection: instructions −8.7% with A/A 0.04% (base 14,462 / 14,468, candidate 13,201)
- interp with_connection: instructions −8.3% with A/A 0.03% (base 15,557 / 15,561, candidate 14,272)
- interp has_many reset/load: instructions −0.8% with A/A 0.04% (base 737,295 / 737,553, candidate 731,248)
- interp has_one reset/load: instructions −1.0% with A/A 0.04% (base 610,843 / 611,073, candidate 604,654)
- interp belongs_to reset/load: instructions −1.0% with A/A 0.04% (base 582,697 / 582,913, candidate 577,176)
- interp joins to_sql: instructions −0.6% with A/A 0.05% (base 351,131 / 351,311, candidate 349,004)
- zjit lease_connection: instructions −10.4% with A/A 0.06% (base 7,014 / 7,010, candidate 6,283): not JIT-flat (base n0 invalidation_count missing, base n2000 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit with_connection: instructions −9.2% with A/A 0.02% (base 8,006 / 8,008, candidate 7,271): not JIT-flat (base n0 invalidation_count missing, base n2000 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit has_many reset/load: instructions −1.2% with A/A 0.29% (base 289,994 / 289,159, candidate 286,127): not JIT-flat (base n0 invalidation_count missing, base n2000 compiled_iseq_count +1, base n2000 compiled_side_exit_count +8, …), no claim
- zjit has_one reset/load: instructions −1.2% with A/A 0.05% (base 255,015 / 254,900, candidate 251,837): not JIT-flat (base n0 compiled_iseq_count +1, base n0 compiled_side_exit_count +2, base n0 invalidation_count missing, …), no claim
- zjit belongs_to reset/load: instructions −1.2% with A/A 0.10% (base 247,554 / 247,802, candidate 244,633): not JIT-flat (base n0 compiled_iseq_count +1, base n0 compiled_side_exit_count +2, base n0 invalidation_count missing, …), no claim
- zjit joins to_sql: instructions −1.0% with A/A 0.03% (base 137,250 / 137,292, candidate 135,843): not JIT-flat (base n0 invalidation_count missing, base n2000 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
