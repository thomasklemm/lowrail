#!/usr/bin/env bash
set -euo pipefail
ROOT=/home/user/workspace/repo
WORK=$ROOT/.amp/in/orb-backup/l3-review-41af
OUT=$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/head-41af869c78
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.10/bin:$PATH
export BUNDLE_PATH=$WORK/gems TMPDIR=$WORK/tmp
mkdir -p "$TMPDIR"
for adapter in sqlite3 postgresql; do
  for tree in main head; do
    export RAILS=$WORK/$tree BUNDLE_GEMFILE=$WORK/b-$tree/Gemfile ADAPTER=$adapter
    for mode in interp yjit; do
      flags=()
      [ "$mode" != yjit ] || flags=(--yjit)
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/review_probe.rb" > "$OUT/probe-$tree-$adapter-$mode.txt"
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25/exactness_extension.rb" > "$OUT/extended-$tree-$adapter-$mode.txt"
      ruby "${flags[@]}" "$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-27/callable_default_repro.rb" > "$OUT/default-$tree-$adapter-$mode.txt"
    done
  done
done
for adapter in sqlite3 postgresql; do
  for mode in interp yjit; do
    for probe in probe extended default; do
      cmp "$OUT/$probe-main-$adapter-$mode.txt" "$OUT/$probe-head-$adapter-$mode.txt"
      wc -l "$OUT/$probe-main-$adapter-$mode.txt"
    done
  done
done
