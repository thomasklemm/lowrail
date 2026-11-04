import sys, collections
a=open(sys.argv[1]).read().splitlines(); b=open(sys.argv[2]).read().splitlines()
assert len(a)==len(b)
kinds=collections.Counter(); ex=collections.defaultdict(list)
for x,y in zip(a,b):
    if x==y: continue
    xa=x.split('|'); ya=y.split('|')
    z=xa[0].split(':')[0]
    old=xa[3]; new=ya[3]
    if old==new: k=(z,'advance only')
    elif 'Error' in old or 'Ambiguous' in old or 'PeriodNotFound' in old or 'Invalid' in old: k=(z,'old raised '+old.split()[0])
    elif 'Error' in new or 'Time ' not in new: k=(z,'new raised '+new)
    else: k=(z,'both times, differ')
    kinds[k]+=1
    if len(ex[k])<3: ex[k].append((xa[0],xa[1],xa[2],old,new, xa[4:] , ya[4:]))
for k,v in kinds.most_common(): 
    print(v,k)
    for e in ex[k]: print('   ',e)
