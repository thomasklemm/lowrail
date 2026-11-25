Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fresh fiber with_connection` | 13 | 13 | 70,628 | 68,736 | −2.7% |
| `fresh fiber` | 4 | 4 | 5,909 | 5,909 | −0.0% |
| `registry miss, new key` | 2 | 2 | 7,214 | 7,908 | +9.6% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `fresh fiber with_connection` | – | – | 34,140 | 33,462 | −2.0% |
| `fresh fiber` | 4 | 4 | 6,122 | 6,118 | within noise |
| `registry miss, new key` | 2 | 2 | 4,742 | 5,245 | +10.6% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census11/body/LR1-miss.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/lr1/rails-base at cf0325a832
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/lr1/rails-head at 7e342de11f
- interp fresh fiber with_connection: instructions −2.7% with A/A 0.00% (base 70,630 / 70,626, candidate 68,736)
- interp fresh fiber: instructions −0.0% with A/A 0.00% (base 5,909 / 5,909, candidate 5,909)
- interp registry miss, new key: instructions +9.6% with A/A 0.09% (base 7,210 / 7,217, candidate 7,908)
- yjit fresh fiber with_connection: objects differ between the two base runs (13, 13)
- yjit fresh fiber with_connection: instructions −2.0% with A/A 0.04% (base 34,147 / 34,133, candidate 33,462), JIT-flat in 6 windows
- yjit fresh fiber: instructions −0.1% with A/A 0.13% (base 6,126 / 6,118, candidate 6,118), JIT-flat in 6 windows: inside the A/A, no claim
- yjit registry miss, new key: instructions +10.6% with A/A 0.05% (base 4,741 / 4,743, candidate 5,245), JIT-flat in 6 windows
