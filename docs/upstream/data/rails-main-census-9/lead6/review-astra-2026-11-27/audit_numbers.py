import json
import pathlib
import re
import tarfile

root = pathlib.Path('bench/upstream/lead6/body')
for run in sorted(root.glob('*2026-11-27')):
    result = json.loads((run / 'results.json').read_text())
    print('\nRUN', run.name, 'n=', result['n'])
    print('PINS', result['sides'])
    with tarfile.open(run / 'raw/callgrind.tar.gz') as archive:
        totals = {}
        for entry in archive:
            if entry.name.endswith('.callgrind'):
                raw = archive.extractfile(entry).read()
                totals[pathlib.Path(entry.name).name] = int(re.findall(rb'^totals: (\d+)', raw, re.M)[-1])
    for key, expected in result['instructions'].items():
        mode, name = key.split(' ', 1)
        slug = re.sub(r'\W+', '_', name)
        values = {}
        for side in ['base', 'base2', 'candidate']:
            def total(n):
                matches = [v for k, v in totals.items() if re.fullmatch(
                    rf'ir-{mode}-\d+-{re.escape(slug)}-{side}-n{n}\.callgrind', k)]
                assert len(matches) == 1, (key, side, n, matches)
                return matches[0]
            values[side] = (total(result['n']) - total(0)) / result['n']
        mean = (values['base'] + values['base2']) / 2
        change = (values['candidate'] / mean - 1) * 100
        aa = abs(values['base'] - values['base2']) / mean * 100
        assert abs(mean - expected['base']) < 1e-6
        assert abs(values['candidate'] - expected['candidate']) < 1e-6
        assert abs(change - expected['change'] * 100) < 1e-6
        print(key, values, 'mean=', mean, 'change%= ', round(change, 4), 'AA%=', round(aa, 4))
        for log in sorted((run / 'raw').glob(f'ir-{mode}-*-{slug}-*.log')):
            if log.name.endswith('.valgrind.log'):
                assert not re.search('brk segment overflow|Cannot map memory to grow brk segment', log.read_text())
            else:
                for line in log.read_text().splitlines():
                    if line.startswith('jit '):
                        pairs = re.findall(r'(\w+)=([^ >]*)>([^ ]*)', line)
                        print(' ', log.name, pairs)
                        assert all(before == after for _, before, after in pairs)
    for log in sorted((run / 'raw').glob('objects-*.log')):
        print(log.name, log.read_text().strip())
print('\nAll archived instruction totals match results.json; all recorded present JIT counters are flat.')
