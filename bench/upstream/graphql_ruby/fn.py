import sys,collections
def load(p):
    d=collections.Counter(); fl=fn=None
    for l in open(p):
        if l.startswith('fl='): fl=l[3:].strip()
        elif l.startswith('fn='): fn=l[3:].strip()
        elif l[:1].isdigit() or l[:1]=='-':
            parts=l.split()
            if len(parts)>=2:
                try: d[(fl.split('/')[-1] if fl else '?',fn)]+=int(parts[1])
                except: pass
    return d
a=load(sys.argv[1]); b=load(sys.argv[2])
for k in a: a[k]-=b.get(k,0)
tot=sum(a.values()); print("total per-iter delta", tot//5)
for k,v in sorted(a.items(), key=lambda kv:-abs(kv[1]))[:14]: print(f"{v//5:>14,} {k[0]}:{k[1]}")
