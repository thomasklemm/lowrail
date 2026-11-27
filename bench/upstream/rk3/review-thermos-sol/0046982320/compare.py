import collections
import itertools
import json
import sys

counts = collections.Counter()
examples = collections.defaultdict(list)
with open(sys.argv[1]) as a, open(sys.argv[2]) as b:
    for i, (left, right) in enumerate(itertools.zip_longest(a, b), 1):
        assert left is not None and right is not None, 'unequal output lengths'
        x, y = json.loads(left), json.loads(right)
        counts['calls'] += 1
        if x == y:
            continue
        expected = json.loads(left)
        if expected[1] in ('utils', 'include') and expected[2][0:2] == ['error', 'ArgumentError'] and bytes(expected[2][2]).startswith(b'invalid %-encoding') and expected[2][-1] == 'ASCII-8BIT':
            expected[2][-1] = 'UTF-8'
        kind = 'message_encoding_only' if expected == y else 'unexpected'
        counts[kind] += 1
        if len(examples[kind]) < 8:
            examples[kind].append({'line': i, 'base': x, 'head': y})
print(json.dumps({'counts': counts, 'examples': examples}, indent=2))
sys.exit(1 if counts['unexpected'] else 0)
