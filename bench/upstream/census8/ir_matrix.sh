#!/bin/bash
# ir_matrix.sh OUT BASE CAND "CASES" "MODES": Ir per call for BASE (twice: main and aa) and CAND.
# BASE and CAND are Rails checkouts; MODES from interp yjit zjit. One line per run in OUT.
out=$1 base=$2 cand=$3 cases=$4 modes=$5
here=$(cd "$(dirname "$0")" && pwd)
for c in $cases; do for m in $modes; do for v in main:$base aa:$base cand:$cand; do
  echo "${v%%:*} ${v#*:} $c $m"
done; done; done | xargs -P "${JOBS:-6}" -L 1 bash -c 'echo "$0 $("'"$here"'/ir.sh" "$1" "$2" "$3")"' >> "$out"
sort -o "$out" "$out"
