Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT (computed by hand from raw/, see below)

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `plain` | 453 | 306 | 1,590,079 | 670,227 | −57.8% |
| `mention + link` | 826 | 385 | 2,731,488 | 1,017,262 | −62.8% |
| `formatted list` | 893 | 541 | 2,884,448 | 1,300,125 | −54.9% |
| `Lexxy paragraphs` | 578 | 407 | 2,690,326 | 928,000 | no A/A, no claim |

Record (not for the body): diagnostic for -2 (59f8a80bf6) only. script/upstream-bench did not write this table: the run was stopped by hand during its last window (Lexxy paragraphs, base2 N=500), whose dump is empty, so the tool never reached its report. Every other window completed; the values are (N=500 totals − N=0 totals) / 500 from the trailing totals: lines in raw/, and the JIT-flat counters from the matching .log files, all unchanged. Not rerun (cf352_cohort.md).
- base: /home/user/workspace/repos/campfire at 7b809885a1; candidate: /home/user/workspace/repos/wt-cf352 at 59f8a80bf6; ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
- yjit plain: instructions −57.8% with A/A 0.01% (base 1,589,975 / 1,590,184, candidate 670,227), JIT-flat in 6 windows
- yjit mention + link: instructions −62.8% with A/A 0.11% (base 2,733,041 / 2,729,934, candidate 1,017,262), JIT-flat in 6 windows
- yjit formatted list: instructions −54.9% with A/A 0.14% (base 2,882,388 / 2,886,508, candidate 1,300,125), JIT-flat in 6 windows
- yjit Lexxy paragraphs: instructions −65.5% against one base run (base 2,690,326, candidate 928,000); base2 n500 was killed, JIT-flat in 5 windows
