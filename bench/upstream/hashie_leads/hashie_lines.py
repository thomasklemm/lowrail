#!/usr/bin/env python3
"""Every hashie line in lowrail-profile reports (requests, else jobs): warm objects per unit, reach, share of the
unit's objects. Usage: python3 -I hashie_lines.py NAME=CAPTURE_DIR ..."""
import gzip
import json
import os
import sys

for arg in sys.argv[1:]:
    name, path = arg.split("=", 1)
    path = path.split(",")[0]
    if os.path.isdir(path):
        path = os.path.join(path, "report.json.gz")
    with gzip.open(path, "rt") as f:
        d = json.load(f)
    reqs = d["summary"][0]["requests"]
    if d["ranked"]:
        unit, ranked, total = "request", d["ranked"], d["summary"][0]["objects_per_request"]
        units = reqs
    else:
        o = d["outside_requests"]["job"]
        unit, ranked = "job", o["ranked"]
        total = None
        units = d["summary"][0]["completed"]["job"]
    rows = [r for r in ranked if r["site"].startswith("GEM/hashie/")]
    print(f"== {name}: {len(rows)} hashie lines, {units} {unit}s" + (f", {total:.0f} objects/{unit}" if total else ""))
    for r in rows:
        warm = r["warm"][0]
        share = f"{100 * warm / total:.2f}%" if total else ""
        reach = r["reached"][0]
        print(f"  {r['site'][4:]:42} {warm:9.2f}/{unit} {share:>7} reach {reach}/{units}")
