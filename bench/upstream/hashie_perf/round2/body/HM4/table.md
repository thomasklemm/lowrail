Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `quiet.new(repository)` | 14.8 | 14.8 | 1,464,179 | 987,258 | −32.6% |
| `quiet.new(auth hash)` | 17.0 | 17.0 | 476,682 | 330,098 | −30.8% |
| `quiet merge` | 13.8 | 13.8 | 1,506,517 | 1,020,308 | −32.3% |
| `quiet []=` | 0 | 0 | 11,578 | 6,639 | −42.7% |
| `Mash.new(repository)` | 24.8 | 24.8 | 1,481,384 | 1,527,321 | +3.1% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `quiet.new(repository)` | 14.8 | 14.8 | 584,010 | 303,209 | −48.1% |
| `quiet.new(auth hash)` | 17.0 | 17.0 | 189,326 | 102,832 | −45.7% |
| `quiet merge` | 13.8 | 13.8 | 603,037 | 314,838 | −47.8% |
| `quiet []=` | 0 | 0 | 5,085 | 2,377 | −53.3% |
| `Mash.new(repository)` | 28.8 | 28.8 | 605,271 | 611,891 | +1.1% |

Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 64.94 µs | 31.42 µs | −51.7% |
| `quiet.new(auth hash)` | 21.30 µs | 11.30 µs | −47.0% |
| `quiet merge` | 67.35 µs | 32.97 µs | −51.0% |
| `quiet []=` | 0.46 µs | 0.15 µs | −66.2% |
| `Mash.new(repository)` | 69.77 µs | 71.42 µs | +2.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/body/HM4.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-h at 10a9303397
- interp quiet.new(repository): instructions −32.6% with A/A 0.04% (base 1,463,876 / 1,464,482, candidate 987,258)
- interp quiet.new(auth hash): instructions −30.8% with A/A 0.16% (base 477,052 / 476,312, candidate 330,098)
- interp quiet merge: instructions −32.3% with A/A 0.04% (base 1,506,198 / 1,506,835, candidate 1,020,308)
- interp quiet []=: instructions −42.7% with A/A 0.03% (base 11,580 / 11,576, candidate 6,639)
- interp Mash.new(repository): instructions +3.1% with A/A 0.04% (base 1,481,683 / 1,481,085, candidate 1,527,321)
- yjit quiet.new(repository): instructions −48.1% with A/A 0.23% (base 584,667 / 583,352, candidate 303,209), JIT-flat in 6 windows
- yjit quiet.new(auth hash): instructions −45.7% with A/A 0.28% (base 189,588 / 189,065, candidate 102,832), JIT-flat in 6 windows
- yjit quiet merge: instructions −47.8% with A/A 0.27% (base 603,837 / 602,236, candidate 314,838), JIT-flat in 6 windows
- yjit quiet []=: instructions −53.3% with A/A 0.08% (base 5,083 / 5,087, candidate 2,377), JIT-flat in 6 windows
- yjit Mash.new(repository): instructions +1.1% with A/A 0.09% (base 605,554 / 604,987, candidate 611,891), JIT-flat in 6 windows
- wall quiet.new(repository): −51.7% [−51.8%, −50.6%] with A/A +0.2% [−0.5%, +0.6%] (764 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −47.0% [−47.6%, −46.7%] with A/A −0.1% [−0.5%, +0.7%] (2265 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet merge: −51.0% [−51.4%, −50.4%] with A/A +0.4% [−0.3%, +0.6%] (706 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −66.2% [−66.3%, −65.9%] with A/A −0.7% [−2.0%, +0.4%] (111615 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash.new(repository): +2.3% [+1.9%, +4.3%] with A/A +0.4% [−0.1%, +0.7%] (692 calls × 30 windows per process), JIT-flat in 60 processes
