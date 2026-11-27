import gzip
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[6]
out = Path(__file__).resolve().parent

def read_output(name):
    path = out / name
    if path.exists():
        return path.read_text()
    with gzip.open(str(path) + ".gz", "rt") as file:
        return file.read()

body = (out / "body-reviewed.md").read_text()
script = re.search(r"```ruby\n(.*?)```", body, re.S)[1]
assert script == (root / "bench/upstream/l3/l3_ips.rb").read_text()
print("Body Ruby script matches l3_ips.rb byte for byte; 9 triples + id + timestamps = 30 columns")
raw_ips = (root / "bench/upstream/l3/results/rebuild2-2026-11-27/body-ips.txt").read_text()
assert raw_ips.splitlines()[0] in body
for line in body.splitlines():
    match = re.match(r"(before|after):\s+(.*)", line)
    if match:
        side = "main" if match[1] == "before" else "l3"
        matches = [s for s in raw_ips.splitlines() if re.match(side + r" r\d+:\s+" + re.escape(match[2]) + "$", s)]
        assert len(matches) == 1, line
        print("Exact body output:", matches[0])
for side in ("main", "l3", "main2"):
    for op in ("Marshal.dump", "attributes_for_database"):
        rows = re.findall(r"^" + side + r" r(\d+):\s+" + re.escape(op) + r"\s+([\d.]+)k", raw_ips, re.M)
        assert [int(r[0]) for r in rows] == list(range(1, 7))
        print("Kept IPS rounds:", side, op, "6", "best", max(float(r[1]) for r in rows))

data_dir = root / "bench/upstream/l3/body/L3b-2026-11-27"
data = json.loads((data_dir / "results.json").read_text())
assert data["sides"]["base"]["head"] == "088fc0cf61e4ba0c7987decafacc69adb3e22eec"
assert data["sides"]["candidate"]["head"] == "41af869c787a33db4cb46149746cf3cabeb896f7"
ops = ["Marshal.dump", "attributes_for_database", "attributes_before_type_cast", "MessagePack dump"]
for mode in ("interp", "yjit"):
    for index, op in enumerate(ops, 1):
        row = data["instructions"][mode + " " + op]
        for side, key in [("base", "base1"), ("base2", "base2"), ("candidate", "candidate")]:
            totals = []
            for n in (0, 500):
                prefix = f"ir-{mode}-{index}-{op.replace('.', '_').replace(' ', '_')}-{side}-n{n}"
                log = (data_dir / "raw" / (prefix + ".valgrind.log")).read_text()
                totals.append(int(re.search(r"I\s+refs:\s+([\d,]+)", log)[1].replace(",", "")))
                if mode == "yjit":
                    jit_log = (data_dir / "raw" / (prefix + ".log")).read_text()
                    counters = re.findall(r"(\w+)=(\d+)>(\d+)", jit_log)
                    assert len(counters) == 3 and all(a == b for _, a, b in counters)
            assert abs((totals[1] - totals[0]) / 500 - row[key]) < 0.00001
        assert row["base"] == (row["base1"] + row["base2"]) / 2
        print("Raw instructions verified:", mode, op, row["base"], row["candidate"])
    for op in ops[1:3]:
        for side, expected in [("base", 4), ("base2", 4), ("candidate", 2)]:
            text = (data_dir / "raw" / f"objects-{mode}-{side}.log").read_text()
            count = float(re.search(r"objects " + op + r"\t([\d.]+)", text)[1])
            assert count == expected
        print("Raw allocations verified:", mode, op, "4 / 4 / 2")

base = [json.loads(line) for line in read_output("caches-base.jsonl").splitlines()]
head = [json.loads(line) for line in read_output("caches-head.jsonl").splitlines()]
assert base == head
print("Cache/default differential:", len(base), "cases identical")
reached = [row for row in base if isinstance(row[1], bool) and row[1]]
print("Cases with callback reached during the first operation:", len(reached))
for stage in ["default", "cast", "deserialize", "serialize", "changed_in_place?"]:
    print("Callback reached:", stage, sum(row[0].startswith(stage + "/") for row in reached))
for variant in ("no-btc-snapshot", "no-db-snapshot"):
    mutant = [json.loads(line) for line in read_output(f"caches-{variant}.jsonl").splitlines()]
    assert len(mutant) == len(base)
    changed = [a[0] for a, b in zip(base, mutant) if a != b]
    assert changed
    print("Negative control:", variant, len(changed), "different cases")
    (out / f"{variant}-differences.json").write_text(json.dumps(changed, indent=2) + "\n")
