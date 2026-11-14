#!/usr/bin/env bash
# Callgrind Ir per request: (Ir(N) - Ir(0)) / N for one census workload.
#   [PMAP_RAILS=SPEC] request_ir.sh APP WORKLOAD MODE [N]   MODE: interp | yjit
# Prints: APP|WORKLOAD|MODE|Ir per request|objects per request|blocks compiled in the N window
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$1 workload=$2 mode=$3 n=${4:-200}
flag=() smc=()
if [ "$mode" = yjit ]; then flag=(--yjit) smc=(--smc-check=all); fi
run() {
  CENSUS_MODE=$([ "$mode" = yjit ] && echo yjit || echo interpreter) "$here/hx" censuspmap "$app" \
    valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null \
    ruby -rbundler/setup "${flag[@]}" "$here/request_ir.rb" "$app" "$workload" "$1" 2>&1
}
zero=$(run 0); full=$(run "$n")
a=$(grep -o 'Collected : [0-9]*' <<<"$zero" | tail -1 | grep -o '[0-9]*')
b=$(grep -o 'Collected : [0-9]*' <<<"$full" | tail -1 | grep -o '[0-9]*')
stats=$(grep -o 'PMAP compiled_blocks=[0-9-]* objects=[0-9]*' <<<"$full")
blocks=${stats#*compiled_blocks=}; blocks=${blocks%% *}; objects=${stats##*objects=}
echo "$app|$workload|$mode|$(( (b - a) / n ))|$(( objects / n ))|$blocks"
