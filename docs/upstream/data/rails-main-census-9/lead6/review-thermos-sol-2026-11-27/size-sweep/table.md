Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, head | Instructions, main | Instructions, head | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `keys 0 full raw row` | 1 | 1 | 2,224 | 2,224 | within noise |
| `keys 0 absent row` | 1 | 1 | 2,224 | 2,224 | within noise |
| `keys 1 full raw row` | 1 | 1 | 4,708 | 4,190 | −11.0% |
| `keys 1 absent row` | 1 | 1 | 4,112 | 3,598 | −12.5% |
| `keys 30 full raw row` | 1 | 1 | 69,555 | 57,317 | −17.6% |
| `keys 30 absent row` | 1 | 1 | 53,424 | 41,041 | −23.2% |
| `keys 102 full raw row` | 1 | 1 | 230,377 | 188,500 | −18.2% |
| `keys 102 absent row` | 1 | 1 | 175,387 | 133,563 | −23.8% |
| `keys 32768 full raw row` | 1 | 1 | 73,433,414 | 60,026,619 | −18.3% |
| `keys 32768 absent row` | 1 | 1 | 55,819,301 | 42,421,639 | −24.0% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/docs/upstream/data/rails-main-census-9/lead6/review-thermos-sol-2026-11-27/size-sweep.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/base at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/head at 8b1c6428ea
- interp keys 0 full raw row: instructions +0.0% with A/A 0.00% (base 2,224 / 2,224, candidate 2,224): inside the A/A, no claim
- interp keys 0 absent row: instructions +0.0% with A/A 0.00% (base 2,224 / 2,224, candidate 2,224): inside the A/A, no claim
- interp keys 1 full raw row: instructions −11.0% with A/A 0.04% (base 4,707 / 4,709, candidate 4,190)
- interp keys 1 absent row: instructions −12.5% with A/A 0.00% (base 4,112 / 4,112, candidate 3,598)
- interp keys 30 full raw row: instructions −17.6% with A/A 0.14% (base 69,507 / 69,603, candidate 57,317)
- interp keys 30 absent row: instructions −23.2% with A/A 0.08% (base 53,402 / 53,446, candidate 41,041)
- interp keys 102 full raw row: instructions −18.2% with A/A 0.02% (base 230,358 / 230,397, candidate 188,500)
- interp keys 102 absent row: instructions −23.8% with A/A 0.02% (base 175,402 / 175,372, candidate 133,563)
- interp keys 32768 full raw row: instructions −18.3% with A/A 0.00% (base 73,431,610 / 73,435,217, candidate 60,026,619)
- interp keys 32768 absent row: instructions −24.0% with A/A 0.01% (base 55,817,578 / 55,821,024, candidate 42,421,639)
