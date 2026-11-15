#!/usr/bin/env bash
# Runs one ruby-bench benchmark for docs/upstream/zjit-not-equal.md.
#   run.sh count|cg BENCH NAME OUT_DIR RUBY_FLAGS...
# RUBY_BENCH_DIR is a ruby-bench checkout with harness/zne1count.rb (count_harness.rb), copied per run because
# the apps write caches and databases. RUBY_PREFIX is the measurement build (neq_count.patch). cg needs the
# pinned Valgrind (script/bench-valgrind) in VALGRIND_PREFIX and the bench/callgrind.c extension in CGEXT.
set -euo pipefail
kind=$1 bench=$2 name=$3 out=$4; shift 4
prefix=${RUBY_PREFIX:-$HOME/w/rs}
mkdir -p "$out"
src=${RUBY_BENCH_DIR:-$HOME/w/ruby-bench}
copy="$HOME/w/rbc/$(basename "$src")-$bench-$name-$(basename "$out")"
rm -rf "$copy"
mkdir -p "$HOME/w/rbc"
cp -a "$src" "$copy"
cd "$copy"
unset RUBYOPT
export PATH="$prefix/bin:$PATH" HARNESS=zne1count ZNE1_MODE=$kind ZNE1_JSON="$out/$name.json" RUBY_GC_HEAP_INIT_BYTES=33554432
if [ "$kind" = cg ]; then
  "${VALGRIND_PREFIX:-$HOME/w/vg319brk}/bin/valgrind" --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
    --callgrind-out-file="$out/$name.cg" \
    ruby -I "${CGEXT:-$HOME/w/cgext}" "$@" "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1
else
  ruby "$@" "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1
fi
rm -rf "$copy"
