# Summarize per-compile side-exit footprints (bet Z9). Build ruby with zjit_exit_footprint.patch (measurement
# only), run a benchmark with ZJIT_EXIT_LOG=1, then: python3 zjit_exit_footprint.py stderr.log
# Each Z9EXIT line: location, exit bytes, unique exits, local stores, stack stores, max locals in one exit.
import sys
def solve(M, v):
    n = len(v); M = [r[:] + [v[i]] for i, r in enumerate(M)]
    for i in range(n):
        p = max(range(i, n), key=lambda k: abs(M[k][i])); M[i], M[p] = M[p], M[i]
        for k in range(n):
            if k != i:
                f = M[k][i] / M[i][i]; M[k] = [a - f * b for a, b in zip(M[k], M[i])]
    return [M[i][n] / M[i][i] for i in range(n)]
rows = [l.rstrip('\n').split('\t')[1:] for l in open(sys.argv[1], errors='replace') if l.startswith('Z9EXIT\t')]
rows = [(name, *map(int, rest)) for name, *rest in rows]
total = sum(r[1] for r in rows); exits = sum(r[2] for r in rows)
print(f'compiles={len(rows)} exit_bytes={total} exits={exits} bytes/exit={total / exits:.0f} max_locals={max(r[5] for r in rows)}')
X = [[float(r[2]), float(r[3]), float(r[4])] for r in rows]; y = [float(r[1]) for r in rows]
c = solve([[sum(x[i] * x[j] for x in X) for j in range(3)] for i in range(3)], [sum(x[i] * v for x, v in zip(X, y)) for i in range(3)])
share = [100 * c[i] * sum(x[i] for x in X) / sum(y) for i in range(3)]
print(f'fit: {c[0]:.1f} B/exit + {c[1]:.1f} B/local + {c[2]:.1f} B/stack slot; share fixed {share[0]:.0f}% locals {share[1]:.0f}% stack {share[2]:.0f}%')
for r in sorted(rows, key=lambda r: -r[1])[:10]:
    print(f'{r[1]:>8} B  exits={r[2]:>5} locals/exit={r[3] / r[2]:5.1f} max={r[5]:>3}  {r[0]}')
