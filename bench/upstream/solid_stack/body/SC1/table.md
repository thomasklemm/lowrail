Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `listener poll, idle` | 234 | 231 | 1,698,352 | 1,451,741 | −14.5% |
| `listener poll, one message` | – | – | 2,747,123 | 2,502,183 | −8.9% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `listener poll, idle` | 238 | 235 | 930,367 | 714,436 | −23.2% |
| `listener poll, one message` | – | – | 1,572,738 | 1,355,006 | −13.8% |

benchmark-ips, Ruby 4.0.10, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 4.6k i/s | 5.3k i/s | +14.8% |
| `listener poll, one message` | 1.9k i/s | 1.9k i/s | +3.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/solid_stack/body/SC1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/main/solid_cable at 40dd29ffdc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/cand/solid_cable at ef534cc941
- interp listener poll, idle: instructions −14.5% with A/A 0.03% (base 1,698,092 / 1,698,612, candidate 1,451,741)
- interp listener poll, one message: objects differ between the two base runs (435, 434.9)
- interp listener poll, one message: instructions −8.9% with A/A 0.01% (base 2,747,293 / 2,746,953, candidate 2,502,183)
- yjit listener poll, idle: instructions −23.2% with A/A 0.00% (base 930,366 / 930,368, candidate 714,436), JIT-flat in 6 windows
- yjit listener poll, one message: objects differ between the two base runs (443, 443)
- yjit listener poll, one message: instructions −13.8% with A/A 0.06% (base 1,572,284 / 1,573,192, candidate 1,355,006), JIT-flat in 6 windows
- ips listener poll, idle: +14.8% with A/A 0.48% (best base 4.6k / 4.6k, candidate 5.3k), JIT-flat in 9 windows
- ips listener poll, one message: +3.2% with A/A 2.32% (best base 1.8k / 1.9k, candidate 1.9k), JIT-flat in 9 windows
