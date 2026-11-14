#!/bin/bash
# matrix5.sh -> results.tsv: tree workload rep N Ir, as matrix4.sh. 2026-11-14 recheck after rails#59141: trees
# rails-main and rails-ctl at main 50c54eed06, rails at OP8 71c77e3a01, one Gemfile.<tree> each with the same lockfile
# apart from the path. Summary: ruby summary4.rb results-50c54eed06.tsv
cd "$(dirname "$0")"; RB=$(~/.local/bin/mise where ruby@4.0.9)/bin/ruby
jobs=(); for rep in 1 2 3; do for w in newplain newcont newnested; do for t in rails-main rails-ctl rails; do jobs+=("$t $w $rep"); done; done; done
run() { set -- $1
  ir=$(RAILS_PATH=$HOME/workspace/repos/$1 BUNDLE_GEMFILE=$PWD/Gemfile.$1 valgrind --tool=callgrind --toggle-collect=rb_ary_initialize --callgrind-out-file=/dev/null $RB driver.rb $2 1000 2>&1 | sed -n 's/.*Collected : //p')
  echo "$1 $2 $3 1000 $ir" >> results.tmp; }
: > results.tmp; i=0; for j in "${jobs[@]}"; do run "$j" & i=$((i+1)); [ $((i % 2)) -eq 0 ] && wait; done; wait
sort results.tmp > results.tsv; echo done > results.done
