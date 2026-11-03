# ir_table.py: Ir per call = (Ir(N=5000) - Ir(N=0)) / 5000, from callgrind's "Collected" line.
import re, glob, os, collections
def ir(f):
    m = re.search(r'Collected : (\d+)', open(f).read()); return int(m.group(1)) if m else None
rows = collections.OrderedDict()
for f in sorted(glob.glob('/tmp/w/open/ir/*-5000.out')):
    c, v, m = os.path.basename(f)[:-9].rsplit('-', 2)[0], None, None
    base = os.path.basename(f)[:-9]; parts = base.split('-'); m = parts[-1]
    rest = '-'.join(parts[:-1]); case, v = rest.split('-', 1)
    a, b = ir(f), ir(f.replace('-5000.out', '-0.out'))
    if a is None or b is None: continue
    rows.setdefault((case, m), {})[v] = (a - b) / 5000
print('| Case | Mode | main Ir | A/A % | variant | Ir | Δ | Δ % |'); print('| --- | --- | ---: | ---: | --- | ---: | ---: | ---: |')
for (case, m), r in rows.items():
    if 'main' not in r or 'aa' not in r: continue
    mn = r['main']; aa = 100 * (r['aa'] - mn) / mn
    for v, x in r.items():
        if v in ('main', 'aa'): continue
        print(f'| {case} | {m} | {mn:,.0f} | {aa:+.2f}% | {v} | {x:,.0f} | {x - mn:+,.0f} | {100 * (x - mn) / mn:+.2f}% |')
