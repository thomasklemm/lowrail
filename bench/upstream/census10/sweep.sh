#!/bin/bash
# sweep.sh SCRIPT OUT TREE...: SCRIPT per tree (~/c10/TREE) and mode (interp, yjit) under
# census 8's patched Callgrind, fixed heap; OUT/NAME-TREE-MODE.txt (NAME = SCRIPT's basename).
# Extra environment (KEEP, N, WARM, CASES) passes through; TAG suffixes the file name.
set -u
script=$1 out=$2; shift 2; mkdir -p "$out"
name=$(basename "$script" .rb)
ruby=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby}
vg=${VALGRIND_PREFIX:-$HOME/c8-valgrind}/bin/valgrind
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
for mode in ${MODES:-interp yjit}; do
  flag=; smc=; [ $mode = yjit ] && flag=--yjit && smc=--smc-check=all-non-file
  for tree in "$@"; do
    f=$out/$name-$tree${TAG:-}-$mode.txt; [ -s "$f" ] && continue
    RAILS=$HOME/c10/$tree $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc \
      "$ruby" $flag "$script" ${CASES:-} > "$f.tmp" 2>"$f.err" && mv "$f.tmp" "$f" && rm -f "$f.err"
    echo "$tree $mode $(date -u +%T)"
  done
done
