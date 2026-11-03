#!/usr/bin/env bash
# Runs one ruby-bench benchmark for docs/upstream/zjit-yjit-gap.md.
#   zjit_yjit_gap_run.sh stats|callgrind BENCH NAME OUT_DIR RUBY_FLAGS...
# Needs a ruby-bench checkout (RUBY_BENCH_DIR, default ~/w/ruby-bench; copied per run) with harness/gap.rb (zjit_yjit_gap_harness.rb), RUBY_PREFIX (default ~/w/rm) and,
# for callgrind, the bench/callgrind.c extension built in CGEXT (default ~/w/cgext).
set -euo pipefail
kind=$1 bench=$2 name=$3 out=$4; shift 4
prefix=${RUBY_PREFIX:-$HOME/w/rm}
mkdir -p "$out"
# Each run gets its own copy: lobsters writes a file cache and the apps write their databases.
src=${RUBY_BENCH_DIR:-$HOME/w/ruby-bench}
copy="$HOME/w/rbc/$bench-$kind-$name-$(basename "$out")"
[ -d "$copy" ] || cp -a "$src" "$copy"
cd "$copy"
unset RUBYOPT
export PATH="$prefix/bin:$PATH" HARNESS=gap GAP_MODE=$kind GAP_JSON="$out/$name.json"
if [ "$kind" = callgrind ]; then
  valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file \
    --dump-instr=yes --compress-strings=no --compress-pos=no \
    --callgrind-out-file="$out/$name.cg.%p" \
    ruby -I "${CGEXT:-$HOME/w/cgext}" "$@" "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1
  pid=$(ls "$out/$name".cg.*.1 | sed 's/.*\.cg\.\([0-9]*\)\.1$/\1/')
  if [ -f "/tmp/perf-$pid.map" ]; then mv "/tmp/perf-$pid.map" "$out/$name.perf.map"; else : > "$out/$name.perf.map"; fi
else
  ruby "$@" "benchmarks/$bench/benchmark.rb" > "$out/$name.log" 2>&1
fi
