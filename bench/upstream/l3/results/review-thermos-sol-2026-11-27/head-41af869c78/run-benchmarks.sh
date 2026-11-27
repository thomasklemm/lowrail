#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/user/workspace/repo
WORK=$ROOT/.amp/in/orb-backup/l3-review-41af
OUT=$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/head-41af869c78
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.10/bin:$PATH BUNDLE_PATH=$WORK/gems
export TMPDIR=$WORK/tmp
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000
export RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
unset RUBYOPT
for bench in sweep worst; do
  for round in 1 2 3; do
    for tree in main head main2; do
      source_tree=$tree
      [ "$tree" != main2 ] || source_tree=main
      export RAILS=$WORK/$source_tree BUNDLE_GEMFILE=$WORK/b-$source_tree/Gemfile
      echo "=== $tree round $round ==="
      taskset -c 1 ruby --yjit -rbundler/setup "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/${bench}_ips.rb"
    done
  done > "$OUT/$bench-ips.log" 2>&1
  ruby "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/summarize_ips.rb" "$OUT/$bench-ips.log" "$OUT/$bench-ips.json" > "$OUT/$bench-ips-best.txt"
done
