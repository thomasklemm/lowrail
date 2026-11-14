#!/bin/bash
# sweep.sh OUT MODE TREE...: k6_micro.rb once per tree under census 8's patched
# Callgrind, fixed heap; writes OUT/TREE-MODE.txt. MODE is interp, yjit or zjit
# (zjit with RUBY set to a Ruby master binary).
# Trees are Rails checkouts under ~/k6/trees; one tree under two names is the A/A.
# Gems come from BUNDLE_GEMFILE (a Gemfile without the Rails path gems).
set -eu
out=$1; mode=$2; shift 2; mkdir -p "$out"
here=$(cd "$(dirname "$0")" && pwd)
ruby=${RUBY:-${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
flag=; smc=; [ "$mode" = yjit ] && flag=--yjit && smc=--smc-check=all-non-file
[ "$mode" = zjit ] && flag=--zjit && smc=--smc-check=all-non-file
for tree in "$@"; do
  f=$out/$tree-$mode.txt; [ -s "$f" ] && continue
  RAILS=$HOME/k6/trees/$tree N=${N:-100} WARM=${WARM:-100} "$vg" --tool=callgrind --instr-atstart=no \
    --callgrind-out-file=/dev/null $smc "$ruby" -rbundler/setup $flag "$here/k6_micro.rb" ${CASES:-} > "$f.tmp" 2> "$f.err"
  mv "$f.tmp" "$f"
  echo "$tree $mode $(date -u +%T)"
done
