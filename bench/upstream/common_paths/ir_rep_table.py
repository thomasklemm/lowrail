import re, glob, os, sys, statistics as st
d = sys.argv[1]; N = int(sys.argv[2])
ir = {}
for f in glob.glob(f"{d}/*.out"):
    m = re.search(r"Collected : (\d+)", open(f).read())
    c, v, mode, n = os.path.basename(f)[:-4].rsplit("-", 3)
    if m: ir[(c, v, mode, int(n))] = int(m.group(1))
    else: print("MISSING", f)
print("| Case | Mode | main Ir/call (median, range) | A/A Ir/call | A/A % | candidate | Δ % vs main |")
print("| --- | --- | ---: | ---: | ---: | ---: | ---: |")
for c in sorted({k[0] for k in ir}):
    for mode in ("i49", "y49", "i41", "z41"):
        per = {}
        for (cc, v, mm, n), x in ir.items():
            if cc == c and mm == mode and n == N and (cc, v, mm, 0) in ir:
                per.setdefault(re.sub(r"\d+$", "", v), []).append((x - ir[(cc, v, mm, 0)]) / N)
        if len(per) < 3: continue
        med = {k: st.median(v) for k, v in per.items()}
        rng = lambda k: f"{min(per[k]):,.0f}–{max(per[k]):,.0f}" if len(per[k]) > 1 else ""
        print(f"| {c} | {mode} | {med['main']:,.0f} ({rng('main')}) | {med['aa']:,.0f} ({rng('aa')}) | {100*(med['aa']-med['main'])/med['main']:+.2f}% | {med['cand']:,.0f} ({rng('cand')}) | {100*(med['cand']-med['main'])/med['main']:+.2f}% |")
