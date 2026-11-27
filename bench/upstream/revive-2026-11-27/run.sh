#!/usr/bin/env bash
# Interleaved Callgrind runs: main, to1, fh2, lbl1, main2, main again; interpreter then YJIT. Output: results/MODE.txt
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); mkdir -p "$here/results"
export BUNDLE_WITHOUT="mysql:postgresql:job:cable:storage:bench:doc"
for mode in ${MODES:-interp yjit}; do
  for t in main to1 fh2 lbl1 main2 main; do
    "$here/revive_ir.sh" "$HOME/src/w-$t" "$mode" "${N:-1000}" | sed "s/^/$t /" >> "$here/results/$mode.txt"
  done
done
echo RUN-DONE
