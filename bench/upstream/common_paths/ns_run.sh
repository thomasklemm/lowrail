#!/bin/bash
# ns_run.sh OUT "case:cand ..." ROUNDS N : interleaved wall ns per call, rotating variant order each round
out=$1; specs=$2; rounds=${3:-7}; N=${4:-20000}; mkdir -p $out; : > $out/ns.tsv
for s in $specs; do c=${s%%:*}; cand=${s#*:}
  for m in i49 y49; do f=""; [ $m = y49 ] && f="--yjit"
    for r in $(seq 1 $rounds); do
      vs=("main:main" "aa:aa" "cand:$cand"); k=$((r % 3)); order=("${vs[@]:$k}" "${vs[@]:0:$k}")
      for v in "${order[@]}"; do name=${v%%:*}; d=${v#*:}
        ns=$(cd ~/work/wt/$d && BUNDLE_GEMFILE=$PWD/Gemfile WARMUP=5000 mise exec ruby@4.0.9 -- ruby $f ~/work/bench/micro.rb $c $N ns)
        printf "%s\t%s\t%s\t%s\t%s\n" $c $m $name $r $ns >> $out/ns.tsv
      done
    done
  done
done
echo NSDONE
