import json
import pathlib
import re

raw = pathlib.Path(__file__).parent / "raw"
trees = ("stable", "parent", "merge", "main", "head")


def sections(path):
    parts = re.split(r"^(=== .* ===)\n", path.read_text(), flags=re.M)
    return dict(zip(parts[1::2], parts[2::2]))


for adapter in ("sqlite3", "postgresql"):
    matrix = {tree: sections(raw / f"matrix-{tree}-{adapter}.txt") for tree in trees}
    for section, value in matrix["head"].items():
        matches = [tree for tree in trees[:-1] if matrix[tree][section] == value]
        print(adapter, section, "head equals", ",".join(matches) or "NEITHER")
        assert "stable" in matches or "main" in matches
    for group in ("scoped", "scoped-order", "scoped-effects", "scoped-hash"):
        head = (raw / f"{group}-head-{adapter}.txt").read_bytes()
        main = (raw / f"{group}-main-{adapter}.txt").read_bytes()
        print(adapter, group, "head byte-identical to main:", head == main)
        assert head == main
    for mode in ("finite", "range", "phase"):
        for width in (16, 17):
            data = {}
            for tree in trees:
                rows = [json.loads(line) for line in (raw / f"adversarial-{tree}-{adapter}-{mode}-{width}.txt").read_text().splitlines() if line.startswith("[")]
                assert len(rows) == 130, (tree, mode, width, len(rows))
                for row in rows:
                    if isinstance(row[3], str):
                        assert mode == "range" and row[3] == "ActiveModel::RangeError", row
                data[tree] = {tuple(row[:3]): row[3:] for row in rows}
                assert len(data[tree]) == 130
            third = []
            changed = []
            for key, value in data["head"].items():
                if value != data["main"][key]:
                    changed.append(key)
                if value not in (data["stable"][key], data["main"][key]):
                    third.append((key, {tree: data[tree][key] for tree in trees}))
            print(adapter, mode, width, "cases", len(data["head"]), "different from main", len(changed), "neither main nor stable", len(third))
            for key, values in third:
                print("THIRD", key, json.dumps(values))
            assert not third
