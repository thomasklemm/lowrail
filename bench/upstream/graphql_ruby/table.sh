#!/bin/bash
# table.sh <tag> <revs...> : per-iteration Ir = (n6 - n1)/5 per rev and rep
tag=$1; shift
for rev in "$@"; do for r in a b; do
  f1=/tmp/gqb/cg/$tag.$rev.$r.1.log; f6=/tmp/gqb/cg/$tag.$rev.$r.6.log
  i1=$(grep "I *refs" $f1 2>/dev/null | awk '{print $NF}' | tr -d ,); i6=$(grep "I *refs" $f6 2>/dev/null | awk '{print $NF}' | tr -d ,)
  [ -n "$i1" ] && [ -n "$i6" ] && echo "$rev $r $(( (i6-i1)/5 ))" || echo "$rev $r pending"
done; done
