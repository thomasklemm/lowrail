"""Apply Ragel's content changes to graphql-ruby's committed lexer.c without reformatting it.

usage: python3 -I apply_ragel_diff.py <ragel output for base .rl> <ragel output for new .rl> <committed lexer.c> <out>

The committed lexer.c equals Ragel 7.0.4's output for the same lexer.rl except for whitespace and
#line numbers. Lines are aligned base<->committed and base->new; unchanged lines keep the committed
text, changed or added lines take Ragel's text, lexer.rl #line numbers come from Ragel's new output,
and lexer.c self-references are renumbered to line + 1 (the committed file's rule).
"""
import difflib, re, sys
B, N, C = (open(p).read().split('\n') for p in sys.argv[1:4])
SELF = '"graphql-c_parser/ext/graphql_c_parser_ext/lexer.c"'
def key(l):
    if l.startswith('#line '): return '#line ' + l.split(' ', 2)[2]
    return re.sub(r'\s+', '', l)
kB, kN, kC = [list(map(key, x)) for x in (B, N, C)]
assert [k for k in kB if k] == [k for k in kC if k], 'committed file differs from Ragel base beyond whitespace'
b2c = {}
for t, i1, i2, j1, j2 in difflib.SequenceMatcher(None, kB, kC, autojunk=False).get_opcodes():
    if t == 'equal':
        for k in range(i2 - i1): b2c[i1 + k] = j1 + k
out = []
for t, i1, i2, j1, j2 in difflib.SequenceMatcher(None, kB, kN, autojunk=False).get_opcodes():
    if t == 'equal':
        for k in range(i2 - i1):
            bi, ni = i1 + k, j1 + k
            out.append(N[ni] if N[ni].startswith('#line ') else (C[b2c[bi]] if bi in b2c else N[ni]))
    else:
        out.extend(N[j1:j2])
for i, l in enumerate(out):
    if l.startswith('#line ') and l.endswith(SELF): out[i] = '#line %d %s' % (i + 2, SELF)
open(sys.argv[4], 'w').write('\n'.join(out))
