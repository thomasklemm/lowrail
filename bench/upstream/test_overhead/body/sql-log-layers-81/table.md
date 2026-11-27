Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, 81 | Objects, 81-aa | Instructions, 81 | Instructions, 81-aa | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `full` | 95 | 95 | 342,804 | 342,149 | −0.2% |
| `no_format` | 56 | 56 | 261,910 | 261,788 | −0.0% |
| `info` | 50 | 50 | 236,438 | 235,806 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-layers-81.
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-81 at 3f290b759c
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-81b at 3f290b759c
- interp full: instructions −0.2% with A/A 0.07% (base 342,688 / 342,920, candidate 342,149)
- interp no_format: instructions −0.0% with A/A 0.00% (base 261,905 / 261,914, candidate 261,788)
- interp info: instructions −0.3% with A/A 0.55% (base 235,787 / 237,090, candidate 235,806): inside the A/A, no claim
