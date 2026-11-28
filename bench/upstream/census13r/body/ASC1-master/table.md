Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `belongs_to load` | 92 | 92 | 522,844 | 507,067 | −3.0% |
| `has_one load` | 92 | 92 | 557,646 | 541,693 | −2.9% |
| `has_many load` | 112 | 112 | 686,596 | 669,456 | −2.5% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `belongs_to load` | 92 | 92 | 217,353 | 212,702 | not JIT-flat, no claim |
| `has_one load` | 92 | 92 | 229,736 | 225,706 | not JIT-flat, no claim |
| `has_many load` | 112 | 112 | 260,460 | 256,304 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in bench/upstream/census13r/body/ASC1-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at ed1b28c5b9
- interp belongs_to load: instructions −3.0% with A/A 0.01% (base 522,858 / 522,829, candidate 507,067)
- interp has_one load: instructions −2.9% with A/A 0.03% (base 557,722 / 557,570, candidate 541,693)
- interp has_many load: instructions −2.5% with A/A 0.02% (base 686,666 / 686,525, candidate 669,456)
- zjit belongs_to load: instructions −2.1% with A/A 0.33% (base 216,991 / 217,714, candidate 212,702): not JIT-flat (base2 n2000 compiled_iseq_count +1, base2 n2000 compiled_side_exit_count +6), no claim
- zjit has_one load: instructions −1.8% with A/A 0.14% (base 229,897 / 229,575, candidate 225,706): not JIT-flat (candidate n2000 compiled_iseq_count +2, candidate n2000 compiled_side_exit_count +35), no claim
- zjit has_many load: instructions −1.6% with A/A 0.05% (base 260,524 / 260,395, candidate 256,304): not JIT-flat (candidate n2000 compiled_iseq_count +2, candidate n2000 compiled_side_exit_count +15), no claim
