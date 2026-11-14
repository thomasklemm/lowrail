#!/bin/bash
# req_sweep.sh OUT TREE...: req_micro.rb per tree and mode (interp, yjit), fixed heap; OUT/req-TREE-MODE.txt.
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
    f=$out/req-$tree-$mode.txt; [ -s "$f" ] && continue
    RAILS=$HOME/c9/$tree N=${N:-100} WARM=${WARM:-100} $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc \
      "$ruby" $flag "$here/req_micro.rb" ${CASES:-} > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
    echo "$tree $mode $(date -u +%T)"
  done
done
