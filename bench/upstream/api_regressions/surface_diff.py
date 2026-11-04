import json, sys, re
a = json.load(open(sys.argv[1]))["entries"]
b = json.load(open(sys.argv[2]))["entries"]

def split(k):
    m = re.match(r"^(.*?)([#.])([^#.:][^#.]*)$", k)
    return (m.group(1), m.group(2), m.group(3)) if m else (k, None, None)

gone_mods = {k for k, v in a.items() if v.get("kind") in ("class", "module") and k not in b}
def under_gone(base):
    parts = base.split("::")
    return any("::".join(parts[:i]) in gone_mods for i in range(1, len(parts) + 1))

out = {"removed": [], "now_private": [], "removed_private": [], "sig": [], "mods": [], "consts": [], "super": []}
for k, v in sorted(a.items()):
    base, sep, meth = split(k)
    if sep is None:
        if v.get("kind") in ("class", "module"):
            if k not in b:
                if not under_gone("::".join(k.split("::")[:-1])):
                    out["mods"].append((k, v["kind"]))
            elif v.get("super") != b[k].get("super"):
                out["super"].append((k, v.get("super"), b[k].get("super")))
        elif k not in b:
            out["consts"].append((k, v.get("kind"), v.get("class") or v.get("to")))
        continue
    if under_gone(base) or base not in b:
        continue
    pub_key, priv_key = ("all_i", "all_ip") if sep == "#" else ("all_s", "all_sp")
    pub_b, priv_b = set(b[base].get(pub_key, [])), set(b[base].get(priv_key, []))
    if v["vis"] in "+#":
        if meth in pub_b:
            pass
        elif meth in priv_b:
            out["now_private"].append((k, v["sig"], v["src"]))
        else:
            out["removed"].append((k, v["sig"], v["src"]))
    else:
        if meth not in pub_b and meth not in priv_b:
            out["removed_private"].append((k, v["sig"], v["src"]))
    if k in b and v.get("sig") != b[k].get("sig") and v["vis"] in "+#":
        out["sig"].append((k, v["sig"], b[k]["sig"], b[k].get("src")))

for sec, rows in out.items():
    print(f"## {sec} ({len(rows)})")
    for r in rows:
        print("-", " | ".join(str(x) for x in r))
    print()
