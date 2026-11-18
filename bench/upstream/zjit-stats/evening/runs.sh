#!/usr/bin/env bash
# Stats runs for docs/upstream/zjit-stats-2026-11-18-evening.md: each build (~/rb/NAME from build.sh) x railsbench,
# lobsters, shipit, via ../run.sh. NAMES picks builds (default new parent new-aa); OUT the JSON directory.
set -uo pipefail
R=$(cd "$(dirname "$0")/.." && pwd)
out=${OUT:-/tmp/zstats-evening}
mkdir -p "$out"
for b in railsbench lobsters shipit; do
  for name in ${NAMES:-new parent new-aa}; do
    [ -s "$out/$b-$name.json" ] && continue
    echo "$(date -u +%T) $b $name"
    RUBY_PREFIX=$HOME/rb/$name "$R/run.sh" "$b" "$b-$name" "$out" || echo "FAILED $b $name"
  done
done
echo "$(date -u +%T) done"
