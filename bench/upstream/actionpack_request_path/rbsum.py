#!/usr/bin/env python3
import sys, re, collections
d = collections.defaultdict(dict)
for line in open(sys.argv[1]):
    m = re.match(r"(\w+) (\w+) (\w+) Collected : (\d+)", line)
    if m: d[(m[1], m[2])][m[3]] = int(m[4])
for (app, mode), v in sorted(d.items()):
    if len(v) < 3: print(app, mode, "incomplete", v); continue
    m1, m2, c = v["main1"], v["main2"], v["cand"]; mean = (m1 + m2) / 2
    print(f"{app:10} {mode:6} main1 {m1:>15,} main2 {m2:>15,} A/A {100*(m2/m1-1):+.3f}%  cand {c:>15,}  vs mean {100*(c/mean-1):+.3f}%  ({(c-mean)/1e6:+.1f}M)")
