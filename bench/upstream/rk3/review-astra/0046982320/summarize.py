import copy
import json
import pathlib
import re
import sys
from collections import Counter

root = pathlib.Path(sys.argv[1])
versions = ['2.7.3', '3.0.7', '3.1.7', '3.2.9', '3.3.9', '3.4.6', '4.0.9']
for version in versions:
    a = dict(json.loads(line) for line in (root / f'base-{version}-adversarial.jsonl').read_text().splitlines())
    b = dict(json.loads(line) for line in (root / f'rack-{version}-adversarial.jsonl').read_text().splitlines())
    assert a.keys() == b.keys()
    counts = Counter()
    for label, before in a.items():
        after = b[label]
        if before == after:
            continue
        if label.startswith('encoding '):
            normalized = copy.deepcopy(before)
            old_encoding = bytes(normalized[1][0][-1][1])
            new_encoding = bytes(after[1][0][-1][1])
            assert old_encoding in (b'ASCII-8BIT', b'BINARY') and new_encoding == b'UTF-8', label
            normalized[1][0][-1] = after[1][0][-1]
            assert normalized == after, label
            counts['Utils error message encoding'] += 1
        else:
            counts[label] += 1
    print(version, 'independent scenarios:', len(a), dict(counts))
    if version != '2.7.3':
        assert a['ractor'] == b['ractor'] and a['ractor'][0] == 'ok'
    for mode in ['clean', 'util', 'pure']:
        path = root / f'base-{version}-{mode}-replay.txt'
        if not path.exists():
            continue
        aa = path.read_text().splitlines()
        bb = (root / f'rack-{version}-{mode}-replay.txt').read_text().splitlines()
        assert len(aa) == len(bb) == 204073
        counts = Counter()
        for before, after in zip(aa, bb):
            if before == after:
                continue
            normalized = re.sub(r', "(?:BINARY|ASCII-8BIT)"\]$', ', "UTF-8"]', before)
            if normalized == after and ':err' in before:
                counts['message encoding'] += 1
            elif before.startswith('probe QueryParser parameters'):
                counts['parameter name'] += 1
            elif re.sub('0x[0-9a-f]+', '0xADDRESS', before) == re.sub('0x[0-9a-f]+', '0xADDRESS', after):
                counts['object address noise'] += 1
            elif 'BasicObject' in before and 'NoMethodError' in before and version == '3.1.7':
                counts['error_highlight moved source'] += 1
            else:
                raise AssertionError((before, after))
        print(version, mode, 'replay lines:', len(aa), dict(counts))
