#!/usr/bin/env python3
"""Export compact large_app_profile.rb captures. Not an optimization price."""
import collections
import hashlib
import json
from pathlib import Path
import re
import statistics
import sys


AREAS = ["routing", "controller callbacks", "params", "AR query building",
         "AR instantiation/attributes", "view lookup/render", "helpers", "JSON",
         "Rack/middleware", "instrumentation/notifications", "GC",
         "database execution/cache", "cache/serialization", "AS utilities",
         "AR associations/preload", "AR other/persistence",
         "app", "other gems/runtime", "harness", "sampler residual"]


def normalize_file(file, app):
    if not file:
        return ""
    if "/gems/" in file:
        return "GEM/" + file.rsplit("/gems/", 1)[1]
    if "/benchmarks/lobsters/" in file:
        return "APP/lobsters/" + file.split("/benchmarks/lobsters/", 1)[1]
    if f"/.corpus/{app}/" in file:
        return f"APP/{app}/" + file.split(f"/.corpus/{app}/", 1)[1]
    if "/lib/ruby/4.0.0/" in file:
        return "RUBY/" + file.split("/lib/ruby/4.0.0/", 1)[1]
    if "/bench/" in file:
        return "HARNESS/bench/" + file.split("/bench/", 1)[1]
    return file


def normalize_name(name, file):
    if "/app/views/" in file and "_app_views_" in name:
        return "ERB " + file.split("/app/views/", 1)[1]
    return re.sub(r"0x[0-9a-f]+", "<address>", name)


def area(site):
    file, owner, leaf = (site[k] for k in ("file", "owner", "leaf"))
    if leaf == "<sampler residual>":
        return "sampler residual"
    if leaf in ("(marking)", "(sweeping)", "(garbage collection)"):
        return "GC"
    if file.startswith("HARNESS/") or "/rack/mock" in file:
        return "harness"
    if "/active_support/notifications" in file or "/active_support/subscriber" in file:
        return "instrumentation/notifications"
    if "/callbacks" in file or "/abstract_controller/callbacks" in file:
        return "controller callbacks"
    if "/routing/" in file or "/journey/" in file:
        return "routing"
    if "strong_parameters" in file or "/http/parameters" in file or "query_parser" in file:
        return "params"
    if "/json" in file or "JSON" in owner or "JSON" in leaf:
        return "JSON"
    if "/active_record/" in file:
        if any(x in file for x in ("/connection_adapters/", "/result.rb", "/query_cache.rb")):
            return "database execution/cache"
        if any(x in file for x in ("/attribute", "/type/", "/core.rb", "/model_schema.rb", "/inheritance.rb", "/store.rb", "/type_caster/", "/enum.rb")) or "instantiate" in owner:
            return "AR instantiation/attributes"
        if any(x in file for x in ("/relation", "/scoping", "/reflection", "/table_metadata", "/querying", "/sanitization", "/association_scope", "/join_dependency", "/alias_tracker", "/statement_cache")):
            return "AR query building"
        if "/associations" in file:
            return "AR associations/preload"
        return "AR other/persistence"
    if "/arel/" in file:
        return "AR query building"
    if "/active_model/attribute" in file or "/active_model/type" in file:
        return "AR instantiation/attributes"
    if "/sqlite3" in file:
        return "database execution/cache"
    if "/active_support/cache" in file:
        return "cache/serialization"
    if "/helpers/" in file:
        return "helpers"
    if "/action_view/" in file or "/app/views/" in file:
        return "view lookup/render"
    if file.startswith("GEM/rack-") or "/action_dispatch/" in file:
        return "Rack/middleware"
    if "/active_support/" in file:
        return "AS utilities"
    if file.startswith("APP/"):
        return "app"
    return "other gems/runtime"


def rank(sites, denominator):
    counts = collections.Counter()
    for s in sites:
        counts[tuple(s[k] for k in ("leaf", "owner", "file", "line", "area"))] += s["samples"]
    return [dict(zip(("leaf", "owner", "file", "line", "area"), key),
                 samples=count, percent=100 * count / denominator)
            for key, count in counts.most_common()]


