Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash#to_hash` | 11 | 11 | 803,707 | 580,042 | −27.8% |
| `Mash#to_json` | 14 | 14 | 859,833 | 634,710 | −26.2% |
| `to_hash(symbolize_keys: true)` | 10.8 | 10.8 | 902,563 | 678,085 | −24.9% |
| `auth info to_hash` | 5 | 5 | 44,157 | 32,955 | −25.4% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash#to_hash` | 11 | 11 | 264,974 | 214,537 | −19.0% |
| `Mash#to_json` | 14 | 14 | 320,090 | 269,701 | −15.7% |
| `to_hash(symbolize_keys: true)` | 10.8 | 10.8 | 308,405 | 258,259 | −16.3% |
| `auth info to_hash` | 5 | 5 | 14,428 | 12,524 | −13.2% |

Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash#to_hash` | 25.26 µs | 20.59 µs | −18.5% |
| `Mash#to_json` | 30.89 µs | 26.20 µs | −15.0% |
| `to_hash(symbolize_keys: true)` | 31.12 µs | 26.49 µs | −14.6% |
| `auth info to_hash` | 1.41 µs | 1.31 µs | −7.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/body/HM5.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-th at e10dce085d
- interp Mash#to_hash: instructions −27.8% with A/A 0.02% (base 803,807 / 803,608, candidate 580,042)
- interp Mash#to_json: instructions −26.2% with A/A 0.11% (base 859,381 / 860,285, candidate 634,710)
- interp to_hash(symbolize_keys: true): instructions −24.9% with A/A 0.01% (base 902,537 / 902,588, candidate 678,085)
- interp auth info to_hash: instructions −25.4% with A/A 0.03% (base 44,163 / 44,151, candidate 32,955)
- yjit Mash#to_hash: instructions −19.0% with A/A 0.28% (base 265,341 / 264,607, candidate 214,537), JIT-flat in 6 windows
- yjit Mash#to_json: instructions −15.7% with A/A 0.20% (base 319,764 / 320,416, candidate 269,701), JIT-flat in 6 windows
- yjit to_hash(symbolize_keys: true): instructions −16.3% with A/A 0.06% (base 308,318 / 308,491, candidate 258,259), JIT-flat in 6 windows
- yjit auth info to_hash: instructions −13.2% with A/A 0.17% (base 14,416 / 14,440, candidate 12,524), JIT-flat in 6 windows
- wall Mash#to_hash: −18.5% [−19.0%, −18.1%] with A/A +0.1% [−0.2%, +0.5%] (1980 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash#to_json: −15.0% [−15.4%, −14.8%] with A/A +0.1% [−0.1%, +0.7%] (1566 calls × 30 windows per process), JIT-flat in 60 processes
- wall to_hash(symbolize_keys: true): −14.6% [−15.1%, −14.0%] with A/A +0.0% [−0.7%, +0.7%] (1616 calls × 30 windows per process), JIT-flat in 60 processes
- wall auth info to_hash: −7.2% [−7.6%, −6.7%] with A/A +0.4% [−0.3%, +0.6%] (36461 calls × 30 windows per process), JIT-flat in 60 processes
