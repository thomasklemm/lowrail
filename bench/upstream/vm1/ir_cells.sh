#!/usr/bin/env bash
# request_ir.sh cells for several Rails trees, JOBS at a time:
#   ir_cells.sh OUT "label=SPEC" ... -- "CORPUS|APP|WORKLOAD" ...   (MODES, N, JOBS from the environment;
#   SPEC "" is the copy's base Rails, run as base and again as base2 for A/A)
# Lines "label|app|workload|mode|Ir/request|objects/request|blocks compiled" go to OUT.
set -uo pipefail
p_map=$(cd "$(dirname "$0")/../p_map" && pwd)
out=$1; shift
labels=()
while [ "$1" != "--" ]; do labels+=("$1"); shift; done; shift
modes=${MODES:-interp yjit} n=${N:-50} jobs=${JOBS:-3}
cells=()
for cell in "$@"; do
  for mode in $modes; do
    for label in "${labels[@]}"; do cells+=("$label|$cell|$mode"); done
  done
done
printf '%s\n' "${cells[@]}" | xargs -P "$jobs" -I{} bash -c '
  IFS="|" read -r labelspec corpus app workload mode <<<"{}"
  label=${labelspec%%=*} spec=${labelspec#*=}
  line=$(PMAP_CORPUS=$corpus PMAP_RAILS=$spec "'"$p_map"'/request_ir.sh" "$app" "$workload" "$mode" '"$n"' 2>/dev/null | tail -1)
  echo "$label|$line" >> "'"$out"'"
'
