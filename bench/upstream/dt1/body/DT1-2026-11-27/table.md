Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, change | Instructions, main | Instructions, change | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, then update! of one column` | – | – | 2,111,005 | 1,871,399 | −11.4% |
| `find, then changed?` | 90 | 59 | 712,854 | 486,626 | −31.7% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, change | Instructions, main | Instructions, change | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find, then update! of one column` | – | – | 1,012,317 | 875,219 | not JIT-flat, no claim |
| `find, then changed?` | 90 | 59 | 356,775 | 234,848 | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/dt1/body/DT1-2026-11-27.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/fix2 at 4e635c7ca5
- interp find, then update! of one column: objects differ between the two base runs (300, 300)
- interp find, then update! of one column: instructions −11.4% with A/A 0.06% (base 2,110,408 / 2,111,603, candidate 1,871,399)
- interp find, then changed?: instructions −31.7% with A/A 0.04% (base 712,997 / 712,711, candidate 486,626)
- yjit find, then update! of one column: objects differ between the two base runs (302, 302)
- yjit find, then update! of one column: instructions −13.5% with A/A 0.21% (base 1,011,232 / 1,013,402, candidate 875,219): not JIT-flat (candidate n2000 compiled_block_count +1, base2 n2000 compiled_iseq_count +1, base2 n2000 compiled_block_count +10), no claim
- yjit find, then changed?: instructions −34.2% with A/A 0.18% (base 357,099 / 356,452, candidate 234,848): not JIT-flat (base n2000 compiled_block_count +10, candidate n2000 compiled_block_count +8), no claim
