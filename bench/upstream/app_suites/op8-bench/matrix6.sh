#!/bin/bash
# matrix6.sh -> results.tsv: tree workload rep N Ir, as matrix5.sh. 2026-11-27, Rafael's review on OP8: trees under
# ~/workspace/repos at main 9e82904f18 (rails-main, rails-ctl), OP8 rebased onto it (rails), the Serialized-only
# type-level freezable? (rails-rafael) and the same plus Helpers::Mutable#freezable? false (rails-typelevel). One
# Gemfile.<tree> each, copied from Gemfile.rails-main, with the same lockfile apart from the path.
# Summary: ruby summary4.rb results-9e82904f18.tsv
cd "$(dirname "$0")"; RB=$(~/.local/bin/mise where ruby@4.0.9)/bin/ruby
trees=(rails-main rails-ctl rails rails-rafael rails-typelevel)
jobs=(); for rep in 1 2 3; do for w in newplain newcont newnested newnull newjson; do for t in "${trees[@]}"; do jobs+=("$t $w $rep"); done; done; done
run() { set -- $1
  ir=$(RAILS_PATH=$HOME/workspace/repos/$1 BUNDLE_GEMFILE=$PWD/Gemfile.$1 valgrind --tool=callgrind --toggle-collect=rb_ary_initialize --callgrind-out-file=/dev/null $RB driver.rb $2 1000 2>&1 | sed -n 's/.*Collected : //p')
  echo "$1 $2 $3 1000 $ir" >> results.tmp; }
: > results.tmp; i=0; for j in "${jobs[@]}"; do run "$j" & i=$((i+1)); [ $((i % 2)) -eq 0 ] && wait; done; wait
sort results.tmp > results.tsv; echo done > results.done
