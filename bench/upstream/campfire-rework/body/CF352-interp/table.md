Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `plain` | 451 | 305 | 1,797,930 | 798,658 | −55.6% |
| `mention + link` | 820 | 384 | 3,396,827 | 1,166,562 | −65.7% |
| `formatted list` | 891 | 540 | 3,214,496 | 1,493,052 | −53.6% |
| `Lexxy paragraphs` | 576 | 406 | 2,949,326 | 1,089,360 | −63.1% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/campfire-rework/body/CF352-interp.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/campfire at 7b809885a1
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repos/wt-cf352 at 59f8a80bf6
- interp plain: instructions −55.6% with A/A 0.04% (base 1,797,551 / 1,798,308, candidate 798,658)
- interp mention + link: instructions −65.7% with A/A 0.04% (base 3,397,481 / 3,396,173, candidate 1,166,562)
- interp formatted list: instructions −53.6% with A/A 0.09% (base 3,213,087 / 3,215,906, candidate 1,493,052)
- interp Lexxy paragraphs: instructions −63.1% with A/A 0.13% (base 2,951,250 / 2,947,401, candidate 1,089,360)
