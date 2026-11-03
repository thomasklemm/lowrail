#!/usr/bin/env python3
# sitedelta.py LABEL FILE_SUBSTR [AA_LABEL]: per workload, objects/op at sites in FILE vs r72, and the traced total.
import json, glob, os, sys, statistics
root = "/home/user/workspace/repo/.lowrail/private/census"
label, sub = sys.argv[1], sys.argv[2]
base = "r72"

def load(l):
    out = {}
    for f in glob.glob(f"{root}/{l}/*.json"):
        if f.endswith("meta.json"): continue
        d = json.load(open(f))
        for w in d["workloads"]:
            site = sum(s["objects_per_op"] for s in w.get("sites", []) if sub in s["file"])
            total = w["traced_gc_objects"] / w["ops"]
            out[(d["app"], d["mode"], w["workload"])] = (site, total, statistics.median(w["gc_enabled_objects_per_op"]))
    return out

b, c = load(base), load(label)
for mode in ("interpreter", "yjit"):
    keys = [k for k in b if k in c and k[1] == mode]
    moved = [(k, c[k][0] - b[k][0], c[k][1] - b[k][1], c[k][2] - b[k][2]) for k in keys if c[k][0] - b[k][0] <= -0.5]
    apps = sorted({k[0].replace("-nops", "").replace("-mysql", "") for k, *_ in moved})
    reached = [k for k in keys if b[k][0] >= 0.5]
    print(f"{label} {mode}: {len(keys)} workloads, file reached in {len(reached)}, site moved <=-0.5 in {len(moved)} ({len(apps)} apps: {','.join(apps)})")
    if moved:
        print(f"  site delta median {statistics.median(x[1] for x in moved):+.1f}, traced-total median {statistics.median(x[2] for x in moved):+.1f}, gc-window median {statistics.median(x[3] for x in moved):+.1f}")
    rises = [(k, c[k][0] - b[k][0]) for k in keys if c[k][0] - b[k][0] >= 0.5]
    print(f"  site rises >=+0.5: {len(rises)}")
    for k, sd, td, gd in sorted(moved, key=lambda x: x[1])[: int(os.environ.get("TOP", "8"))]:
        print(f"    {k[0]:<18} {k[2]:<45} site {sd:+8.1f} traced {td:+8.1f} gc {gd:+8.1f}")
