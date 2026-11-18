# Usage: check.py BASE.jsonl OTHER.jsonl FIX_ON_BASE.jsonl FIX_ON_OTHER.jsonl
# Every row must change only where one of the two changes (BASE->OTHER, BASE->FIX_ON_BASE) changes it, and the
# rebased fix must then match that side; rows both change are printed for reading by hand.
import json, sys
F = ('props', 'json', 'meta', 'calls', 'recorder', 'error')
a, m, o, n = ({(d['case'], d['visit'], d['devtools']): d for d in map(json.loads, open(p))} for p in sys.argv[1:5])
eq = lambda x, y: all(x.get(f) == y.get(f) for f in F)
bad = []
for k in a:
    other, fix = not eq(a[k], m[k]), not eq(a[k], o[k])
    if other and fix:
        print('both change', k)
    elif other:
        eq(n[k], m[k]) or bad.append(k)
    elif fix:
        eq(n[k], o[k]) or bad.append(k)
    elif not eq(n[k], a[k]):
        bad.append(k)
print(f'{len(a)} rows, inconsistent: {bad}')
sys.exit(1 if bad else 0)
