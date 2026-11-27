import json
import re
from pathlib import Path

out = Path(__file__).resolve().parent
for file in ("body-ips", "sizes", "large"):
    rows = {}
    group = tree = None
    for line in (out / (file + ".txt")).read_text().splitlines():
        if line.startswith("=== "):
            tokens = line.split()[1:-1]
            tree = tokens[-1]
            group = tokens[0] if file == "sizes" else file
        match = re.match(r"\s*(.+?)\s+([\d.]+)([kM]?) \(.*i/s", line)
        if match:
            op, ips, unit = match.groups()
            value = float(ips) * {"": 1, "k": 1000, "M": 1000000}[unit]
            rows.setdefault((group, op), {}).setdefault(tree, []).append(value)
    for (group, op), data in rows.items():
        best = {tree: max(values) for tree, values in data.items()}
        print(json.dumps({"group": group, "operation": op, "runs": data,
            "head_percent": round(100 * (best["head"] / best["base"] - 1), 2),
            "aa_percent": round(100 * (best["base2"] / best["base"] - 1), 2)}))
