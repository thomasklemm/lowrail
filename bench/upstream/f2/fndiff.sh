#!/bin/bash
# fndiff.sh DIR CASE N: self Ir per iteration by function, (W(N) - W(0)) / N, from float_ir.sh KEEP=1 output
d=$1 c=$2 n=$3
sum() { callgrind_annotate --auto=no --inclusive=no --threshold=100 "$1" 2>/dev/null | sed -n '/file:function/,$p' | tail -n +3 |
  sed -E 's/\([ 0-9.]+%\)//' | awk 'NF>=2 {ir=$1; gsub(",","",ir); fn=$2; sub(/^.*:/,"",fn); s[fn]+=ir} END{for(k in s) print k, s[k]}'; }
join -a1 -a2 -e 0 -o 0,1.2,2.2 <(sum $d/$c-0.cg | sort) <(sum $d/$c-$n.cg | sort) |
  awk -v n=$n '{v=($3-$2)/n; if (v>=0.5 || v<=-0.5) printf "%7.1f %s\n", v, $1}' | sort -rn
