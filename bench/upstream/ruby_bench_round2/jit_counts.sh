#!/usr/bin/env bash
# Per-iteration JIT compile counts on stock ruby-bench, default harness, no warmup split.
# usage: jit_counts.sh <yjit|zjit> <bench> <tag> <iters>
set -euo pipefail
mode=$1 bench=$2 tag=$3 iters=${4:-60}
src=$HOME/rb/ruby-bench
work=$HOME/rb/copies/$mode-$bench-$tag
rm -rf "$work"; mkdir -p "$(dirname "$work")"; cp -a "$src" "$work"
out=$HOME/rb/out/counts; mkdir -p "$out"
if [ "$mode" = yjit ]; then
  export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
  flags=--yjit
  export YJIT_BENCH_STATS=compiled_block_count,compiled_iseq_count,invalidation_count,compile_time_ns
else
  export PATH=$HOME/rubies/master/bin:$PATH
  flags=--zjit
  export ZJIT_BENCH_STATS=compiled_iseq_count,compiled_side_exit_count,compile_time_ns,code_region_bytes
fi
cd "$work"
WARMUP_ITRS=0 MIN_BENCH_ITRS=$iters MIN_BENCH_TIME=0 OUT_CSV_PATH=/tmp/ignore-$mode-$bench-$tag.csv \
  ruby $flags benchmarks/$bench/benchmark.rb > "$out/$mode-$bench-$tag.txt" 2>&1
rm -rf "$work"
echo "done $mode $bench $tag"
