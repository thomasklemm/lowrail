#!/bin/bash
# matrix.sh RUBY LABEL -> results-LABEL.tsv: tree workload rep Ir collected inside the measured loop only
# (callgrind --toggle-collect=rb_ary_initialize around Array.new(N) { work }, GC disabled; new* N=1000, rbar N=10)
. ~/w/env.sh
RB=$1; L=$2; SUF=$3; cd ~/w/op8bench
out=results-$L.tsv; : > $out.tmp
jobs=()
for rep in 1 2 3 4 5; do for w in newplain newcont rbar; do for t in ${TREES:-rails-main rails-ctl rails-fix3}; do jobs+=("$t $w $rep"); done; done; done
run() { set -- $1; n=1000; [ $2 = rbar ] && n=10
  ir=$(RAILS_PATH=$HOME/w/$1 BUNDLE_GEMFILE=$PWD/Gemfile.$1$SUF valgrind --tool=callgrind --toggle-collect=rb_ary_initialize --callgrind-out-file=/dev/null $RB driver.rb $2 $n 2>&1 | sed -n 's/.*Collected : //p')
  echo "$1 $2 $3 $n $ir" >> $out.tmp; }
i=0; for j in "${jobs[@]}"; do run "$j" & i=$((i+1)); [ $((i % 3)) -eq 0 ] && wait; done; wait
sort $out.tmp > $out; rm $out.tmp; echo done > $out.done
exec sleep infinity
