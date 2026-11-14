#!/bin/bash
# rows_sweep.sh OUT TREE...: rows_micro.rb for ROWS 1 20 1000 10000 x WIDTH 5 30 300, interp and YJIT.
set -u
out=$1; shift; mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for mode in ${MODES:-interp yjit}; do
  flag=; smc=; [ $mode = yjit ] && flag=--yjit && smc=--smc-check=all-non-file
  for tree in "$@"; do
    for w in ${WIDTHS:-5 30 300}; do for r in ${ROWS:-1 20 1000 10000}; do
      RAILS=$HOME/c9/$tree WIDTH=$w ROWS=$r $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc \
        "$ruby" $flag "$here/rows_micro.rb" 2>/dev/null | sed "s/^/$tree $mode /" >> "$out/rows.txt"
    done; done
  done
done
