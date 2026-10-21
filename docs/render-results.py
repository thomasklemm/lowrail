#!/usr/bin/env python3
"""Render README's current results from published, accepted exports."""

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
        if "delta_pct" in value:
            value = [value["delta_pct"], *value["ci95_pct"]]
        else:
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


def throughput(entry, data, source_url):
    result = lookup(data, entry["result"])
    config, summary = result["config"], result["summary"]
    rows = [
        f"**{entry['date']} · [{entry['app_endpoint']}]({entry['report']}) · "
        f"Ruby / Rails {entry['ruby_rails']} · {entry['mode']}.**",
        "",
        f"**{entry['tier']}.** Measured on {commit(entry['revision'])}; "
        f"does **not** include {commit(entry['excluded_revision'])}.",
        f"Puma {config['workers']} workers × {config['threads']} thread, "
        f"c{config['concurrency']}, {config['warmup_seconds']} s warmup / "
        f"{config['duration']} s load, {config['rounds']} rotated off-A/on/off-B rounds.",
        f"Protocol {commit(result['protocol_revision'])}; "
        f"published {commit(entry['publication'])}; [exact JSON]({source_url}).",
        "",
        f"**RPS A/A {interval(summary['aa'])}.** The preregistered rule passes: "
        "A/A contains zero and the on/off RPS lower bound exceeds the A/A upper bound.",
        "This does not establish ±2% resolution or a latency gate.",
        "",
        "| Metric | Paired on/off Δ [95% interval] | off-A | on | off-B |",
        "|---|---|---:|---:|---:|",
    ]
    arms = ("off_a", "on", "off_b")
    metrics = [("RPS", summary["on_off"], [summary["median_rps"][arm] for arm in arms])]
    for percentile in ("p50", "p90", "p99"):
        metrics.append((
            f"{percentile}, ms", result["latency_comparisons"][percentile]["on_off"],
            [summary["median_latency_ms"][arm][percentile] for arm in arms],
        ))
    for label, effect, values in metrics:
        medians = " | ".join(f"{n.quantize(Decimal('0.1'), rounding=ROUND_HALF_UP):f}" for n in values)
        rows.append(f"| **{label}** | **{interval(effect)}** | {medians} |")
    for label, field, divisor, places in (
        ("GC collections / 1,000 requests", "count_per_1000_completions", 1, "0.1"),
        ("Allocations / request", "total_allocated_objects_per_1000_completions", 1000, "1"),
    ):
        medians = [result["gc_process_diagnostics"][arm]["median_process_diagnostics"][field] / divisor for arm in arms]
        shown = " | ".join(f"{n.quantize(Decimal(places), rounding=ROUND_HALF_UP):f}" for n in medians)
        rows.append(f"| **{label}** | — | {shown} |")
    rows.extend([
        "",
        "**Not uniformly faster: p99 increases despite lower p50/p90 and higher RPS. "
        "GC collections increase despite fewer allocations; the cause is not established.**",
        "Arm values are medians of windows; paired deltas are means of within-round ratios, "
        "not ratios of those medians. GC/allocations are load-bracketing four-process "
        "diagnostics including metrics/background work, not exclusive request counters.",
    ])
    return rows


root = Path(__file__).resolve().parent.parent
if sys.argv[1:] not in ([], ["--check"]):
    sys.exit("Usage: python3 docs/render-results.py [--check]")
throughput_rows = []
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
    if entry.get("kind") == "throughput":
        throughput_rows.extend(throughput(entry, data, source_url))
        continue
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
before, rest = rendered.split("<!-- throughput-results:start -->\n")
_, after = rest.split("<!-- throughput-results:end -->")
rendered = before + "<!-- throughput-results:start -->\n" + "\n".join(throughput_rows) + "\n<!-- throughput-results:end -->" + after
if "--check" in sys.argv:
    if readme.read_text() != rendered:
        sys.exit("README results stale; run python3 docs/render-results.py")
    print("README results match accepted exports and commit objects.")
else:
    readme.write_text(rendered)
    print("Updated README current results.")
