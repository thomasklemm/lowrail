Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 7 | 31,443 | 31,345 | within noise |
| `text_field_tag id:` | 6 | 6 | 26,670 | 26,614 | −0.2% |
| `button_to 5 params` | 97 | 97 | 301,138 | 300,945 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/K6-reviewed-vs-merged-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/k6-reviewed at aa1dfc3698
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/k6-merged at 271b595e9e
- zjit text_field_tag: instructions −0.3% with A/A 0.32% (base 31,494 / 31,392, candidate 31,345), JIT-flat in 6 windows: inside the A/A, no claim
- zjit text_field_tag id:: instructions −0.2% with A/A 0.04% (base 26,676 / 26,664, candidate 26,614), JIT-flat in 6 windows
- zjit button_to 5 params: instructions −0.1% with A/A 0.06% (base 301,040 / 301,235, candidate 300,945), JIT-flat in 6 windows: inside the A/A, no claim
