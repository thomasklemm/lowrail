Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, uncached | Instructions, main | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `worker poll, idle` | 297 | 295 | 600,290 | 603,851 | +0.6% |
| `dispatcher poll, idle` | – | – | 640,865 | 649,978 | +1.4% |
| `dispatcher poll, 10 due jobs` | – | – | 16,454,372 | 15,927,859 | not JIT-flat, no claim |
| `dispatcher poll, 100 due jobs` | – | – | 119,854,307 | 114,952,310 | not JIT-flat, no claim |
| `worker claim, 3 jobs` | – | – | 6,930,654 | 6,886,539 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-sq-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/main/solid_queue at b9c646a848
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/cand/solid_queue at b9c646a848 (dirty)
- yjit worker poll, idle: instructions +0.6% with A/A 0.10% (base 599,990 / 600,589, candidate 603,851), JIT-flat in 6 windows
- yjit dispatcher poll, idle: objects differ between the two base runs (302.9, 303)
- yjit dispatcher poll, idle: instructions +1.4% with A/A 0.06% (base 641,062 / 640,668, candidate 649,978), JIT-flat in 6 windows
- yjit dispatcher poll, 10 due jobs: objects differ between the two base runs (5491.8, 5492.2)
- yjit dispatcher poll, 10 due jobs: instructions −3.2% with A/A 0.01% (base 16,453,150 / 16,455,595, candidate 15,927,859): not JIT-flat (candidate n200 compiled_block_count +5, base2 n200 compiled_block_count +5), no claim
- yjit dispatcher poll, 100 due jobs: objects differ between the two base runs (34020.4, 34021.2)
- yjit dispatcher poll, 100 due jobs: instructions −4.1% with A/A 0.04% (base 119,878,753 / 119,829,860, candidate 114,952,310): not JIT-flat (base n200 compiled_iseq_count +2, base n200 compiled_block_count +15, candidate n200 compiled_iseq_count +2, …), no claim
- yjit worker claim, 3 jobs: objects differ between the two base runs (2,684, 2,684)
- yjit worker claim, 3 jobs: instructions −0.6% with A/A 0.06% (base 6,932,811 / 6,928,498, candidate 6,886,539): not JIT-flat (base n200 compiled_block_count +2, candidate n200 compiled_block_count +2, base2 n200 compiled_block_count +2), no claim
