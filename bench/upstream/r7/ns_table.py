import sys, statistics as st, collections
d=collections.defaultdict(list)
for l in open('/tmp/w/r7/ns.tsv'):
    p=l.rstrip('\n').split('\t')
    if len(p)<5 or not p[4]: continue
    d[(p[1],p[2],p[3])].append(float(p[4]))
print('| Case | Mode | rounds | main ns | A/A ns | cand ns | Δ % | A/A % |'); print('| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |')
for (c,m) in sorted({(k[0],k[1]) for k in d}):
    a,b,x=[st.median(d[(c,m,v)]) for v in ('main','aa','cand')]
    print(f'| {c} | {m} | {len(d[(c,m,"cand")])} | {a:,.0f} | {b:,.0f} | {x:,.0f} | {100*(x-a)/a:+.2f}% | {100*(b-a)/a:+.2f}% |')
