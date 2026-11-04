#!/usr/bin/env python3
import sys, statistics, collections
d = collections.defaultdict(list)
for l in open(sys.argv[1]):
    c, m, wt, v = l.split(); d[(c, m, wt)].append(float(v))
cand = sys.argv[2]
for (c, m) in sorted({(k[0], k[1]) for k in d}):
    mm, aa, cc = (statistics.median(d[(c, m, w)]) for w in ("main", "aa", cand))
    print(f"{c:18} {m}  main {mm:8.1f}  A/A {100*(aa/mm-1):+.1f}%  cand {cc:8.1f}  {100*(cc/mm-1):+.1f}%  (n={len(d[(c,m,'main')])})")
