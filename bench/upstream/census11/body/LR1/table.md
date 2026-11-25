Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `lease_connection` | 0 | 0 | 14,215 | 12,905 | −9.2% |
| `with_connection` | 0 | 0 | 15,340 | 14,041 | −8.5% |
| `has_many reset/load` | 121 | 121 | 717,925 | 712,157 | −0.8% |
| `has_one reset/load` | 101 | 101 | 597,788 | 591,717 | −1.0% |
| `belongs_to reset/load` | 101 | 101 | 571,660 | 565,603 | −1.1% |
| `joins to_sql` | 106 | 106 | 355,262 | 352,581 | −0.8% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `lease_connection` | 0 | 0 | 5,682 | 4,897 | −13.8% |
| `with_connection` | 0 | 0 | 6,103 | 5,308 | −13.0% |
| `has_many reset/load` | 123 | 123 | 309,067 | 304,899 | not JIT-flat, no claim |
| `has_one reset/load` | 103 | 103 | 258,429 | 255,194 | not JIT-flat, no claim |
| `belongs_to reset/load` | 103 | 103 | 258,586 | 255,366 | not JIT-flat, no claim |
| `joins to_sql` | 107 | 107 | 147,607 | 143,865 | not JIT-flat, no claim |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `lease_connection` | 1.51M i/s | 2.02M i/s | +33.4% |
| `with_connection` | 1.35M i/s | 1.81M i/s | not JIT-flat, no claim |
| `has_many reset/load` | 13.5k i/s | 13.6k i/s | within noise |
| `has_one reset/load` | 14.2k i/s | 14.8k i/s | +4.6% |
| `belongs_to reset/load` | 14.6k i/s | 15.2k i/s | +3.6% |
| `joins to_sql` | 32.5k i/s | 32.8k i/s | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census11/body/LR1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/lr1/rails-base at cf0325a832
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/lr1/rails-head at 7e342de11f
- interp lease_connection: instructions −9.2% with A/A 0.10% (base 14,208 / 14,222, candidate 12,905)
- interp with_connection: instructions −8.5% with A/A 0.03% (base 15,338 / 15,342, candidate 14,041)
- interp has_many reset/load: instructions −0.8% with A/A 0.03% (base 717,805 / 718,044, candidate 712,157)
- interp has_one reset/load: instructions −1.0% with A/A 0.05% (base 597,923 / 597,653, candidate 591,717)
- interp belongs_to reset/load: instructions −1.1% with A/A 0.06% (base 571,497 / 571,824, candidate 565,603)
- interp joins to_sql: instructions −0.8% with A/A 0.05% (base 355,355 / 355,168, candidate 352,581)
- yjit lease_connection: instructions −13.8% with A/A 0.12% (base 5,678 / 5,685, candidate 4,897), JIT-flat in 6 windows
- yjit with_connection: instructions −13.0% with A/A 0.00% (base 6,103 / 6,103, candidate 5,308), JIT-flat in 6 windows
- yjit has_many reset/load: instructions −1.3% with A/A 0.77% (base 310,264 / 307,869, candidate 304,899): not JIT-flat (base n2000 compiled_block_count +43, candidate n2000 compiled_block_count +4, base2 n2000 compiled_block_count +2), no claim
- yjit has_one reset/load: instructions −1.3% with A/A 0.01% (base 258,445 / 258,413, candidate 255,194): not JIT-flat (base n0 compiled_block_count +1, base n2000 compiled_block_count +7, candidate n0 compiled_block_count +1, …), no claim
- yjit belongs_to reset/load: instructions −1.2% with A/A 0.29% (base 258,209 / 258,964, candidate 255,366): not JIT-flat (base n0 compiled_block_count +1, base n2000 compiled_block_count +1, candidate n0 compiled_block_count +1, …), no claim
- yjit joins to_sql: instructions −2.5% with A/A 0.92% (base 148,288 / 146,926, candidate 143,865): not JIT-flat (base2 n2000 compiled_block_count +25), no claim
- ips lease_connection: +33.4% with A/A 11.70% (best base 1.42M / 1.60M, candidate 2.02M), JIT-flat in 9 windows
- ips with_connection: +34.1% with A/A 2.74% (best base 1.33M / 1.37M, candidate 1.81M): not JIT-flat (r1 base compiled_block_count +6, r1 candidate compiled_block_count +6, r1 base2 compiled_block_count +6, …), no claim
- ips has_many reset/load: +0.9% with A/A 2.19% (best base 13.3k / 13.6k, candidate 13.6k), JIT-flat in 9 windows: inside the A/A, no claim
- ips has_one reset/load: +4.6% with A/A 0.88% (best base 14.1k / 14.2k, candidate 14.8k), JIT-flat in 9 windows
- ips belongs_to reset/load: +3.6% with A/A 1.93% (best base 14.8k / 14.5k, candidate 15.2k), JIT-flat in 9 windows
- ips joins to_sql: +0.8% with A/A 3.34% (best base 33.1k / 32.0k, candidate 32.8k): not JIT-flat (r1 base compiled_block_count +41, r1 candidate compiled_block_count +39, r1 base2 compiled_block_count +34, …), no claim
