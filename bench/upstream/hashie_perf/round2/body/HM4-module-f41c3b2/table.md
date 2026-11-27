Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `quiet.new(repository)` | 14.8 | 14.8 | 1,462,954 | 923,202 | −36.9% |
| `quiet.new(auth hash)` | 17.0 | 17.0 | 477,218 | 309,410 | −35.2% |
| `quiet merge` | 13.8 | 13.8 | 1,507,395 | 954,678 | −36.7% |
| `quiet []=` | 0 | 0 | 11,594 | 5,997 | −48.3% |
| `Mash.new(repository)` | 24.8 | 24.8 | 1,481,753 | 1,481,887 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `quiet.new(repository)` | 14.8 | 14.8 | 585,307 | 294,969 | −49.6% |
| `quiet.new(auth hash)` | 17.0 | 17.0 | 188,738 | 100,627 | −46.7% |
| `quiet merge` | 13.8 | 13.8 | 602,038 | 307,435 | −48.9% |
| `quiet []=` | 0 | 0 | 5,093 | 2,289 | −55.1% |
| `Mash.new(repository)` | 28.8 | 28.8 | 605,434 | 729,129 | +20.4% |

Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 64.94 µs | 30.71 µs | −52.7% |
| `quiet.new(auth hash)` | 21.32 µs | 11.12 µs | −47.8% |
| `quiet merge` | 67.29 µs | 32.14 µs | −52.2% |
| `quiet []=` | 0.46 µs | 0.15 µs | within noise |
| `Mash.new(repository)` | 69.65 µs | 82.69 µs | +19.0% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/body/HM4-module-f41c3b2.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at f41c3b2b27
- interp quiet.new(repository): instructions −36.9% with A/A 0.02% (base 1,462,832 / 1,463,076, candidate 923,202)
- interp quiet.new(auth hash): instructions −35.2% with A/A 0.23% (base 477,765 / 476,672, candidate 309,410)
- interp quiet merge: instructions −36.7% with A/A 0.04% (base 1,507,677 / 1,507,113, candidate 954,678)
- interp quiet []=: instructions −48.3% with A/A 0.10% (base 11,588 / 11,600, candidate 5,997)
- interp Mash.new(repository): instructions +0.0% with A/A 0.13% (base 1,482,727 / 1,480,779, candidate 1,481,887): inside the A/A, no claim
- yjit quiet.new(repository): instructions −49.6% with A/A 0.22% (base 585,940 / 584,674, candidate 294,969), JIT-flat in 6 windows
- yjit quiet.new(auth hash): instructions −46.7% with A/A 0.23% (base 188,954 / 188,521, candidate 100,627), JIT-flat in 6 windows
- yjit quiet merge: instructions −48.9% with A/A 0.01% (base 601,994 / 602,082, candidate 307,435), JIT-flat in 6 windows
- yjit quiet []=: instructions −55.1% with A/A 0.08% (base 5,095 / 5,091, candidate 2,289), JIT-flat in 6 windows
- yjit Mash.new(repository): instructions +20.4% with A/A 0.07% (base 605,235 / 605,634, candidate 729,129), JIT-flat in 6 windows
- wall quiet.new(repository): −52.7% [−53.0%, −51.9%] with A/A −0.0% [−0.5%, +1.2%] (770 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −47.8% [−48.6%, −47.0%] with A/A −0.1% [−0.7%, +0.6%] (2347 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet merge: −52.2% [−52.7%, −51.5%] with A/A −0.1% [−0.4%, +0.4%] (707 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −66.8% [−67.2%, −66.6%] with A/A −1.3% [−2.4%, −0.9%] (97883 calls × 30 windows per process), JIT-flat in 60 processes: A/A interval excludes 0, no claim
- wall Mash.new(repository): +19.0% [+18.2%, +19.6%] with A/A +0.0% [−1.0%, +1.1%] (595 calls × 30 windows per process), JIT-flat in 60 processes
