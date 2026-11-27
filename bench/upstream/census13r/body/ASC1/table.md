Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `belongs_to load` | 94 | 94 | 512,155 | 496,346 | −3.1% |
| `has_one load` | 94 | 94 | 546,596 | 530,339 | −3.0% |
| `has_many load` | 114 | 114 | 666,752 | 650,905 | −2.4% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `belongs_to load` | 96 | 96 | 221,766 | 219,189 | not JIT-flat, no claim |
| `has_one load` | 96 | 96 | 228,518 | 224,737 | not JIT-flat, no claim |
| `has_many load` | 116 | 116 | 277,711 | 255,976 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/ASC1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at 23fe1f4b6b
- interp belongs_to load: instructions −3.1% with A/A 0.06% (base 512,313 / 511,998, candidate 496,346)
- interp has_one load: instructions −3.0% with A/A 0.00% (base 546,589 / 546,604, candidate 530,339)
- interp has_many load: instructions −2.4% with A/A 0.05% (base 666,595 / 666,910, candidate 650,905)
- yjit belongs_to load: instructions −1.2% with A/A 3.07% (base 218,367 / 225,166, candidate 219,189): not JIT-flat (base n2000 compiled_block_count +32, base2 n2000 compiled_block_count +6), no claim
- yjit has_one load: instructions −1.7% with A/A 0.06% (base 228,591 / 228,446, candidate 224,737): not JIT-flat (candidate n2000 compiled_block_count +26), no claim
- yjit has_many load: instructions −7.8% with A/A 0.02% (base 277,682 / 277,740, candidate 255,976): not JIT-flat (base n2000 compiled_block_count +22, base2 n2000 compiled_block_count +24), no claim
