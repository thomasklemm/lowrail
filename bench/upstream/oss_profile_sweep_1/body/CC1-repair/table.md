Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Ability.new(user)` | 57 | 52 | 82,753 | 79,547 | −3.9% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Ability.new(user)` | 57 | 52 | 42,921 | 41,418 | −3.5% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core. Inconclusive, not speed evidence (thermos-sol confirm, 2026-11-25): per base/head/base round the effect is −0.05% vs A/A 5.79%, +10.66% vs 11.27%, +2.73% vs 4.67%; reports ±12-15.5%. The best-of-3 A/A below comes from picking independent maxima. Not in the body.

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `Ability.new(user)` | 153.1k i/s | 160.5k i/s | +4.8% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/oss_profile_sweep_1/body/CC1-repair.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/cancancan-main at 021b13cf76
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/oss/up/cancancan at cb5768e493
- interp Ability.new(user): instructions −3.9% with A/A 0.00% (base 82,753 / 82,753, candidate 79,547)
- yjit Ability.new(user): instructions −3.5% with A/A 0.04% (base 42,930 / 42,911, candidate 41,418), JIT-flat in 6 windows
- ips Ability.new(user): +4.8% with A/A 0.14% (best base 152.9k / 153.2k, candidate 160.5k), JIT-flat in 9 windows
