#!/bin/bash
# sweep.sh OUT TREE...: load_micro.rb under patched Callgrind for every tree x ADAPTERS x WIDTHS x MODES,
# two processes at a time (one PG database per process). Bundles in ~/l7/g-TREE (BUNDLE_PATH ~/l7/gems).
set -u
out=$1; shift; mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
export RUBY=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
export VG=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export BUNDLE_PATH=${BUNDLE_PATH:-$HOME/l7/gems} HERE=$here OUT=$out
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
one() {
  local tree=$1 adapter=$2 width=$3 mode=$4 flag= smc= db=l7_$1_$3_$4
  [ -s "$OUT/$tree-$adapter-$width-$mode.txt" ] && return
  [ "$mode" = yjit ] && flag=--yjit && smc=--smc-check=all-non-file
  [ "$adapter" = postgresql ] && { dropdb --if-exists $db; createdb $db; }
  BUNDLE_GEMFILE=$HOME/l7/g-$tree/Gemfile ADAPTER=$adapter DB=$db WIDTH=$width \
    $VG --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc "$RUBY" $flag "$HERE/load_micro.rb" \
    2>"$OUT/err-$tree-$adapter-$width-$mode.txt" | sed "s/^/$tree $adapter $mode /" > "$OUT/$tree-$adapter-$width-$mode.txt"
}
export -f one
for mode in ${MODES:-interp yjit}; do for adapter in ${ADAPTERS:-sqlite3 postgresql}; do for w in ${WIDTHS:-6 15 30}; do
  for tree in "$@"; do echo "$tree $adapter $w $mode"; done
done; done; done | xargs -P 2 -L 1 bash -c 'one "$@"' _
cat "$out"/*-interp.txt "$out"/*-yjit.txt 2>/dev/null > "$out/all.txt"
