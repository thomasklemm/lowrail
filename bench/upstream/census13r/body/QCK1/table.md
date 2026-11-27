Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 52 | 52 | 321,182 | 312,662 | −2.7% |
| `find, hit` | 38 | 38 | 244,840 | 235,672 | −3.7% |
| `where with 3 binds, miss` | 91 | 91 | 604,053 | 592,998 | −1.8% |
| `where with 3 binds, hit` | 77 | 77 | 540,910 | 529,898 | −2.0% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 52 | 52 | 158,768 | 151,334 | not JIT-flat, no claim |
| `find, hit` | 38 | 38 | 124,415 | 115,390 | −7.3% |
| `where with 3 binds, miss` | 93 | 93 | 263,528 | 250,121 | not JIT-flat, no claim |
| `where with 3 binds, hit` | 79 | 79 | 230,395 | 215,883 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at b41aaa307b
- interp find, miss: instructions −2.7% with A/A 0.05% (base 321,100 / 321,265, candidate 312,662)
- interp find, hit: instructions −3.7% with A/A 0.00% (base 244,845 / 244,836, candidate 235,672)
- interp where with 3 binds, miss: instructions −1.8% with A/A 0.02% (base 604,127 / 603,979, candidate 592,998)
- interp where with 3 binds, hit: instructions −2.0% with A/A 0.00% (base 540,908 / 540,912, candidate 529,898)
- yjit find, miss: instructions −4.7% with A/A 0.03% (base 158,796 / 158,741, candidate 151,334): not JIT-flat (candidate n2000 compiled_block_count +7), no claim
- yjit find, hit: instructions −7.3% with A/A 0.15% (base 124,507 / 124,324, candidate 115,390), JIT-flat in 6 windows
- yjit where with 3 binds, miss: instructions −5.1% with A/A 0.02% (base 263,499 / 263,558, candidate 250,121): not JIT-flat (base n2000 compiled_iseq_count +1, base n2000 compiled_block_count +1), no claim
- yjit where with 3 binds, hit: instructions −6.3% with A/A 0.19% (base 230,609 / 230,180, candidate 215,883): not JIT-flat (base n2000 compiled_block_count +7), no claim
