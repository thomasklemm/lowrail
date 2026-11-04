# Objects per operation at given gem lines, per app, from a gem census label (docs/upstream/gem-request-census-2.md).
#   python3 site_per_app.py LABEL_DIR MODE 'file-regex' [line ...]
# LABEL_DIR is a label from docs/upstream/data/gem-census/receipts.tar.xz (for example g2), MODE interpreter or yjit.
# Prints each configuration's mean over its workloads (shown when >= 0.05) and the mean over all workloads.
import json, glob, sys, re, collections

d, mode, pat = sys.argv[1], sys.argv[2], re.compile(sys.argv[3])
lines = set(int(x) for x in sys.argv[4:])
tot = collections.defaultdict(float); nw = {}; allobj = {}
for f in sorted(glob.glob(f"{d}/*-{mode}.json")):
    j = json.load(open(f)); app = j['app']
    ws = j['workloads']; nw[app] = len(ws)
    for w in ws:
        for s in w['sites']:
            if pat.search(s['file']) and (not lines or s['line'] in lines):
                tot[app] += s['objects_per_op'] / len(ws)
        g = w['gc_enabled_objects_per_op']
        allobj[app] = allobj.get(app, 0) + (sum(g) / len(g)) / len(ws)
grand = 0
for app in sorted(nw):
    grand += tot[app] * nw[app]
    if tot[app] >= 0.05: print(f"{app:20s} {nw[app]:3d} {tot[app]:8.2f}  (all {allobj[app]:.0f})")
n = sum(nw.values()); print(f"ALL {n} workloads: {grand/n:.2f} per workload")
