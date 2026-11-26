Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `mash.deep_merge(update)` | 116 | 111 | 649,761 | 649,827 | within noise |
| `mash.description = value` | 9 | 8 | 21,248 | 21,290 | +0.2% |
| `Mash.new(api_response)` | 101 | 99 | 576,341 | 576,192 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `mash.deep_merge(update)` | 120 | 115 | 317,896 | 317,039 | −0.3% |
| `mash.description = value` | 9 | 8 | 15,177 | 15,201 | +0.2% |
| `Mash.new(api_response)` | 105 | 103 | 278,158 | 279,082 | +0.3% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `mash.deep_merge(update)` | 25.9k i/s | 25.9k i/s | within noise |
| `mash.description = value` | 504.8k i/s | 510.7k i/s | within noise |
| `Mash.new(api_response)` | 30.3k i/s | 31.3k i/s | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_leads/body/HL1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/hashie-master at e1adebc3de
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/hashie-l1 at e1adebc3de (dirty)
- interp mash.deep_merge(update): instructions +0.0% with A/A 0.10% (base 649,433 / 650,089, candidate 649,827): inside the A/A, no claim
- interp mash.description = value: instructions +0.2% with A/A 0.08% (base 21,256 / 21,240, candidate 21,290)
- interp Mash.new(api_response): instructions −0.0% with A/A 0.10% (base 576,042 / 576,640, candidate 576,192): inside the A/A, no claim
- yjit mash.deep_merge(update): instructions −0.3% with A/A 0.21% (base 318,237 / 317,555, candidate 317,039), JIT-flat in 6 windows
- yjit mash.description = value: instructions +0.2% with A/A 0.01% (base 15,178 / 15,176, candidate 15,201), JIT-flat in 6 windows
- yjit Mash.new(api_response): instructions +0.3% with A/A 0.03% (base 278,115 / 278,201, candidate 279,082), JIT-flat in 6 windows
- ips mash.deep_merge(update): −0.0% with A/A 0.32% (best base 25.9k / 26.0k, candidate 25.9k), JIT-flat in 9 windows: inside the A/A, no claim
- ips mash.description = value: +1.2% with A/A 1.55% (best base 500.9k / 508.7k, candidate 510.7k), JIT-flat in 9 windows: inside the A/A, no claim
- ips Mash.new(api_response): +3.5% with A/A 3.90% (best base 30.9k / 29.7k, candidate 31.3k), JIT-flat in 9 windows: inside the A/A, no claim
