#!/usr/bin/env python3
"""Render README's current-results table from published, accepted exports."""

from decimal import Decimal, ROUND_HALF_UP
import json
from pathlib import Path
import subprocess
import sys


def lookup(data, path):
    for key in path.split("."):
        data = data[key]
    return data


def interval(value):
    if isinstance(value, dict):
        value = [value["median"], *value["ci95"]]
    value = [Decimal(n) for n in value]
    rounded = [n.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP) for n in value]
    # Keep a third decimal when rounding would conceal interval separation.
    if (
        any(bound != value[0] and shown == rounded[0]
            for bound, shown in zip(value[1:], rounded[1:]))
        or (value[1] > 0 and rounded[1] == 0)
        or (value[2] < 0 and rounded[2] == 0)
    ):
        rounded = [n.quantize(Decimal("0.001"), rounding=ROUND_HALF_UP) for n in value]
    median, low, high = [f"{n:+f}".replace("-", "−") for n in rounded]
    return f"{median}% [{low}, {high}]"


def commit(sha):
    subprocess.run(["git", "cat-file", "-e", f"{sha}^{{commit}}"], cwd=root, check=True)
    return f"[{sha[:7]}](https://github.com/thomasklemm/lowrail/commit/{sha})"


root = Path(__file__).resolve().parent.parent
if sys.argv[1:] not in ([], ["--check"]):
    sys.exit("Usage: python3 docs/render-results.py [--check]")
rows = [
    "| Date | App / endpoint | Ruby / Rails | Mode / tier | Ir Δ vs no Lowrail [95% interval] | Measured / published |",
    "|---|---|---|---|---|---|",
]
for entry in json.loads((root / "docs/results.json").read_text()):
    source_url = entry["source"]
    if "source_commit" in entry:
        source_commit = entry["source_commit"]
        if len(source_commit) != 40 or source_commit != entry["publication"]:
            sys.exit("Branch source must be pinned to its full publication commit")
        commit(source_commit)
        source = subprocess.check_output(
            ["git", "show", f"{source_commit}:{entry['source']}"], cwd=root, text=True
        )
        source_url = f"https://github.com/thomasklemm/lowrail/blob/{source_commit}/{entry['source']}"
    else:
        source = (root / entry["source"]).read_text()
    data = json.loads(source, parse_float=Decimal)
    if lookup(data, entry["accepted"]) != entry.get("accepted_value", True):
        sys.exit(f"Not accepted: {entry['source']}")
    for gate in entry.get("required_gates", []):
        if lookup(data, gate) is not True:
            sys.exit(f"Failed gate {gate}: {entry['source']}")
    if lookup(data, entry["revision_field"]) != entry["revision"]:
        sys.exit(f"Revision mismatch: {entry['source']}")
    total = interval(lookup(data, entry["total"]))
    no_gc = interval(lookup(data, entry["no_gc"]))
    price = f"**Total {total}**; GC-excluded {no_gc}"
    if "historical" in entry:
        historical = entry["historical"]
        price = (
            f"**No current price:** {total.split(' [')[0]} was "
            f"{historical['reason']} {commit(entry['revision'])}; "
            f"{historical['follow_up']} ({commit(historical['publication'])})"
        )
    runtime = f"; runtime {commit(entry['runtime_revision'])}" if "runtime_revision" in entry else ""
    rows.append(
        f"| {entry['date']} | [{entry['app_endpoint']}]({entry['report']}) | "
        f"{entry['ruby_rails']} | {entry['mode']}; {entry['tier']} | "
        f"{price} | "
        f"{commit(entry['revision'])} / {commit(entry['publication'])}{runtime}; [JSON]({source_url}) |"
    )
readme = root / "README.md"
before, rest = readme.read_text().split("<!-- current-results:start -->\n")
_, after = rest.split("<!-- current-results:end -->")
rendered = before + "<!-- current-results:start -->\n" + "\n".join(rows) + "\n<!-- current-results:end -->" + after
if "--check" in sys.argv:
    if readme.read_text() != rendered:
        sys.exit("README results stale; run python3 docs/render-results.py")
    print("README results match accepted exports and commit objects.")
else:
    readme.write_text(rendered)
    print("Updated README current-results table.")
