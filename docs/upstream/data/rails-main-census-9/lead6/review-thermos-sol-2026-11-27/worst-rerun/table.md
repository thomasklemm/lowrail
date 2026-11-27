Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, head | Instructions, main | Instructions, head | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `unknown String name` | 1 | 1 | 3,484 | 3,242 | −7.0% |
| `nil name` | 1 | 1 | 3,425 | 3,183 | −7.1% |
| `cached String name` | 0 | 0 | 1,990 | 1,401 | −29.6% |
| `partial select missing slot` | 0 | 0 | 1,990 | 1,401 | −29.6% |
| `empty keys` | 1 | 1 | 2,005 | 2,005 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, head | Instructions, main | Instructions, head | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `unknown String name` | 1 | 1 | 1,725 | 1,671 | −3.1% |
| `nil name` | 1 | 1 | 1,673 | 1,620 | −3.1% |
| `cached String name` | 0 | 0 | 1,270 | 1,119 | −11.9% |
| `partial select missing slot` | 0 | 0 | 1,269 | 1,121 | −11.7% |
| `empty keys` | 1 | 1 | 1,412 | 1,412 | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/docs/upstream/data/rails-main-census-9/lead6/review-thermos-sol-2026-11-27/worst-rerun.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/base at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/head at 8b1c6428ea
- interp unknown String name: instructions −7.0% with A/A 0.06% (base 3,483 / 3,485, candidate 3,242)
- interp nil name: instructions −7.1% with A/A 0.06% (base 3,426 / 3,424, candidate 3,183)
- interp cached String name: instructions −29.6% with A/A 0.00% (base 1,990 / 1,990, candidate 1,401)
- interp partial select missing slot: instructions −29.6% with A/A 0.00% (base 1,990 / 1,990, candidate 1,401)
- interp empty keys: instructions +0.0% with A/A 0.00% (base 2,005 / 2,005, candidate 2,005): inside the A/A, no claim
- yjit unknown String name: instructions −3.1% with A/A 0.00% (base 1,725 / 1,725, candidate 1,671), JIT-flat in 6 windows
- yjit nil name: instructions −3.1% with A/A 0.06% (base 1,672 / 1,673, candidate 1,620), JIT-flat in 6 windows
- yjit cached String name: instructions −11.9% with A/A 0.00% (base 1,270 / 1,270, candidate 1,119), JIT-flat in 6 windows
- yjit partial select missing slot: instructions −11.7% with A/A 0.16% (base 1,270 / 1,268, candidate 1,121), JIT-flat in 6 windows
- yjit empty keys: instructions +0.0% with A/A 0.00% (base 1,412 / 1,412, candidate 1,412), JIT-flat in 6 windows: inside the A/A, no claim
