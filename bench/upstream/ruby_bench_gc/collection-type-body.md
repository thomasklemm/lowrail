On Ruby 4.1, `GC::Profiler` records each collection's marking time (ruby/ruby#17431). This keeps it in `--harness=gc`, split into minor and major collections, and adds `mark ms/minor` and `mark ms/major` to the GC summary and `mark/minor` and `mark/major` to the GC time ratios. With `--pvalue`, each iteration is one sample. On Ruby 4.0 and TruffleRuby, nothing changes.

`mark/iter` mixes the cost of one collection with how many collections ran. On lobsters and shipit it is dominated by the major GCs that land in some iterations. ruby/ruby#19685 marks each ZJIT JITFrame ISEQ once per GC. With ZJIT, three processes per build, it lowers marking time per minor GC by 54% (railsbench), 9% (lobsters) and 28% (shipit). Two processes of the same build differ by at most 9%. Iteration time and `mark/iter` stay within noise.

#562 compares timings with GC time removed; these columns cover changes that only change GC work. They also appear in #541's GC per ruby table.
