Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 52 | 52 | 321,528 | 313,180 | −2.6% |
| `find, hit` | 38 | 38 | 244,646 | 236,628 | −3.3% |
| `where with 3 binds, miss` | 91 | 91 | 604,020 | 593,785 | −1.7% |
| `where with 3 binds, hit` | 77 | 77 | 540,763 | 530,792 | −1.8% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 52 | 52 | 158,705 | 151,599 | −4.5% |
| `find, hit` | 38 | 38 | 124,997 | 117,221 | not JIT-flat, no claim |
| `where with 3 binds, miss` | 93 | 93 | 263,418 | 254,206 | −3.5% |
| `where with 3 binds, hit` | 79 | 79 | 230,007 | 220,634 | −4.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in bench/upstream/census13r/body/QCK1c.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- interp find, miss: instructions −2.6% with A/A 0.01% (base 321,551 / 321,505, candidate 313,180)
- interp find, hit: instructions −3.3% with A/A 0.01% (base 244,637 / 244,654, candidate 236,628)
- interp where with 3 binds, miss: instructions −1.7% with A/A 0.04% (base 604,131 / 603,909, candidate 593,785)
- interp where with 3 binds, hit: instructions −1.8% with A/A 0.05% (base 540,615 / 540,911, candidate 530,792)
- yjit find, miss: instructions −4.5% with A/A 0.12% (base 158,611 / 158,798, candidate 151,599), JIT-flat in 6 windows
- yjit find, hit: instructions −6.2% with A/A 1.04% (base 124,347 / 125,647, candidate 117,221): not JIT-flat (base2 n2000 compiled_block_count +28), no claim
- yjit where with 3 binds, miss: instructions −3.5% with A/A 0.02% (base 263,450 / 263,385, candidate 254,206), JIT-flat in 6 windows
- yjit where with 3 binds, hit: instructions −4.1% with A/A 0.10% (base 230,127 / 229,886, candidate 220,634), JIT-flat in 6 windows
