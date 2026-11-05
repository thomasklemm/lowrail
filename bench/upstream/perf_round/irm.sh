#!/bin/bash
# irm.sh APP CASES CASE ITERS VARIANT...   per-call Ir (Callgrind, toggle on rb_ary_cycle) and objects, in parallel.
# RUBY=path (default 4.0.9), JIT=--yjit|--zjit, WARMUP=N. Prints one line per variant.
app=$1 cases=$2 c=$3 n=$4; shift 4
RUBY=${RUBY:-$(mise where ruby@4.0.9)/bin/ruby}
O=/tmp/irm; mkdir -p $O
tag=$(basename $RUBY | tr -dc a-z0-9)-${JIT:-i}-$app-$c-$n
smc=; [ -n "$JIT" ] && smc=--smc-check=all-non-file
for v in "$@"; do
  (export PATH=$(dirname $RUBY):$PATH RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
   if [ $app != none ]; then export BUNDLE_GEMFILE=$HOME/src/ruby-bench/benchmarks/$app/Gemfile.$v; [ $app = railsbench ] && cp /tmp/cc-railsbench-m.sqlite3 /tmp/irm-$v-$$.sqlite3 && export DATABASE_URL=sqlite3:/tmp/irm-$v-$$.sqlite3; fi
   [ $app = none ] && [ -n "$BG" ] && export BUNDLE_GEMFILE=$BG RUBYOPT="-rbundler/setup $RUBYOPT"
   export RAILS_PATH=$HOME/src/wt/$v APP=$app
   /home/user/vg-brk512/bin/valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null \
     $RUBY $JIT $HOME/src/irm.rb $cases $c $n > $O/$tag-$v.log 2>&1) &
done
wait
for v in "$@"; do
  ir=$(grep -o 'Collected : [0-9]*' $O/$tag-$v.log | grep -o '[0-9]*$')
  ob=$(grep -o 'OBJECTS_PER_CALL [0-9.]*' $O/$tag-$v.log | awk '{print $2}')
  if [ -z "$ir" ]; then echo "$v FAILED (see $O/$tag-$v.log)"; tail -5 $O/$tag-$v.log; continue; fi
  awk -v v=$v -v ir=$ir -v n=$n -v ob=$ob 'BEGIN{printf "%-10s Ir/call %10.1f  objects/call %s\n", v, ir/n, ob}'
done
