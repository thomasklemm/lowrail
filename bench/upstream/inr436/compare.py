import json, sys
def load(p): return {(d['case'], d['visit'], d['devtools']): d for d in map(json.loads, open(p))}
a, b = load(sys.argv[1]), load(sys.argv[2])
keys = ('props', 'json', 'meta', 'calls', 'recorder', 'error')
diff = {}
for k in a:
    fields = [f for f in keys if a[k].get(f) != b[k].get(f)]
    if fields: diff.setdefault(k[0], []).append((k[1], k[2], fields))
print(f"{sys.argv[1].split('/')[-1]} vs {sys.argv[2].split('/')[-1]}: {sum(map(len, diff.values()))}/{len(a)} rows differ")
for case, rows in diff.items():
    print(' ', case, [f"{v}{'+dt' if d else ''}:{'/'.join(f)}" for v, d, f in rows])
if len(sys.argv) > 3:
    for k in a:
        if k[0] == sys.argv[3] and (len(sys.argv) < 5 or k[1] == sys.argv[4]):
            print(k, '\n  A', {f: a[k].get(f) for f in keys if f not in ('json',)}, '\n  B', {f: b[k].get(f) for f in keys if f not in ('json',)})
