from collections import Counter, defaultdict
from pathlib import Path
import json
import re
import tarfile

root = Path('/home/user/workspace/repo')
out = root / 'bench/upstream/l3/results/review-thermos-sol-2026-11-27/head-319e55a661'
item = (root / 'bench/upstream/pr-queue/items/L3.md').read_text()
(out / 'item-snapshot.md').write_text(item)
body = item.split('# Build attribute Hashes without copying the lazy row\n', 1)[1]
script = re.search(r'```ruby\n(.*?)\n```', body, re.S)[1]
assert script.strip() == (root / 'bench/upstream/l3/l3_ips.rb').read_text().strip()
(out / 'body-script.rb').write_text(script + '\n')
print('Body Ruby script equals l3_ips.rb byte-for-byte excluding edge whitespace.')
raw = (root / 'bench/upstream/l3/results/rebuild3-2026-11-27/body-ips.txt').read_text()
normalize = lambda line: ' '.join(line.split())
samples = defaultdict(list)
for line in raw.splitlines():
    match = re.match(r'(main2?|l3) r(\d+):\s*(.*)', line)
    if match:
        label = re.match(r'(.+?)\s+([\d.]+)([kM]?) \(', match[3])
        ips = float(label[2]) * {'': 1, 'k': 1000, 'M': 1000000}[label[3]]
        samples[match[1]].append((int(match[2]), normalize(match[3]), label[1].strip(), ips))
for tree, rows in samples.items():
    rounds = Counter(row[0] for row in rows)
    assert rounds == Counter({n: 2 for n in range(1, 7)}), rounds
    print(f'{tree}: 6 full rounds, two results per round: {dict(rounds)}')
for line in body.splitlines():
    match = re.match(r'(before|after):\s*(.*)', line)
    if match:
        tree = 'main' if match[1] == 'before' else 'l3'
        found = [row for row in samples[tree] if row[1] == normalize(match[2])]
        assert len(found) == 1, line
        row = found[0]
        assert row[3] == max(r[3] for r in samples[tree] if r[2] == row[2])
        print(f'Exact quoted best line, {tree} round {row[0]}: {row[1]}')
for name in ['Marshal.dump', 'attributes_for_database']:
    best = {tree: max(r[3] for r in rows if r[2] == name) for tree, rows in samples.items()}
    slowest = min(r[3] for r in samples['l3'] if r[2] == name)
    fastest_base = max(r[3] for tree in ['main', 'main2'] for r in samples[tree] if r[2] == name)
    assert slowest > fastest_base
    print(f'{name}: {best}, head gain {(best["l3"]/best["main"]-1)*100:.2f}%, A/A {(best["main2"]/best["main"]-1)*100:+.2f}%, slowest head {slowest} > fastest control {fastest_base}')
assert body.count('ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]') == 1
assert raw.splitlines()[0] == 'ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]'
print('Quoted Ruby description matches raw output.')
print('Schema columns = 1 id + 9 * (string + integer + boolean) + 2 timestamps = 30.')

run = root / 'bench/upstream/l3/body/L3c-2026-11-27'
data = json.loads((run / 'results.json').read_text())
assert data['sides']['base']['head'] == '088fc0cf61e4ba0c7987decafacc69adb3e22eec'
assert data['sides']['candidate']['head'] == '319e55a661702e756a5140aeec2300aa55efa0f4'
for mode in ['interp', 'yjit']:
    for side, key in [('base', 'base1'), ('base2', 'base2'), ('candidate', 'candidate')]:
        for line in (run / f'raw/objects-{mode}-{side}.log').read_text().splitlines():
            name, count = line.removeprefix('objects ').split('\t')
            assert data['objects'][f'{mode} {name}'][key] == float(count)
    for name in ['attributes_for_database', 'attributes_before_type_cast']:
        counts = data['objects'][f'{mode} {name}']
        assert (counts['base1'], counts['base2'], counts['candidate']) == (4, 4, 2)
        print(f'{mode} {name} objects: raw base=4, base2=4, head=2; A/A=0')
print('All retained raw object rows equal results.json; body allocations match both modes.')
with tarfile.open(run / 'raw/callgrind.tar.gz') as archive:
    for mode in ['interp', 'yjit']:
        for number, name in enumerate(['Marshal.dump', 'attributes_for_database', 'attributes_before_type_cast', 'MessagePack dump'], 1):
            values = {}
            for side, key in [('base', 'base1'), ('base2', 'base2'), ('candidate', 'candidate')]:
                totals = {}
                for n in [0, data['n']]:
                    stem = f'ir-{mode}-{number}-{name.replace(" ", "_").replace(".", "_")}-{side}-n{n}'
                    text = archive.extractfile(stem + '.callgrind').read().decode()
                    totals[n] = int(re.findall(r'^totals: (\d+)', text, re.M)[-1])
                    log = (run / f'raw/{stem}.log').read_text()
                    if mode == 'yjit':
                        counters = re.findall(r'(compiled_iseq_count|compiled_block_count|invalidation_count)=(\d+)>(\d+)', log)
                        assert len(counters) == 3 and all(before == after for _, before, after in counters)
                values[key] = (totals[data['n']] - totals[0]) / data['n']
            entry = data['instructions'][f'{mode} {name}']
            for key, value in values.items():
                assert entry[key] == value, (mode, name, key, entry[key], value)
            base = (values['base1'] + values['base2']) / 2
            change = (values['candidate'] / base - 1) * 100
            aa = abs(values['base1'] - values['base2']) / base * 100
            print(f'{mode} {name}: raw counts {values}; change {change:.1f}%, A/A {aa:.2f}%')
print('All eight instruction rows independently reconstructed from raw Callgrind totals; all 24 YJIT windows flat.')
print('Body prose words excluding fences:', len(re.sub(r'```.*?```', '', body, flags=re.S).split()))
