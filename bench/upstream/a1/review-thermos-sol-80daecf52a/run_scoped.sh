#!/usr/bin/env bash
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
for pair in "$@"; do
  name=${pair%%=*}
  export RAILS=${pair#*=}
  for adapter in sqlite3 postgresql; do
    export ADAPTER=$adapter DATABASE=a1_review_scoped
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
            WIDTH=$width ruby "$here/$probe.rb"
          done
        done
      } > "$here/raw/$group-$name-$adapter.txt" 2>&1
    done
  done
done
