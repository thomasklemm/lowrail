#!/usr/bin/env bash
# Interleaved base/bump timing on Ruby 4.0.9, one process at a time, pinned to CPU 1.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
out=$HOME/rb/out/bump; mkdir -p "$out"
for round in 1 2; do
  for b in railsbench lobsters shipit; do
    for mode in interp yjit; do
      for tree in ruby-bench rb-bump; do
        flags=""; [ $mode = yjit ] && flags=--yjit
        (cd $HOME/rb/$tree && WARMUP_ITRS=10 MIN_BENCH_ITRS=10 MIN_BENCH_TIME=0 OUT_CSV_PATH=/tmp/ign.csv \
          setarch x86_64 -R taskset -c 1 ruby $flags benchmarks/$b/benchmark.rb 2>&1 \
          | grep "Average of last" | sed "s/^/$round $b $mode $tree /") >> "$out/results.txt"
      done
    done
  done
done
echo BENCH_DONE >> "$out/results.txt"
