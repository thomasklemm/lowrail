Objects and Callgrind instructions per call, base and candidate Ruby, no JIT

| | Objects, before | Objects, after | Instructions, before | Instructions, after | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `flat.value` | 0 | 0 | 992 | 992 | within noise |
| `redefine, then redefined.value` | 3 | 3 | 6,628 | 6,617 | −0.2% |

Objects and Callgrind instructions per call, base and candidate Ruby, YJIT

| | Objects, before | Objects, after | Instructions, before | Instructions, after | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `flat.value` | 0 | 0 | 884 | 884 | within noise |
| `redefine, then redefined.value` | 2 | 2 | 205,303 | 205,493 | not JIT-flat, no claim |

benchmark-ips, base and candidate Ruby, YJIT, best of 1 on one core

| | Before | After | Change |
| --- | ---: | ---: | ---: |
| `flat.value` | 17.34M i/s | 16.09M i/s | −7.2% |
| `redefine, then redefined.value` | 18.5k i/s | 18.8k i/s | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/jit_flat_gate/redefine.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
- interp flat.value: instructions +0.0% with A/A 0.00% (base 992 / 992, candidate 992): inside the A/A, no claim
- interp redefine, then redefined.value: instructions −0.2% with A/A 0.00% (base 6,628 / 6,628, candidate 6,617)
- yjit flat.value: instructions +0.0% with A/A 0.00% (base 884 / 884, candidate 884), JIT-flat in 6 windows: inside the A/A, no claim
- yjit redefine, then redefined.value: instructions +0.1% with A/A 0.07% (base 205,377 / 205,230, candidate 205,493): not JIT-flat (base n2000 compiled_block_count +2000, base n2000 invalidation_count +2000, candidate n2000 compiled_block_count +2000, …), no claim
- ips flat.value: −7.2% with A/A 2.97% (best base 17.60M / 17.08M, candidate 16.09M), JIT-flat in 3 windows
- ips redefine, then redefined.value: +1.8% with A/A 0.30% (best base 18.5k / 18.5k, candidate 18.8k): not JIT-flat (r1 base compiled_block_count +38020, r1 base invalidation_count +38020, r1 candidate compiled_block_count +38052, …), no claim
