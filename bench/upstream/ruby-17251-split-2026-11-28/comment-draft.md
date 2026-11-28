Draft follow-up on ruby/ruby#17251. **Not posted.** Posting needs Thomas's approval of this exact text. Numbers:
[README](README.md), [report.txt](report.txt). Text: Astra's replacement (review on 39377167) with its own gcbench
correction; thermos-sol approved unchanged (07dcda56).

---

Repeating the comparison of base `f6278067b6` and head `9715d0224e` sequentially, one benchmark at a time. A diagnostic build sets `GC_HEAP_OLDOBJECT_RECLAIM_RATIO` to 2.0, disabling the tighter old-object limit while leaving the rest of the patch unchanged.

Shipit, six rounds with 15 warmups and 40 measured iterations. Medians, interpreter / YJIT / ZJIT; time and RSS rounded:

| | base | head | head, 2× limit |
| --- | ---: | ---: | ---: |
| majors | 6 / 6 / 7 | 8 / 9 / 8 | 6 / 6 / 6.5 |
| GC time ms | 2,761 / 3,080 / 3,134 | 2,644 / 3,214 / 2,959 | 2,566 / 3,117 / 3,042 |
| sampled peak RSS MiB | 151 / 200 / 181 | 149 / 195 / 180 | 151 / 201 / 183 |

Against the 2× build, the head adds a median 2 / 3 / 2 majors. Its sampled peak RSS is lower by paired medians of 2.4 / 4.5 / 3.3 MiB, lower in 5 / 6 / 5 of the six pairs. Against base, GC time rises under YJIT in five of six pairs (median +168 ms) and falls under ZJIT in all six (−224 ms). Interpreter differences overlap the A/A range.

Selected ruby-bench `73918b2` benchmarks, three rounds. RSS after the final full GC, head against base, rounded median percentage change of paired rounds, interpreter / YJIT / ZJIT:

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

For these rows, the 2× build's median changes are within five percentage points of the head's: most of these RSS changes remain without the tighter limit. liquid-c's base copies span 38–67 MiB, versus 34–40 MiB on the head. hexapdf and ruby-lsp are omitted because their A/A RSS changes reach 35% and 12%.

gcbench's peak RSS also rises about 30% in all modes. In the interpreter and YJIT, base takes one `nofree` major during warmup, dropping old objects from about 469k to 150k; the head takes none during warmup or the measured iterations. The higher RSS remains after the final full GC.

Two qualifications to the previous Rails results: over two sequential rounds of the same 35 workloads, the ZJIT RSS increase did not reproduce. RSS summed after each app's last window differs by −2.3 MiB against base and +3.3 MiB against its copy; the copies differ by −5.6 MiB. YJIT majors now rise from 1 to 2 in each round, rather than falling from 1 to 0. These two rounds do not establish a consistent Rails RSS improvement.
