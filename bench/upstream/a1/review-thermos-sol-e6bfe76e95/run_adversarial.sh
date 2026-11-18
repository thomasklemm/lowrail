#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
here="$root/bench/upstream/a1/review-thermos-sol-e6bfe76e95"
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
for pair in "$@"; do
  name=${pair%%=*}
  export RAILS=${pair#*=}
  for adapter in sqlite3 postgresql; do
    export ADAPTER=$adapter DATABASE=a1_review_probe
    for mode in finite range phase; do
      for width in 16 17; do
        MODE=$mode WIDTH=$width ruby "$here/adversarial_joins.rb" > "$here/raw/adversarial-$name-$adapter-$mode-$width.txt" 2>&1
      done
    done
  done
done
