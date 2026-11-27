import json
import pathlib
import re
import subprocess

here = pathlib.Path(__file__).parent
root = pathlib.Path.cwd()
item = root / 'bench/upstream/pr-queue/items/L6.md'
text = item.read_text()
body = text[text.index('# Look up indexes inline'):]
(here / 'reviewed-body.md').write_text(body)
snippet = re.search(r'```ruby\n(.*?)\n```', body, re.S)[1]
(here / 'body-benchmark.rb').write_text(snippet + '\n')
assert 'In the measured `update!` of one column' in body
assert 'objects per call unchanged' not in body
assert 'ZJIT' not in body
assert '# Look up indexes inline in LazyIndexedAttributeSet#[] and #keys' == body.splitlines()[0]

run = root / 'docs/upstream/data/rails-main-census-9/lead6/review-thermos-sol-2026-11-27/body-rerun'
result = json.loads((run / 'results.json').read_text())
assert result['sides']['base']['head'] == '088fc0cf61e4ba0c7987decafacc69adb3e22eec'
assert result['sides']['candidate']['head'] == '8b1c6428ea056b3c5983372d85b85615ae3d3f45'
rates = {}
for log in sorted((run / 'raw').glob('ips-*.log')):
    raw = log.read_text()
    rate = float(re.search(r'serializable_hash\s+([\d.]+)k \(±', raw)[1]) * 1000
    side = log.stem.rsplit('-', 1)[1]
    rates.setdefault(side, []).append(rate)
    pairs = re.findall(r'(\w+)=(\d+)>(\d+)', raw)
    assert {key for key, _, _ in pairs} == {'compiled_iseq_count', 'compiled_block_count', 'invalidation_count'}
    assert all(before == after for _, before, after in pairs)
    print(log.name, rate, pairs)
assert len(rates) == 3 and all(len(v) == 3 for v in rates.values())
assert max(rates['base']) == 50195
assert max(rates['candidate']) == 52253
for log in ['ips-r2-base.log', 'ips-r1-candidate.log']:
    raw = (run / 'raw' / log).read_text()
    line = next(line.strip() for line in raw.splitlines() if 'μs/i' in line)
    assert line in body
    print('Body output matched exactly:', log, line)
assert result['ips']['serializable_hash']['jit']['flat']
assert len(result['ips']['serializable_hash']['jit']['windows']) == 9
print('Best base/base2/head:', max(rates['base']), max(rates['base2']), max(rates['candidate']))
print('All 9 IPS windows have present, unchanged JIT counters; body output matches retained logs.')
print('Lowrail:', subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip())
print('Body SHA256:', __import__('hashlib').sha256(body.encode()).hexdigest())
