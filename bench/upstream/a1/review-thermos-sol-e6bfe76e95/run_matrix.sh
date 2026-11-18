#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
here="$root/bench/upstream/a1/review-thermos-sol-e6bfe76e95"
previous="$root/bench/upstream/a1/review-thermos-sol-80daecf52a"
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
mkdir -p "$here/raw"
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
          KEEP=$keep WIDTH=$width ruby "$root/bench/upstream/a1/followup-81/composite_serialization.rb"
        done
        for probe in join_serialization range_join range_plain scoped_join linear_join range_paths; do
          echo "=== $probe WIDTH=$width (both KEEP settings) ==="
          WIDTH=$width ruby "$root/bench/upstream/a1/followup-81/$probe.rb"
        done
      done
    } > "$here/raw/matrix-$name-$adapter.txt" 2>&1
    for group in scoped scoped-order scoped-effects scoped-hash; do
      case $group in
        scoped) probes="scoped_late_serialization scoped_range" ;;
        scoped-order) probes="scoped_default_order scoped_join_removed" ;;
        scoped-effects) probes="scoped_extension scoped_removed_bind" ;;
        scoped-hash) probes="scoped_hash_phase" ;;
      esac
      {
        for probe in $probes; do
          for width in 16 17; do
            echo "=== $probe WIDTH=$width ==="
            WIDTH=$width ruby "$previous/$probe.rb"
          done
        done
      } > "$here/raw/$group-$name-$adapter.txt" 2>&1
    done
  done
done