def export(paths):
    result = {"format": 1, "purpose": "native startup-YJIT exploration; not a price/support claim",
              "aggregation": "equal requests per route; pooled observed work, not deployment traffic",
              "self_attribution": "native/internal leaves charged to nearest absolute Ruby source at sampled line; leaf retained; GC separate",
              "area_names": AREAS, "captures": [], "apps": {}, "pooled": {}}
    pooled = collections.defaultdict(list)
    denominators = collections.Counter()
    for path in paths:
        capture = json.loads(path.read_text())
        name, mode = capture["app"], capture["mode"]
        assert capture["source_unchanged"] and not capture["lowrail_loaded"]
        assert capture["startup_yjit"] and capture["rails"] == "8.1.4"
        entry = {k: v for k, v in capture.items() if k != "routes"}
        entry["input_sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        entry["input_file"] = path.name
        entry["routes"] = {}
        app = result["apps"].setdefault(name, {"native": {}, "profiles": {}})
        all_sites, samples, missed = [], 0, 0
        for route, r in capture["routes"].items():
            out = {k: v for k, v in r.items() if k != "profile"}
            if mode == "native":
                blocks = r["blocks"]
                app["native"][route] = {
                    "wall_ms_median": statistics.median(b["wall_seconds"] * 1000 / b["requests"] for b in blocks),
                    "wall_ms_range": [min(b["wall_seconds"] * 1000 / b["requests"] for b in blocks), max(b["wall_seconds"] * 1000 / b["requests"] for b in blocks)],
                    "cpu_ms_median": statistics.median(b["cpu_seconds"] * 1000 / b["requests"] for b in blocks),
                    "objects_per_request": statistics.median(b["gc_delta"]["total_allocated_objects"] / b["requests"] for b in blocks),
                    "minor_gc": sum(b["gc_delta"]["minor_gc_count"] for b in blocks),
                    "major_gc": sum(b["gc_delta"]["major_gc_count"] for b in blocks),
                    "gc_ms_per_request": sum(b["gc_delta"]["time"] for b in blocks) / sum(b["requests"] for b in blocks),
                    "gc_wall_percent": 100 * sum(b["gc_delta"]["time"] for b in blocks) / (1000 * sum(b["wall_seconds"] for b in blocks)),
                    "status": r["status"], "bytes": r["bytes"], "content_type": r["content_type"]}
            else:
                p = r["profile"]
                ids = {old: str(i) for i, old in enumerate(p["frames"])}
                frames = {}
                for old, f in p["frames"].items():
                    file = normalize_file(f["file"], name)
                    frames[ids[old]] = dict(f, file=file, name=normalize_name(f["name"], file),
                                           edges={ids[k]: v for k, v in f.get("edges", {}).items()})
                sites = []
                for s in p["self_sites"]:
                    file = normalize_file(s["file"], name)
                    s = dict(s, file=file, owner=normalize_name(s["owner"], file), leaf=normalize_name(s["leaf"], file))
                    s["area"] = area(s)
                    sites.append(s)
                assert sum(s["samples"] for s in sites) == p["samples"]
                out["frame_report_residual"] = p["samples"] - sum(f["samples"] for f in frames.values())
                bands = {a: sum(s["samples"] for s in sites if s["area"] == a) for a in AREAS}
                out["profile"] = {k: v for k, v in p.items() if k not in ("frames", "self_sites")}
                out["profile"].update(frames=frames, self_sites=sites, area_samples=bands,
                                      background_samples=sum(s["samples"] for s in sites if s["background"]))
                out["top20_self"] = rank(sites, p["samples"])[:20]
                all_sites.extend(sites)
                samples += p["samples"]
                missed += p["missed_samples"]
            entry["routes"][route] = out
        if mode != "native":
            app["profiles"][mode] = {"samples": samples, "missed_samples": missed,
                "area_samples": {a: sum(s["samples"] for s in all_sites if s["area"] == a) for a in AREAS},
                "ranked_self": rank(all_sites, samples)}
            pooled[mode].extend(all_sites)
            denominators[mode] += samples
        result["captures"].append(entry)
    for mode, sites in pooled.items():
        result["pooled"][mode] = {"samples": denominators[mode],
            "area_samples": {a: sum(s["samples"] for s in sites if s["area"] == a) for a in AREAS},
            "ranked_self": rank(sites, denominators[mode])}
    return result


if __name__ == "__main__":
    output, *inputs = sys.argv[1:]
    result = export([Path(p) for p in inputs])
    Path(output).write_text(json.dumps(result, separators=(",", ":")) + "\n")
    print(f"Exported {len(result['captures'])} captures / {len(result['apps'])} apps to {output}; every self/area denominator reconciles.")
