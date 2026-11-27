#!/usr/bin/env bash
# One timed ruby-bench process for docs/upstream/zjit-gap-census-3.md.
#   wall_run.sh BENCH RUBY_PREFIX OUT_JSON CPU RUBY_FLAGS...
# Runs in the lane's own ruby-bench copy (~/w/rbc/wall-CPU), on Rails main (Gemfile.main), pinned to CPU, with the
# benchmark's file cache cleared first. Env: WARMUP_ITRS, MEASURE_ITRS, HARNESS (default gapwall).
set -euo pipefail
bench=$1 prefix=$2 json=$3 cpu=$4; shift 4
copy=$HOME/w/rbc/wall-$cpu
mkdir -p "$HOME/w/rbc" "$(dirname "$json")"
[ -d "$copy" ] || cp -a "${RUBY_BENCH_DIR:-$HOME/w/ruby-bench}" "$copy"
cp "$(dirname "$0")/wall_harness.rb" "$copy/harness/gapwall.rb"
cp "$(dirname "$0")/../zjit_yjit_gap_harness.rb" "$copy/harness/gap.rb"
cd "$copy"
rm -rf "benchmarks/$bench/tmp/cache" "benchmarks/$bench/log/production.log"
unset RUBYOPT
export PATH="$prefix/bin:$PATH" HARNESS=${HARNESS:-gapwall} WALL_JSON=$json GAP_JSON=$json \
  BUNDLE_GEMFILE="$copy/benchmarks/$bench/Gemfile.main" RUBY_GC_HEAP_INIT_BYTES=${RUBY_GC_HEAP_INIT_BYTES:-33554432}
exec taskset -c "$cpu" ruby "$@" "benchmarks/$bench/benchmark.rb" > "${json%.json}.log" 2>&1
