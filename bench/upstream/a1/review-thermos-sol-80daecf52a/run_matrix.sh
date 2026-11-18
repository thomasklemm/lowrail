#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
out="$root/bench/upstream/a1/review-thermos-sol-80daecf52a/raw"
probes="$root/bench/upstream/a1/followup-81"
mkdir -p "$out"
for pair in "$@"; do
  name=${pair%%=*}
  export RAILS=${pair#*=}
  for adapter in sqlite3 postgresql; do
    export ADAPTER=$adapter DATABASE=a1_review_probe
    {
      git -C "$RAILS" rev-parse HEAD
      ruby -v
      for width in 16 17; do
        for keep in 0 1; do
          echo "=== composite WIDTH=$width KEEP=$keep ==="
          KEEP=$keep WIDTH=$width ruby "$probes/composite_serialization.rb"
        done
        for probe in join_serialization range_join range_plain scoped_join; do
          echo "=== $probe WIDTH=$width (both KEEP settings) ==="
          WIDTH=$width ruby "$probes/$probe.rb"
        done
      done
      for probe in linear_join range_paths; do
        echo "=== $probe (both KEEP settings) ==="
        ruby "$probes/$probe.rb"
      done
    } > "$out/matrix-$name-$adapter.txt" 2>&1
  done
done
