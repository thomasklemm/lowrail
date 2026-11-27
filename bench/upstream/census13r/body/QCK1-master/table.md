Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 50 | 50 | 325,675 | 318,467 | −2.2% |
| `find, hit` | 38 | 38 | 249,637 | 241,380 | −3.3% |
| `where with 3 binds, miss` | 89 | 89 | 615,362 | 603,030 | −2.0% |
| `where with 3 binds, hit` | 77 | 77 | 553,026 | 541,922 | −2.0% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, miss` | 50 | 50 | 146,885 | 139,337 | −5.1% |
| `find, hit` | 38 | 38 | 119,898 | 110,946 | −7.5% |
| `where with 3 binds, miss` | 90 | 90 | 252,075 | 241,649 | −4.1% |
| `where with 3 binds, hit` | 78 | 78 | 226,305 | 215,120 | −4.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at e1978ba23b
- interp find, miss: instructions −2.2% with A/A 0.00% (base 325,681 / 325,668, candidate 318,467)
- interp find, hit: instructions −3.3% with A/A 0.05% (base 249,574 / 249,700, candidate 241,380)
- interp where with 3 binds, miss: instructions −2.0% with A/A 0.04% (base 615,484 / 615,239, candidate 603,030)
- interp where with 3 binds, hit: instructions −2.0% with A/A 0.03% (base 552,937 / 553,116, candidate 541,922)
- zjit find, miss: instructions −5.1% with A/A 0.01% (base 146,892 / 146,878, candidate 139,337), JIT-flat in 6 windows
- zjit find, hit: instructions −7.5% with A/A 0.02% (base 119,889 / 119,907, candidate 110,946), JIT-flat in 6 windows
- zjit where with 3 binds, miss: instructions −4.1% with A/A 0.05% (base 252,139 / 252,011, candidate 241,649), JIT-flat in 6 windows
- zjit where with 3 binds, hit: instructions −4.9% with A/A 0.02% (base 226,330 / 226,281, candidate 215,120), JIT-flat in 6 windows
