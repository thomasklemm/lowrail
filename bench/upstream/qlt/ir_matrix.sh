#!/usr/bin/env bash
# The Callgrind cells of the query log tag record, two at a time (Lobsters under YJIT
# compiles thousands of blocks per window, so it runs in the interpreter):
#   ir_matrix.sh OUT_DIR   (appends OUT_DIR/ir.txt)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1; mkdir -p "$out"
cells() {
  for c in "none on 0" "none on 0 aa" "default off 0" "default off 1" "default on 0" "default on 1" "request_id off 1" "request_id on 1"; do
    echo "censusqlt blog GET_article yjit 100 200 $c"; done
  for c in "none on 0" "none on 0 aa" "default off 0" "default on 0" "request_id off 1" "request_id on 1"; do
    echo "censusqltpg blog GET_article yjit 100 200 $c"; done
  for c in "none on 0" "none on 0 aa" "default off 1" "default on 1" "request_id off 1" "request_id on 1"; do
    echo "censusqlt lobsters GET_story interp 30 50 $c"; done
}
cell() {
  local corpus=$1 app=$2 workload=${3//_/ } mode=$4 n=$5 warm=$6 tags=$7 ps=$8 cache=$9 aa=${10:-}
  line=$(QLT_TAGS=$tags QLT_PS=$ps QLT_CACHE=$cache PMAP_WARMUP=$warm "$here/ir.sh" "$corpus" "$app" "$workload" "$mode" "$n")
  echo "$corpus|$line${aa:+|aa}" >> "$out/ir.txt"
}
export -f cell; export here out
cells | xargs -P2 -L1 bash -c 'cell "$@"' _
