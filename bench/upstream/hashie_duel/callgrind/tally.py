#!/usr/bin/env python3
"""Tallies the Duel --callgrind calibration: every attempt's two Duel jobs side by side, the CPU-time job
(YJIT, Duel's default mode) and the instructions job (--callgrind, no JIT), from round.sh's *.summary.txt.
Per job: job seconds, Duel's own seconds, regressed, unsettled, faster, whether Duel measured again; then per
cohort (A/A, plants, candidate) totals, and the widest A/A interval of each instructions benchmark.
Usage: python3 -I tally.py DIR"""
import glob
import os
import re
import sys
from collections import defaultdict
from datetime import datetime

root = sys.argv[1]
when = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
MODES = {"duel-duel": "cpu", "instructions-duel-instructions-": "instr"}
rows = []
widest = defaultdict(lambda: [1.0, 1.0])
for path in sorted(glob.glob(os.path.join(root, "*.summary.txt"))):
    base = os.path.basename(path).removesuffix(".summary.txt")
    run, job = base.split(".", 1)
    if job not in MODES:
        continue
    text = open(path).read()
    head = text.splitlines()[0]
    start, end = re.search(r"job (\S+) -> (\S+)", head).groups()
    m = re.search(r"(\d+) benchmarks in (\d+)s: (\d+) regressed, (\d+) errors, (\d+) with", text)
    if not m:
        rows.append({"run": run, "mode": MODES[job], "job_s": int((when(end) - when(start)).total_seconds()), "broken": head})
        continue
    count, total, regressed, errors, unsettled = map(int, m.groups())
    regressions = sorted(set(re.findall(r"REGRESSION (.+?): ", text)))
    rows.append({
        "run": run, "mode": MODES[job], "benchmarks": count,
        "job_s": int((when(end) - when(start)).total_seconds()), "duel_s": total,
        "regressed": regressed, "errors": errors, "unsettled": unsettled,
        "faster": len(re.findall(r"^  .* faster ", text, re.M)),
        "again": "Measuring" in text, "regressions": regressions,
    })
    if run.startswith("aa-") and MODES[job] == "instr":
        for name, lo, hi in re.findall(r"^  (.+?)\s+\d+\.\ds n=\d+\s+instructions [\d.]+ \[([\d.]+), ([\d.]+)\]", text, re.M):
            w = widest[name]
            w[0], w[1] = min(w[0], float(lo)), max(w[1], float(hi))

print(f"{'run':28} {'mode':5} {'job s':>5} {'duel s':>6} {'regr':>4} {'err':>3} {'unset':>5} {'faster':>6} again")
for r in rows:
    if "broken" in r:
        print(f"{r['run']:28} {r['mode']:5} {r['job_s']:5}  no report: {r['broken']}")
        continue
    print(f"{r['run']:28} {r['mode']:5} {r['job_s']:5} {r['duel_s']:6} {r['regressed']:4} {r['errors']:3} {r['unsettled']:5} {r['faster']:6} "
          f"{'yes' if r['again'] else ''}  {'; '.join(r['regressions'])}")

def median(xs):
    xs = sorted(xs)
    return xs[len(xs) // 2] if xs else None

print()
for cohort in ("aa-", "plant-alloc", "plant-cpu", "hm1"):
    for mode in ("cpu", "instr"):
        rs = [r for r in rows if r["run"].startswith(cohort) and r["mode"] == mode and "broken" not in r]
        if not rs:
            continue
        jobs = [r["job_s"] for r in rs]
        duel = [r["duel_s"] for r in rs]
        print(f"{cohort.rstrip('-'):11} {mode:5} runs {len(rs):2}  failed {sum(r['regressed'] > 0 for r in rs):2}  measured again {sum(r['again'] for r in rs):2}  "
              f"regressed {'/'.join(str(r['regressed']) for r in rs)}  unsettled {sum(r['unsettled'] for r in rs)} of {sum(r['benchmarks'] for r in rs)}  "
              f"faster {'/'.join(str(r['faster']) for r in rs)}  job {min(jobs)}-{max(jobs)} s (median {median(jobs)})  duel {min(duel)}-{max(duel)} s (median {median(duel)})")
if widest:
    print("\nWidest A/A instructions interval per benchmark, over all A/A runs:")
    for name, (lo, hi) in sorted(widest.items(), key=lambda kv: -kv[1][1]):
        print(f"  {name:55} [{lo:.3f}, {hi:.3f}]")
