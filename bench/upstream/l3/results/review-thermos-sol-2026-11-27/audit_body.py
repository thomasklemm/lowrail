from collections import Counter
from pathlib import Path
import re

root = Path(__file__).resolve().parents[5]
item = (root / "bench/upstream/pr-queue/items/L3.md").read_text()
body = item.split("# Build attribute Hashes without copying the lazy row\n", 1)[1]
script = re.search(r"```ruby\n(.*?)\n```", body, re.S)[1]
assert script.strip() == (root / "bench/upstream/l3/l3_ips.rb").read_text().strip()
raw = (root / "bench/upstream/l3/results/rebuild-2026-11-27/body-ips.txt").read_text()
normalize = lambda line: " ".join(line.split())
samples = {}
for line in raw.splitlines():
    match = re.match(r"(main2?|l3) r(\d+):\s*(.*)", line)
    if match:
        samples.setdefault(match[1], []).append((int(match[2]), normalize(match[3])))
for line in body.splitlines():
    match = re.match(r"(before|after):\s*(.*)", line)
    if match:
        tree = "main" if match[1] == "before" else "l3"
        assert normalize(match[2]) in [sample for _, sample in samples[tree]], line
        print(f"quoted line found in {tree}: {normalize(match[2])}")
print("body script equals l3_ips.rb; all four output lines match retained raw samples")
print("retained samples by round:")
for tree, rows in samples.items():
    print(tree, dict(Counter(round_number for round_number, _ in rows)))
prose = re.sub(r"```.*?```", "", body, flags=re.S)
print("prose words excluding fences:", len(prose.split()))
