import sys, statistics as st, collections
rows = [l.split("\t") for l in open(sys.argv[1]).read().split("\n") if l]
d = collections.defaultdict(list)
for c, m, v, r, ns in rows: d[(c, m, v)].append(float(ns))
print("| Case | Mode | main ns (median) | A/A ns | A/A % | candidate ns | Δ % | rounds |")
print("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
for (c, m) in sorted({(k[0], k[1]) for k in d}):
    md = {v: st.median(d[(c, m, v)]) for v in ("main", "aa", "cand")}
    print(f"| {c} | {m} | {md['main']:,.0f} | {md['aa']:,.0f} | {100*(md['aa']-md['main'])/md['main']:+.1f}% | {md['cand']:,.0f} | {100*(md['cand']-md['main'])/md['main']:+.1f}% | {len(d[(c,m,'main')])} |")
