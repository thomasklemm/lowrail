#!/usr/bin/env python3
# ir_table.py: Ir per call = (Ir(5000) - Ir(0)) / 5000, main / A/A / candidate, per case and mode.
import re, glob, os, sys
d = sys.argv[1] if len(sys.argv) > 1 else "/tmp/w/r7/ir"
ir = {}
for f in glob.glob(f"{d}/*.out"):
    m = re.search(r"Collected : (\d+)", open(f).read())
    c, v, mode, n = os.path.basename(f)[:-4].rsplit("-", 3)
    if m: ir[(c, v, mode, int(n))] = int(m.group(1))
cases = sorted({k[0] for k in ir}, key=lambda c: list(dict.fromkeys(k[0] for k in sorted(ir))).index(c))
print("| Case | Mode | main Ir/call | A/A | candidate | Δ | Δ % | A/A % |")
print("| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |")
for c in cases:
    for mode in ("i40", "y40", "z41"):
        try:
            per = {v: (ir[(c, v, mode, 5000)] - ir[(c, v, mode, 0)]) / 5000 for v in ("main", "aa", "cand")}
        except KeyError:
            continue
        base = (per["main"] + per["aa"]) / 2
        d_ = per["cand"] - base
        print(f"| {c} | {mode} | {per['main']:,.0f} | {per['aa']:,.0f} | {per['cand']:,.0f} | {d_:+,.0f} | {100*d_/base:+.2f}% | {100*(per['aa']-per['main'])/per['main']:+.2f}% |")
