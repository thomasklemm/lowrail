Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, cached | Objects, uncached | Instructions, cached | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1 binds, no rows` | 100 | 97 | 203,605 | 190,438 | −6.5% |
| `20 binds, no rows` | 133 | 130 | 617,041 | 416,829 | not JIT-flat, no claim |
| `100 binds, no rows` | 213 | 210 | 2,135,803 | 1,160,562 | not JIT-flat, no claim |
| `20 binds, 20 rows` | 343 | 339 | 814,967 | 616,239 | −24.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-model-81-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sides/base at fatal: not (dirty)
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sides/uncached at fatal: not (dirty)
- yjit 1 binds, no rows: instructions −6.5% with A/A 0.08% (base 203,689 / 203,521, candidate 190,438), JIT-flat in 6 windows
- yjit 20 binds, no rows: instructions −32.4% with A/A 0.52% (base 618,638 / 615,443, candidate 416,829): not JIT-flat (base n300 compiled_block_count +8), no claim
- yjit 100 binds, no rows: instructions −45.7% with A/A 0.01% (base 2,135,710 / 2,135,896, candidate 1,160,562): not JIT-flat (candidate n300 compiled_iseq_count +1, candidate n300 compiled_block_count +12), no claim
- yjit 20 binds, 20 rows: instructions −24.4% with A/A 0.04% (base 815,142 / 814,791, candidate 616,239), JIT-flat in 6 windows
