Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, main-aa | Instructions, main | Instructions, main-aa | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `consumes` | 0 | 0 | 11,778 | 11,776 | −0.0% |
| `emit_check` | 0 | 0 | 12,282 | 12,285 | +0.0% |
| `payload` | 1 | 1 | 11,830 | 11,830 | within noise |
| `kwargs_debug` | 2 | 2 | 12,904 | 12,931 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, main-aa | Instructions, main | Instructions, main-aa | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `consumes` | 0 | 0 | 4,838 | 4,853 | +0.3% |
| `emit_check` | 0 | 0 | 4,809 | 4,811 | within noise |
| `payload` | 1 | 1 | 10,106 | 10,096 | within noise |
| `kwargs_debug` | 2 | 2 | 12,111 | 12,155 | +0.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-pieces-main.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-mainb at 2e299253f9
- interp consumes: instructions −0.0% with A/A 0.00% (base 11,778 / 11,778, candidate 11,776)
- interp emit_check: instructions +0.0% with A/A 0.02% (base 12,283 / 12,281, candidate 12,285)
- interp payload: instructions −0.0% with A/A 0.00% (base 11,830 / 11,830, candidate 11,830): inside the A/A, no claim
- interp kwargs_debug: instructions +0.2% with A/A 0.41% (base 12,930 / 12,878, candidate 12,931): inside the A/A, no claim
- yjit consumes: instructions +0.3% with A/A 0.04% (base 4,839 / 4,837, candidate 4,853), JIT-flat in 6 windows
- yjit emit_check: instructions +0.0% with A/A 0.08% (base 4,811 / 4,807, candidate 4,811), JIT-flat in 6 windows: inside the A/A, no claim
- yjit payload: instructions −0.1% with A/A 0.21% (base 10,096 / 10,117, candidate 10,096), JIT-flat in 6 windows: inside the A/A, no claim
- yjit kwargs_debug: instructions +0.4% with A/A 0.33% (base 12,092 / 12,131, candidate 12,155), JIT-flat in 6 windows
