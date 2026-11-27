#!/usr/bin/env bash
# Interleaved Callgrind runs under a JIT: main, to1, fh2, lbl1, main2, main again. MODE yjit (Ruby 4.0.9) or zjit
# (RUBY = a Ruby master build, BUNDLE_GEMFILE = a bundle with the Rails path gems and sqlite3). Output: results/MODE.txt
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); mkdir -p "$here/results"; mode=$1
export BUNDLE_WITHOUT="mysql:postgresql:job:cable:storage:bench:doc"
for t in main to1 fh2 lbl1 main2 main; do
  "$here/revive_jit.sh" "$HOME/src/w-$t" "$mode" "${N:-1000}" | sed "s/^/$t /" >> "$here/results/$mode.txt"
done
echo RUN-DONE
