#!/bin/bash
# attr_sweep.sh OUT TREE... : attr_micro.rb under census 8's patched Callgrind,
# fixed heap, for each tree (a Rails checkout under ~/c9), mode (MODES, default
# "interp yjit") and width (WIDTHS, default "5 30 100 300"), one process each.
# Writes OUT/TREE-MODE-wWIDTH.txt. A tree listed twice under two names is the A/A.
set -u
out=$1; shift
mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for w in ${WIDTHS:-5 30 100 300}; do
  for mode in ${MODES:-interp yjit}; do
    for tree in "$@"; do
      f=$out/$tree-$mode-w$w.txt
      [ -s "$f" ] && continue
      flag=; smc=
      [ $mode = yjit ] && flag=--yjit && smc=--smc-check=all-non-file
      RAILS=$HOME/c9/$tree WIDTH=$w $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc \
        "$ruby" $flag "$here/attr_micro.rb" > "$f.tmp" 2> "$f.log" && mv "$f.tmp" "$f"
      echo "$tree $mode w$w $(date -u +%T) $(wc -l < "$f" 2>/dev/null)"
    done
  done
done
