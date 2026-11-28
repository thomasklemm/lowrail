Draft follow-up on ruby/ruby#17251. **Not posted.** Posting needs Thomas's approval of this exact text. Numbers:
[README](README.md), [report.txt](report.txt).

---

A sequential rerun (one benchmark at a time, nothing else on the machine) of base `f6278067b6` against the head `9715d0224e`. It adds two diagnostic builds: the first commit alone, and the head with `GC_HEAP_OLDOBJECT_RECLAIM_RATIO` set to 2.0, so the 1.25× old-object limit never applies.

One correction to the previous comment first: the Rails ZJIT RSS increase there (+9.8 MiB median against base) did not reproduce sequentially. Over two rounds it came out −2.3 MiB against base and +3.3 MiB against its copy, while the two copies of base differed by 5.6 MiB.

The first commit alone gives the same shipit major counts as the head. The head with the 2× limit runs as many shipit majors as base. On every ruby-bench benchmark in the second table, its RSS changes are within five percentage points of the head's. So the extra shipit majors come from the 1.25× limit, and the RSS changes in that table come from the rest of the patch. On shipit the limit lowers the sampled peak by 2–5 MiB against the 2× build.

Shipit, six rounds, medians, interpreter / YJIT / ZJIT:

| | base | head | head, 2× limit |
| --- | ---: | ---: | ---: |
| majors | 6 / 6 / 7 | 8 / 9 / 8 | 6 / 6 / 6 |
| minors | 196 / 204 / 216 | 160 / 175 / 154 | 180 / 184 / 174 |
| GC time ms | 2,761 / 3,080 / 3,134 | 2,644 / 3,214 / 2,959 | 2,566 / 3,117 / 3,042 |
| sampled peak RSS MiB | 151 / 200 / 181 | 149 / 195 / 180 | 151 / 201 / 183 |

The GC-time directions from the previous comment hold: higher under YJIT in five of six pairs (median +168 ms), lower under ZJIT in all six (−224 ms). Interpreter differences overlap the A/A range.

ruby-bench `73918b2` headline benchmarks, three rounds, RSS after the final full GC (ruby-bench's RSS column), head against base, median of paired rounds, interpreter / YJIT / ZJIT:

| | RSS |
| --- | --- |
| liquid-c | −42% / −42% / −38% |
| liquid-render | −19% / −20% / −16% |
| mail | −14% / −21% / −10% |
| sequel | −11% / −11% / −9% |
| lobsters | −6% / −6% / −3% |
| activerecord | −5% / −8% / 0% |
| railsbench | +1% / +1% / +2% |
| liquid-compile | +2% / +5% / +5% |
| gcbench | +40% / +40% / +7% |

liquid-c on the two copies of base ranged from 37 to 67 MiB between runs, while the head stayed at 33–40 MiB. gcbench's peak RSS (VmHWM) is about +30% in all three modes (55 → 72 MiB under YJIT). Under the interpreter and YJIT, the head takes no major GC in the whole gcbench run. Base takes one, a `nofree` major during warmup that drops old objects from about 469k to 150k. hexapdf and ruby-lsp are left out: their RSS differed between the two copies of base by up to 30% and 12%.

Iteration times stayed within ±4%, except activerecord under YJIT (+7%, range −4% to +11%) and gcbench under ZJIT (+7%, with +5% between the two copies of base).

On base, `nofree` majors remain on shipit (all of its 6–7), hexapdf (about 20 per run; the head takes 5–12) and gcbench under ZJIT (about 35 per run; the head takes 6). The 35 Rails workloads take at most one per round. Over their two rounds, majors are higher on the head under YJIT (2 against 1) and ZJIT (4 against 2); GC time and RSS directions are mixed.
