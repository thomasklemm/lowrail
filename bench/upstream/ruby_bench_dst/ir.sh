#!/bin/bash
# ir.sh OUTDIR "variants" "cases" REPS  -> prints variant case rep Ir/op
out=$1; mkdir -p $out; variants=$2; cases=$3; reps=${4:-2}; N=${N:-2000}
jobs=$out/jobs.txt; : > $jobs
for v in $variants; do for c in $cases; do for r in $(seq 1 $reps); do for n in 0 $N; do echo "$v $c $r $n" >> $jobs; done; done; done; done
one() {
  v=$1 c=$2 r=$3 n=$4
  BUNDLE_GEMFILE=$HOME/w/gf/$v/Gemfile PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH \
    setarch -R valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle \
    --callgrind-out-file=/dev/null ruby $HOME/w/bench/${MICRO:-dst_micro.rb} $c $n ir > $out/$v-$c-$r-$n.out 2>&1
}
export -f one; export out MICRO
xargs -P ${P:-4} -L 1 bash -c 'one "$@"' _ < $jobs
for v in $variants; do for c in $cases; do for r in $(seq 1 $reps); do
  a=$(grep -o 'Collected : [0-9]*' $out/$v-$c-$r-0.out | grep -o '[0-9]*$'); b=$(grep -o 'Collected : [0-9]*' $out/$v-$c-$r-$N.out | grep -o '[0-9]*$')
  echo "$v $c $r $(( (b - a) / N ))"
done; done; done
