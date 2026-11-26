Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash.new(api_response)` | 101 | 21 | 576,412 | 557,984 | −3.2% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Mash.new(api_response)` | 105 | 25 | 278,040 | 246,360 | −11.4% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(api_response)` | 39.3k i/s | 47.3k i/s | +20.3% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/HM1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/hashie-master at 37454e149e
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/hashie at 5a63e91244
- interp Mash.new(api_response): instructions −3.2% with A/A 0.00% (base 576,412 / 576,412, candidate 557,984)
- yjit Mash.new(api_response): instructions −11.4% with A/A 0.05% (base 278,110 / 277,969, candidate 246,360), JIT-flat in 6 windows
- ips Mash.new(api_response): +20.3% with A/A 3.80% (best base 38.6k / 40.0k, candidate 47.3k), JIT-flat in 9 windows
