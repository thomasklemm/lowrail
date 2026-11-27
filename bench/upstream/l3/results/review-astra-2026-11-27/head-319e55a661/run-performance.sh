set -euo pipefail
source .amp/in/orb-backup/l3-review/env.sh
OUT="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27/head-319e55a661"
OLD="$ROOT/bench/upstream/l3/results/review-astra-2026-11-27"
for label in base head base2; do
  tree="$label"; [[ "$tree" == base2 ]] && tree=base
  use_tree "$tree"
  echo "=== $label ==="
  taskset -c 1 ruby --yjit -rbundler/setup "$ROOT/bench/upstream/l3/l3_ips.rb"
done > "$OUT/body-ips.txt"
for width in 6 30 100; do
  for label in base head base2; do
    tree="$label"; [[ "$tree" == base2 ]] && tree=base
    use_tree "$tree"
    echo "=== $width $label ==="
    WIDTH="$width" taskset -c 1 ruby --yjit "$OLD/performance.rb"
  done
done > "$OUT/sizes.txt"
for round in 1 2 3; do
  for label in base head base2; do
    tree="$label"; [[ "$tree" == base2 ]] && tree=base
    use_tree "$tree"
    echo "=== $round $label ==="
    LARGE=1 taskset -c 1 ruby --yjit "$OLD/performance.rb"
  done
done > "$OUT/large.txt"
