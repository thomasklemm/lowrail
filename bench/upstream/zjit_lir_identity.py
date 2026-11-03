# Generated-code identity check for compiler-speed changes (bet Z6).
# Dump with: setarch x86_64 -R ruby --zjit --zjit-dump-lir=scratch_split BENCH > dump.out
# python3 zjit_lir_identity.py base.out other.out  -> compiled units of other.out that base.out lacks.
# Masks addresses, install prefixes, side-exit and vreg numbers and CodePtr offsets, and compares
# each unit as a sorted line multiset, because side exits come out in HashMap order.
import re, sys, hashlib, collections
SUB = [(re.compile(r'/home/[^ ]*?/rubies/[a-z0-9]+/'), '/PREFIX/'), (re.compile(r'0x[0-9a-f]{6,}'), '0xADDR'),
       (re.compile(r'side_exit_\d+'), 'side_exit_N'), (re.compile(r'\bv\d+\b'), 'vN'),
       (re.compile(r'CodePtr\(\d+\)'), 'CodePtr(N)')]
def units(path):
    c = collections.Counter()
    for u in open(path, errors='replace').read().split('LIR scratch_split:\n'):
        if not u.strip(): continue
        lines = u.splitlines()
        for r, s in SUB: lines = [r.sub(s, l) for l in lines]
        c[hashlib.sha256('\n'.join(sorted(lines)).encode()).hexdigest()] += 1
    return c
a, b = units(sys.argv[1]), units(sys.argv[2])
print(f'units={sum(b.values())} differ={sum((b - a).values())}')
