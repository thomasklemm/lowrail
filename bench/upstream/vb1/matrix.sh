#!/bin/bash
# matrix.sh OUT [JOBS]: every run.sh cell for VB1, two at a time by default. Trees main, main2 (A/A), fix (the
# branch) and fixb (the branch plus a block literal in deep_dup); widths 6, 30, 100 and the request mix; Ruby 4.0.9
# interpreter and YJIT, Ruby master ZJIT. The trees of one cell run next to each other.
set -uo pipefail
out=$1; jobs=${2:-2}
here=$(cd "$(dirname "$0")" && pwd)
for mode in interp yjit zjit; do
  for width in 6 30 100 req; do
    for tree in main fix main2 fixb; do
      echo "$tree $width $mode"
    done
  done
done | N=${N:-200} WARM=${WARM:-100} xargs -P"$jobs" -L1 bash -c '"$0/run.sh" "$1" $2 $3 $4 && echo "done $2 $3 $4"' "$here" "$out"
