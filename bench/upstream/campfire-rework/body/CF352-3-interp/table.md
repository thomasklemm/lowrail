Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `plain` | 451 | 286 | 1,797,206 | 734,556 | −59.1% |
| `mention + link` | 820 | 365 | 3,403,479 | 1,101,044 | −67.6% |
| `formatted list` | 891 | 521 | 3,216,595 | 1,407,040 | −56.3% |
| `Lexxy paragraphs` | 576 | 384 | 2,950,623 | 999,700 | −66.1% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/campfire-rework/body/CF352-3-interp.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/campfire at 7b809885a1
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/wt-cf352-3 at 015240e9e2
- interp plain: instructions −59.1% with A/A 0.00% (base 1,797,247 / 1,797,164, candidate 734,556)
- interp mention + link: instructions −67.6% with A/A 0.33% (base 3,409,117 / 3,397,841, candidate 1,101,044)
- interp formatted list: instructions −56.3% with A/A 0.07% (base 3,217,683 / 3,215,507, candidate 1,407,040)
- interp Lexxy paragraphs: instructions −66.1% with A/A 0.08% (base 2,949,430 / 2,951,816, candidate 999,700)
