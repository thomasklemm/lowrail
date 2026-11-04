import glob, os, re, statistics, sys
from collections import defaultdict
out, N = sys.argv[1], int(sys.argv[2])
ir = {}
for f in glob.glob(os.path.join(out, "*.out")):
    b = os.path.basename(f)[:-4]
    c, v, m, n = b.rsplit("-", 3)
    txt = open(f).read()
    mm = re.search(r"Collected : ([\d,]+)", txt)
    if not mm:
        print("MISSING", b); continue
    ir[(c, v, m, int(n))] = int(mm.group(1).replace(",", ""))
per = defaultdict(list)
for (c, v, m, n), val in ir.items():
    if n == N and (c, v, m, 0) in ir:
        per[(c, re.sub(r"\d+$", "", v), m)].append((ir[(c, v, m, N)] - ir[(c, v, m, 0)]) / N)
cases = sorted({k[0] for k in per}); modes = ["i49", "y49", "i41", "z41"]
print(f"{'case':18} {'mode':4} {'main':>11} {'A/A':>8} {'cand':>11} {'delta':>8}  (median of reps; runs)")
for c in cases:
    for m in modes:
        if (c, "main", m) not in per: continue
        mn = statistics.median(per[(c, "main", m)]); aa = statistics.median(per[(c, "aa", m)]); cd = statistics.median(per[(c, "cand", m)])
        print(f"{c:18} {m:4} {mn:11,.0f} {100*(aa-mn)/mn:+7.2f}% {cd:11,.0f} {100*(cd-mn)/mn:+7.2f}%  {len(per[(c,'main',m)])}")
