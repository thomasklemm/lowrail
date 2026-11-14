#!/bin/bash
# yjit.sh OUT TREE WIDTH CASE...: attr_micro.rb under --yjit (census 8's patched Callgrind, fixed heap), as
# attr_sweep.sh's yjit mode but for chosen cases. The last column is the measured window's compiled blocks (0 = flat).
set -u
out=$1 tree=$2 w=$3; shift 3
mkdir -p "$out"
here=$(cd "$(dirname "$0")/.." && pwd)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
f=$out/$tree-yjit-w$w.txt
RAILS=$HOME/c9/$tree WIDTH=$w $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null --smc-check=all-non-file \
  "$ruby" --yjit "$here/attr_micro.rb" "$@" > "$f.tmp" 2> "$f.log" && mv "$f.tmp" "$f" && rm -f "$f.log"
echo "$tree w$w"; cat "$f" 2>/dev/null || tail -3 "$f.log"
