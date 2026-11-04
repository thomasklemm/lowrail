#!/bin/bash
# ns_pinned.sh OUT "case:cand ..." ROUNDS N : wall ns per call (GC off), Ruby 4.0.9 interpreter and YJIT,
# pinned to one CPU, variants main / aa / candidate in a rotating order each round
out=$1; specs=$2; rounds=${3:-15}; N=${4:-30000}; mkdir -p $out; : > $out/ns.tsv
R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby; B=$(cd $(dirname $0) && pwd)/micro.rb
for s in $specs; do c=${s%%:*}; cand=${s#*:}
  for m in i49 y49; do f=""; [ $m = y49 ] && f="--yjit"
    for r in $(seq 1 $rounds); do
      vs=("main:main" "aa:aa" "cand:$cand"); k=$((r % 3)); order=("${vs[@]:$k}" "${vs[@]:0:$k}")
      for v in "${order[@]}"; do name=${v%%:*}; d=${v#*:}
        ns=$(RAILS=$HOME/w/wt/$d WARMUP=5000 taskset -c ${CPU:-3} $R $f $B $c $N ns)
        printf "%s\t%s\t%s\t%s\t%s\n" $c $m $name $r $ns >> $out/ns.tsv
      done
    done
  done
done
echo NSDONE
