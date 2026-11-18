import json
import math
from pathlib import Path
import re
import statistics

root = Path(__file__).resolve().parents[4]
body = root / "bench/upstream/a1/body/a1"
results = json.loads((body / "results.json").read_text())
names = [key.removeprefix("interp ") for key in results["instructions"] if key.startswith("interp ")]
for mode in ("interp", "yjit"):
    for index, name in enumerate(names, 1):
        key = f"{mode} {name}"
        stem = re.sub(r"\W+", "_", name)
        for side, field in (("base", "base1"), ("base2", "base2"), ("candidate", "candidate")):
            totals = []
            for count in (0, 2000):
                log = body / "raw" / f"ir-{mode}-{index}-{stem}-{side}-n{count}.valgrind.log"
                totals.append(int(re.findall(r"Collected : (\d+)", log.read_text())[-1]))
            observed = (totals[1] - totals[0]) / 2000
            assert math.isclose(observed, results["instructions"][key][field], abs_tol=1e-8), (key, field)
            cells = dict(re.findall(r"^objects (.+)\t(\S+)$", (body / "raw" / f"objects-{mode}-{side}.log").read_text(), re.M))
            assert float(cells[name]) == results["objects"][key][field], (key, field)
        for measure in ("objects", "instructions"):
            cell = results[measure][key]
            base = (cell["base1"] + cell["base2"]) / 2
            assert math.isclose(base, cell["base"])
            assert math.isclose(cell["candidate"] / base - 1, cell["change"], abs_tol=1e-12)
            assert math.isclose(abs(cell["base2"] - cell["base1"]) / base, cell["aa"], abs_tol=1e-12)
        cell = results["instructions"][key]
        obj = results["objects"][key]
        print(f'{key}: Ir {cell["base"]:.5f} -> {cell["candidate"]:.5f}, {100 * cell["change"]:.5f}%; A/A {100 * cell["aa"]:.5f}%; objects {obj["base"]} -> {obj["candidate"]}')
print("PASS: 36 instruction cells reconstructed from 72 raw Callgrind windows; 36 raw object cells; all deltas and A/A values")

census = root / "docs/upstream/data/rails-main-census-10"
def micro(name):
    return {fields[0]: (float(fields[1]), float(fields[2])) for line in (census / f"raw/assoc/assoc_micro-{name}-interp.txt").read_text().splitlines() if len(fields := line.split()) == 4}

old, main, main2 = (micro(name) for name in ("s81", "main", "main2"))
for name in ("has_many", "has_one", "joins_has_many", "joins_through"):
    mean = (main[name][0] + main2[name][0]) / 2
    print(f'census main vs 8.1 {name}: {old[name][0]} -> {mean}, {100 * (mean / old[name][0] - 1):.5f}%; A/A {100 * abs(main[name][0] - main2[name][0]) / mean:.5f}%; objects {old[name][1]} -> {main[name][1]}')

reach = [line.split("\t") for line in (census / "share-A1.tsv").read_text().splitlines()[1:] if line and not line.startswith("#")]
reached = [row for row in reach if int(row[3]) > 0]
print(f"census reach: {len(reached)}/{len(reach)} workloads, {len(set(row[0] for row in reached))}/{len(set(row[0] for row in reach))} apps")

requests = (root / "bench/upstream/a1/census-per-request.txt").read_text()
values = re.findall(r"^(.+?)\s+A1\s+([+-][\d.]+)%.*?objs\s+(\d+) ->\s+(\d+)", requests, re.M)
deltas = [float(row[1]) for row in values]
print(f"request summary (not underlying raw windows): {len(values)} workloads, median {statistics.median(deltas):.2f}%, min {min(deltas):.2f}%, objects lower in {sum(int(row[3]) < int(row[2]) for row in values)}")
assert len(values) == 29
assert statistics.median(deltas) == -0.19
assert min(deltas) == -0.89
