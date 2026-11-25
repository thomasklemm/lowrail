#!/usr/bin/env bash
set -euo pipefail
ROOT=$(git rev-parse --show-toplevel)
S=$ROOT/.amp/in/orb-backup/l3-review
E=$ROOT/bench/upstream/l3/results/review-thermos-sol-confirm-2026-11-25
P=$ROOT/bench/upstream/l3/results/review-thermos-sol-2026-11-25
export PATH=/home/user/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
export BUNDLE_PATH=$S/gems TMPDIR=$S/tmp-confirm
for cohort in body sweep worst; do
  case $cohort in
    body) rounds=6; script=$ROOT/bench/upstream/l3/l3_ips.rb ;;
    sweep) rounds=3; script=$P/sweep_ips.rb ;;
    worst) rounds=3; script=$P/worst_ips.rb ;;
  esac
  for ((round=1; round<=rounds; round++)); do
    case $(( (round-1) % 3 )) in
      0) trees="main confirm main2" ;;
      1) trees="confirm main2 main" ;;
      2) trees="main2 main confirm" ;;
    esac
    for tree in $trees; do
      export RAILS=$S/$tree BUNDLE_GEMFILE=$S/Gemfile.$tree
      echo "=== $tree round $round ==="
      taskset -c 1 ruby --yjit -rbundler/setup "$script"
    done
  done > "$E/$cohort-ips.txt" 2>&1
  ruby "$P/summarize_ips.rb" "$E/$cohort-ips.txt" "$E/$cohort-ips.json" | tee "$E/$cohort-best.txt"
done
