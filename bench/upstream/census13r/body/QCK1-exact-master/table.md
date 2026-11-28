Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 50 | 50 | 326,774 | 317,250 | −2.9% |
| `find, hit` | 38 | 38 | 249,990 | 240,434 | −3.8% |
| `where with 3 binds, miss` | 89 | 89 | 615,143 | 603,492 | −1.9% |
| `where with 3 binds, hit` | 77 | 77 | 553,734 | 543,139 | −1.9% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 50 | 50 | 146,836 | 138,649 | −5.6% |
| `find, hit` | 38 | 38 | 119,784 | 112,013 | −6.5% |
| `where with 3 binds, miss` | 90 | 90 | 251,897 | 241,771 | −4.0% |
| `where with 3 binds, hit` | 78 | 78 | 225,783 | 216,580 | −4.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/w/bench-out/QCK1c-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- interp find, miss: instructions −2.9% with A/A 0.00% (base 326,780 / 326,768, candidate 317,250)
- interp find, hit: instructions −3.8% with A/A 0.02% (base 250,010 / 249,971, candidate 240,434)
- interp where with 3 binds, miss: instructions −1.9% with A/A 0.08% (base 614,900 / 615,386, candidate 603,492)
- interp where with 3 binds, hit: instructions −1.9% with A/A 0.03% (base 553,645 / 553,823, candidate 543,139)
- zjit find, miss: instructions −5.6% with A/A 0.14% (base 146,730 / 146,943, candidate 138,649), JIT-flat in 6 windows
- zjit find, hit: instructions −6.5% with A/A 0.12% (base 119,853 / 119,715, candidate 112,013), JIT-flat in 6 windows
- zjit where with 3 binds, miss: instructions −4.0% with A/A 0.02% (base 251,869 / 251,926, candidate 241,771), JIT-flat in 6 windows
- zjit where with 3 binds, hit: instructions −4.1% with A/A 0.01% (base 225,798 / 225,769, candidate 216,580), JIT-flat in 6 windows
