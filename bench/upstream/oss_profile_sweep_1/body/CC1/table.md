Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Ability.new(user)` | 57 | 47 | 82,787 | 80,391 | −2.9% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Ability.new(user)` | 57 | 47 | 42,893 | 40,991 | −4.4% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/CC1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/cancancan-main at 021b13cf76
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/cancancan at 2a5e8c71d1
- interp Ability.new(user): instructions −2.9% with A/A 0.02% (base 82,793 / 82,780, candidate 80,391)
- yjit Ability.new(user): instructions −4.4% with A/A 0.08% (base 42,876 / 42,911, candidate 40,991), JIT-flat in 6 windows
