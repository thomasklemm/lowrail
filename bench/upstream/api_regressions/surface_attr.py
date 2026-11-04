import json, re, subprocess, sys, os
from concurrent.futures import ThreadPoolExecutor
REPO = os.path.expanduser("~/w/rails")
R81 = os.path.expanduser("~/w/wt/r81")
MB = subprocess.check_output(["git", "-C", REPO, "merge-base", "up/8-1-stable", "up/main"], text=True).strip()

def git(*a):
    return subprocess.run(["git", "-C", REPO, *a], capture_output=True, text=True).stdout

items = []
txt = open(sys.argv[1]).read()
for line in open(os.path.expanduser("~/w/out/surface/removed_refined.txt")):
    k = line[2:].split(" | ")[0]; src = line.split(" | ")[2].split(" || ")[0].strip()
    items.append(("method", k, src))
for sec in ("now_private", "mods", "consts"):
    part = txt.split(f"## {sec} (")[1].split("\n## ")[0]
    for l in part.splitlines()[1:]:
        if l.startswith("- "):
            f = l[2:].split(" | ")
            items.append((sec, f[0], f[2] if sec == "now_private" else ""))

def name_of(kind, k):
    if kind in ("method", "now_private"):
        return re.split(r"[#.]", k)[-1]
    return k.split("::")[-1]

def deprecated_in_81(kind, k, src):
    nm = name_of(kind, k)
    m = re.match(r"(.*?):(\d+)$", src or "")
    if m and os.path.exists(os.path.join(R81, m.group(1))):
        lines = open(os.path.join(R81, m.group(1))).read().splitlines()
        i = int(m.group(2)) - 1
        window = "\n".join(lines[max(0, i - 6): i + 12])
        if re.search(r"deprecat", window, re.I):
            return "near-def"
    out = subprocess.run(["grep", "-rlE", rf"deprecat.*\b{re.escape(nm)}\b|\b{re.escape(nm)}\b.*deprecat", "--include=*.rb", R81 + "/" + (m.group(1).split('/')[0] if m else "")], capture_output=True, text=True).stdout
    return "grep:" + ",".join(p.replace(R81 + "/", "") for p in out.split()[:2]) if out.strip() else ""

def attribute(item):
    kind, k, src = item
    nm = name_of(kind, k)
    path = src.split(":")[0] if src and not src.startswith("/") else None
    pat = f"def {nm}" if kind in ("method", "now_private") and not nm.endswith("=") else nm.rstrip("=")
    if kind == "mods":
        pat = f"{('class' if True else '')} {nm}"
    args = ["log", "--format=%H\t%ad\t%an\t%s", "--date=short", f"{MB}..up/main", f"-S{pat}"]
    if path:
        args += ["--", path]
    else:
        args += ["--", "*/lib", "*/app"]
    log = git(*args).strip().splitlines()
    if not log and kind in ("method", "now_private"):
        log = git("log", "--format=%H\t%ad\t%an\t%s", "--date=short", f"{MB}..up/main", f"-S{nm}", "--", path or "*/lib").strip().splitlines()
    c = log[0].split("\t") if log else ["", "", "", ""]
    pr = ""
    if c[0]:
        merges = git("log", "--merges", "--ancestry-path", "--format=%s", f"{c[0]}..up/main").strip().splitlines()
        for s in reversed(merges):
            mm = re.search(r"Merge pull request #(\d+)", s)
            if mm:
                pr = mm.group(1); break
        if not pr:
            mm = re.search(r"\(#(\d+)\)", c[3]); pr = mm.group(1) if mm else ""
    return {"kind": kind, "item": k, "src": src, "commit": c[0][:10], "date": c[1], "author": c[2], "subject": c[3], "pr": pr,
            "dep81": deprecated_in_81(kind, k, src)}

with ThreadPoolExecutor(8) as ex:
    rows = list(ex.map(attribute, items))
json.dump(rows, open(os.path.expanduser("~/w/out/surface/attributed.json"), "w"), indent=1)
print(len(rows))
