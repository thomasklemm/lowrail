# Prints the repro.sh rows where master and the head differ. Usage: python3 -I repro_table.py out/repro.txt
import collections
import re
import sys

cells = collections.OrderedDict()
cell = tree = None
for line in open(sys.argv[1]):
    line = line.rstrip("\n")
    m = re.match(r"== ruby (\S+) hashie (\S+) (base|head)(: bundle failed)?", line)
    if m:
        cell, tree = (m.group(1), m.group(2)), m.group(3)
        cells.setdefault(cell, {})[tree] = None if m.group(4) else {}
    elif " | " in line and cell and cells[cell][tree] is not None:
        key, value = line.split(" | ", 1)
        cells[cell][tree][key] = re.sub(r"0x[0-9a-f]+", "X", value)
for (ruby, hashie), trees in cells.items():
    base, head = trees.get("base"), trees.get("head")
    if head is None:
        print(f"ruby {ruby} hashie {hashie}: bundler refuses the head")
        continue
    rows = [k for k in base if head.get(k) != base[k]]
    print(f"ruby {ruby} hashie {hashie}: {len(base)} cases, {len(rows)} differ")
    for k in rows:
        print(f"  {k}\n    master {base[k]}\n    head   {head.get(k)}")
