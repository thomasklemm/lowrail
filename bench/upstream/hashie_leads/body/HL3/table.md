Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash.new.name = value` | 8 | 7 | 20,341 | 20,376 | +0.2% |
| `mash.description = value` | 9 | 7 | 21,237 | 21,333 | +0.5% |
| `mash.private? / owner! / homepage_` | 16 | 13 | 35,584 | 35,685 | +0.3% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash.new.name = value` | 8 | 7 | 13,424 | 13,547 | +0.9% |
| `mash.description = value` | 9 | 7 | 15,184 | 15,453 | +1.8% |
| `mash.private? / owner! / homepage_` | 16 | 13 | 23,033 | 23,407 | +1.6% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new.name = value` | 582.5k i/s | 578.8k i/s | within noise |
| `mash.description = value` | 519.2k i/s | 511.2k i/s | within noise |
| `mash.private? / owner! / homepage_` | 342.9k i/s | 343.7k i/s | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_leads/body/HL3.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/hashie-master at e1adebc3de
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/hashie-l3 at e1adebc3de (dirty)
- interp Mash.new.name = value: instructions +0.2% with A/A 0.00% (base 20,341 / 20,341, candidate 20,376)
- interp mash.description = value: instructions +0.5% with A/A 0.04% (base 21,233 / 21,241, candidate 21,333)
- interp mash.private? / owner! / homepage_: instructions +0.3% with A/A 0.13% (base 35,560 / 35,607, candidate 35,685)
- yjit Mash.new.name = value: instructions +0.9% with A/A 0.00% (base 13,424 / 13,424, candidate 13,547), JIT-flat in 6 windows
- yjit mash.description = value: instructions +1.8% with A/A 0.33% (base 15,159 / 15,209, candidate 15,453), JIT-flat in 6 windows
- yjit mash.private? / owner! / homepage_: instructions +1.6% with A/A 0.22% (base 23,008 / 23,058, candidate 23,407), JIT-flat in 6 windows
- ips Mash.new.name = value: −0.6% with A/A 2.99% (best base 591.2k / 573.8k, candidate 578.8k), JIT-flat in 9 windows: inside the A/A, no claim
- ips mash.description = value: −1.5% with A/A 2.52% (best base 512.7k / 525.8k, candidate 511.2k), JIT-flat in 9 windows: inside the A/A, no claim
- ips mash.private? / owner! / homepage_: +0.2% with A/A 0.99% (best base 344.6k / 341.2k, candidate 343.7k), JIT-flat in 9 windows: inside the A/A, no claim
