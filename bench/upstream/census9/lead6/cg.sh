#!/bin/bash
# cg.sh OUT TREE WIDTH [CASE]: the cg_window.rb profile for ~/c9/TREE, fixed heap, interpreter.
# Writes OUT/TREE-wWIDTH.cg (the window's dump only).
set -u
out=$1 tree=$2 w=$3 case=${4:-update1}
mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
dir=$(mktemp -d)
RAILS=$HOME/c9/$tree WIDTH=$w $vg --tool=callgrind --instr-atstart=no --callgrind-out-file="$dir/cg.%p" \
  "$ruby" "$here/cg_window.rb" "$case" > "$dir/out" 2> "$dir/err" || { tail -3 "$dir/err"; exit 1; }
f=$(grep -l "^desc: Trigger: Client Request: $case" "$dir"/cg.*) && mv "$f" "$out/$tree-w$w.cg"
rm -rf "$dir"
echo "$tree w$w $(grep -m1 '^summary:\|^totals:' "$out/$tree-w$w.cg")"
