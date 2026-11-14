#!/bin/bash
# ir.sh OUT TREE WIDTH [CASE...]: attr_micro.rb (default case update1) under census 8's patched Callgrind,
# fixed heap, interpreter, for the Rails checkout ~/c9/TREE. Writes OUT/TREE-wWIDTH.txt. Two names for one
# commit are the A/A.
set -u
out=$1 tree=$2 w=$3; shift 3
mkdir -p "$out"
here=$(cd "$(dirname "$0")/.." && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
f=$out/$tree-w$w.txt
RAILS=$HOME/c9/$tree WIDTH=$w $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null \
  "$ruby" "$here/attr_micro.rb" "${@:-update1}" > "$f.tmp" 2> "$f.log" && mv "$f.tmp" "$f" && rm -f "$f.log"
echo "$tree w$w $(cat "$f" 2>/dev/null || tail -3 "$f.log")"
