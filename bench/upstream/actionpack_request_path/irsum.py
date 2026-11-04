#!/usr/bin/env python3
# irsum.py DIR CAND_WT  -> per case/mode: median Ir per call for main, aa (A/A) and the candidate worktree
import sys, glob, os, re, statistics
d, cand = sys.argv[1], sys.argv[2]
rows = {}
for f in glob.glob(os.path.join(d, "*.txt")):
    if f.endswith("jobs.txt"):
        continue
    m = re.match(r"(.+)-([a-z]+?)(\d+)-(\w+)\.txt$", os.path.basename(f))
    case, wt, rep, mode = m.groups()
    txt = open(f).read().split()
    try:
        v = int(txt[-2])
    except (ValueError, IndexError):
        print("bad", f, txt); continue
    rows.setdefault((case, mode), {}).setdefault(wt, []).append(v)
order = ["i49", "y49", "i41", "z41"]
for (case, mode) in sorted(rows, key=lambda k: (k[0], order.index(k[1]))):
    r = rows[(case, mode)]
    if not all(k in r for k in ("main", "aa", cand)):
        continue
    a, aa, b = (statistics.median(r[k]) for k in ("main", "aa", cand))
    spread = max(r["main"]) - min(r["main"])
    print(f"{case:18} {mode:4} main {a:10,.0f} A/A {100*(aa/a-1):+6.2f}%  cand {b:10,.0f} {100*(b/a-1):+7.2f}%  (n={len(r['main'])}, main spread {spread:,})")
