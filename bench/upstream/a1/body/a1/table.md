Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `author.posts` | 121 | 111 | 720,039 | 706,950 | −1.8% |
| `author.profile` | 101 | 91 | 593,753 | 580,714 | −2.2% |
| `comment.post` | 101 | 91 | 572,512 | 559,364 | −2.3% |
| `author.comments (through)` | 158 | 148 | 819,115 | 806,150 | −1.6% |
| `Author.joins(:posts)` | 107 | 99 | 358,827 | 347,917 | −3.0% |
| `author.published_posts (scoped)` | 169 | 169 | 905,884 | 904,572 | −0.1% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `author.posts` | 123 | 113 | 310,143 | 304,612 | −1.8% |
| `author.profile` | 103 | 93 | 255,772 | 250,543 | −2.0% |
| `comment.post` | 103 | 93 | 257,905 | 254,730 | −1.2% |
| `author.comments (through)` | 160 | 150 | 362,659 | 358,121 | −1.3% |
| `Author.joins(:posts)` | 109 | 101 | 146,903 | 140,843 | −4.1% |
| `author.published_posts (scoped)` | 172 | 172 | 372,224 | 373,261 | +0.3% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/a1/body/a1.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/c10/base at e30c36266b
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/c10/a1 at 9877a852dd
- interp author.posts: instructions −1.8% with A/A 0.01% (base 720,092 / 719,987, candidate 706,950)
- interp author.profile: instructions −2.2% with A/A 0.08% (base 593,528 / 593,978, candidate 580,714)
- interp comment.post: instructions −2.3% with A/A 0.04% (base 572,397 / 572,627, candidate 559,364)
- interp author.comments (through): instructions −1.6% with A/A 0.05% (base 819,338 / 818,892, candidate 806,150)
- interp Author.joins(:posts): instructions −3.0% with A/A 0.01% (base 358,808 / 358,846, candidate 347,917)
- interp author.published_posts (scoped): instructions −0.1% with A/A 0.06% (base 906,146 / 905,622, candidate 904,572)
- yjit author.posts: instructions −1.8% with A/A 0.03% (base 310,089 / 310,197, candidate 304,612)
- yjit author.profile: instructions −2.0% with A/A 0.25% (base 256,097 / 255,447, candidate 250,543)
- yjit comment.post: instructions −1.2% with A/A 0.00% (base 257,907 / 257,903, candidate 254,730)
- yjit author.comments (through): instructions −1.3% with A/A 0.22% (base 363,058 / 362,261, candidate 358,121)
- yjit Author.joins(:posts): instructions −4.1% with A/A 1.12% (base 147,723 / 146,083, candidate 140,843)
- yjit author.published_posts (scoped): instructions +0.3% with A/A 0.10% (base 372,045 / 372,403, candidate 373,261)
