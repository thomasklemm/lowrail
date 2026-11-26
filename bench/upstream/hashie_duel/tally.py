#!/usr/bin/env python3
"""Tallies the Duel calibration runs in calibration/*.summary.txt: per run the job time, Duel's own
measuring time, regressed, unsettled and whether Duel measured again; then the A/A totals.
Usage: python3 -I bench/upstream/hashie_duel/tally.py [DIR]"""
import glob
import os
import re
import sys
from datetime import datetime

root = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "calibration")
when = lambda s: datetime.fromisoformat(s.replace("Z", "+00:00"))
rows = []
for path in sorted(glob.glob(os.path.join(root, "*.summary.txt"))):
    text = open(path).read()
    start, end = re.search(r"job (\S+) -> (\S+)", text.splitlines()[0]).groups()
    count, total, regressed, unsettled = re.search(r"(\d+) benchmarks in (\d+)s: (\d+) regressed, \d+ errors, (\d+) with", text).groups()
    rows.append({
        "benchmarks": int(count),
        "run": os.path.basename(path).removesuffix(".summary.txt"),
        "job_s": int((when(end) - when(start)).total_seconds()),
        "duel_s": int(total),
        "regressed": int(regressed),
        "unsettled": int(unsettled),
        "measured_again": "Measuring" in text,
        "faster": len(re.findall(r"^  .* faster ", text, re.M)),
    })
print(f"{'run':32} {'job s':>5} {'duel s':>6} {'regressed':>9} {'unsettled':>9} {'faster':>6}  measured again")
for r in rows:
    print(f"{r['run']:32} {r['job_s']:5} {r['duel_s']:6} {r['regressed']:9} {r['unsettled']:9} {r['faster']:6}  {r['measured_again']}")
aa = [r for r in rows if r["run"].startswith("aa-")]
jobs = sorted(r["job_s"] for r in aa)
print(f"\nA/A: {len(aa)} runs, {sum(r['regressed'] > 0 for r in aa)} failed, {sum(r['measured_again'] for r in aa)} measured again, "
      f"{sum(r['unsettled'] for r in aa)} of {sum(r["benchmarks"] for r in aa)} verdicts unsettled, job {jobs[0]}-{jobs[-1]} s (median {jobs[len(jobs) // 2]} s)")
