#!/bin/bash
# percall.sh CASES CASE N REPS TREE...   per-call Callgrind instructions of CASE (irm.rb, APP=none) in each Rails tree.
# Callgrind counts only inside rb_ary_cycle: N calls after 2,000 warmups, GC disabled, fixed heap. Ir/call is
# inclusive (the call and everything below it, plus the loop's block call). RUBY defaults to 4.0.9 from mise.
# Prints one line per tree and repetition: tree, rep, Ir/call, objects/call.
cases=$(realpath $1) c=$2 n=$3 reps=$4; shift 4
here=$(dirname $(realpath $0))
RUBY=${RUBY:-$(mise where ruby@4.0.9)/bin/ruby}
VALGRIND=${VALGRIND:-$HOME/vg-brk512/bin/valgrind}  # script/bench-valgrind: the fixed heap needs its larger brk
O=${OUT:-/tmp/percall}; mkdir -p $O
for r in $(seq $reps); do
  for t in "$@"; do
    log=$O/$(basename $cases .rb)-$c-$(basename $t)-$r.log
    PATH=$(dirname $RUBY):$PATH BUNDLE_GEMFILE=$t/Gemfile RAILS_PATH=$t APP=none \
    RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
    RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000 \
      $VALGRIND --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null \
      $RUBY -rbundler/setup $here/irm.rb $cases $c $n > $log 2>&1
    ir=$(grep -o 'Collected : [0-9]*' $log | grep -o '[0-9]*$')
    ob=$(grep -o 'OBJECTS_PER_CALL [0-9.]*' $log | awk '{print $2}')
    [ -z "$ir" ] && { echo "$t $r FAILED ($log)"; tail -3 $log; continue; }
    awk -v t=$(basename $t) -v r=$r -v ir=$ir -v n=$n -v ob=$ob 'BEGIN{printf "%-4s %s %10.1f %s\n", t, r, ir/n, ob}'
  done
done
