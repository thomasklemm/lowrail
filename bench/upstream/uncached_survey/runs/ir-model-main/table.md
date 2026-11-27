Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, cached | Objects, uncached | Instructions, cached | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1 binds, no rows` | 76 | 73 | 474,767 | 476,167 | +0.3% |
| `20 binds, no rows` | 128 | 125 | 1,205,788 | 980,914 | −18.6% |
| `100 binds, no rows` | 288 | 285 | 4,087,297 | 2,919,162 | −28.6% |
| `20 binds, 20 rows` | 273 | 269 | 1,644,114 | 1,418,400 | −13.7% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, cached | Objects, uncached | Instructions, cached | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1 binds, no rows` | 78 | 75 | 203,642 | 195,361 | −4.1% |
| `20 binds, no rows` | 130 | 127 | 643,378 | 467,090 | −27.4% |
| `100 binds, no rows` | 290 | 287 | 2,274,274 | 1,371,954 | not JIT-flat, no claim |
| `20 binds, 20 rows` | 275 | 271 | 830,629 | 654,042 | −21.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-model-main.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sides-main/base at fatal: not (dirty)
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sides-main/uncached at fatal: not (dirty)
- interp 1 binds, no rows: instructions +0.3% with A/A 0.04% (base 474,671 / 474,864, candidate 476,167)
- interp 20 binds, no rows: instructions −18.6% with A/A 0.04% (base 1,205,569 / 1,206,007, candidate 980,914)
- interp 100 binds, no rows: instructions −28.6% with A/A 0.01% (base 4,087,190 / 4,087,404, candidate 2,919,162)
- interp 20 binds, 20 rows: instructions −13.7% with A/A 0.02% (base 1,643,975 / 1,644,254, candidate 1,418,400)
- yjit 1 binds, no rows: instructions −4.1% with A/A 0.07% (base 203,567 / 203,717, candidate 195,361), JIT-flat in 6 windows
- yjit 20 binds, no rows: instructions −27.4% with A/A 0.02% (base 643,443 / 643,312, candidate 467,090), JIT-flat in 6 windows
- yjit 100 binds, no rows: instructions −39.7% with A/A 0.19% (base 2,276,473 / 2,272,075, candidate 1,371,954): not JIT-flat (base n300 compiled_block_count +22), no claim
- yjit 20 binds, 20 rows: instructions −21.3% with A/A 0.03% (base 830,520 / 830,739, candidate 654,042), JIT-flat in 6 windows
