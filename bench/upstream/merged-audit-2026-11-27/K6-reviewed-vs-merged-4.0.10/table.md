Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 7 | 60,307 | 60,338 | within noise |
| `text_field_tag id:` | 6 | 6 | 54,947 | 54,971 | within noise |
| `button_to 5 params` | 97 | 97 | 542,787 | 542,741 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 7 | 35,143 | 35,195 | +0.1% |
| `text_field_tag id:` | 6 | 6 | 30,331 | 30,401 | +0.2% |
| `button_to 5 params` | 98 | 98 | 301,483 | 302,122 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/K6-reviewed-vs-merged-4.0.10.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/k6-reviewed at aa1dfc3698
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/k6-merged at 271b595e9e
- interp text_field_tag: instructions +0.1% with A/A 0.11% (base 60,273 / 60,341, candidate 60,338): inside the A/A, no claim
- interp text_field_tag id:: instructions +0.0% with A/A 0.05% (base 54,932 / 54,962, candidate 54,971): inside the A/A, no claim
- interp button_to 5 params: instructions −0.0% with A/A 0.02% (base 542,853 / 542,722, candidate 542,741): inside the A/A, no claim
- yjit text_field_tag: instructions +0.1% with A/A 0.07% (base 35,130 / 35,156, candidate 35,195), JIT-flat in 6 windows
- yjit text_field_tag id:: instructions +0.2% with A/A 0.01% (base 30,330 / 30,333, candidate 30,401), JIT-flat in 6 windows
- yjit button_to 5 params: instructions +0.2% with A/A 0.33% (base 300,992 / 301,973, candidate 302,122), JIT-flat in 6 windows: inside the A/A, no claim
