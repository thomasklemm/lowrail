#!/usr/bin/env bash
# Base, A/A twin and candidate request_ir.sh cells, JOBS at a time:
#   ir_matrix.sh OUT CANDIDATE_SPEC "APP|WORKLOAD" ...    (MODES, N, JOBS from the environment)
# Lines "label|app|workload|mode|Ir/request|objects/request|blocks compiled" go to OUT.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
out=$1 candidate=$2; shift 2
modes=${MODES:-interp yjit} n=${N:-50} jobs=${JOBS:-3}
cells=()
for cell in "$@"; do
  for mode in $modes; do
    for label in base base2 candidate; do cells+=("$label|$cell|$mode"); done
  done
done
printf '%s\n' "${cells[@]}" | xargs -P "$jobs" -I{} bash -c '
  IFS="|" read -r label app workload mode <<<"{}"
  spec=""; [ "$label" = candidate ] && spec="'"$candidate"'"
  line=$(PMAP_RAILS=$spec "'"$here"'/request_ir.sh" "$app" "$workload" "$mode" '"$n"' 2>/dev/null | tail -1)
  echo "$label|$line" >> "'"$out"'"
'
