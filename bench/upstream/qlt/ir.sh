#!/usr/bin/env bash
# Callgrind Ir per request under one query log tag setting (p_map/request_ir.rb):
#   QLT_TAGS=.. QLT_PS=.. QLT_CACHE=.. ir.sh CORPUS APP WORKLOAD MODE N
# Prints: APP|WORKLOAD|MODE|tags/ps/cache|Ir per request|objects per request|blocks compiled in the N window
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
corpus=$1 app=$2 workload=$3 mode=$4 n=$5
flag=() smc=()
if [ "$mode" = yjit ]; then flag=(--yjit) smc=(--smc-check=all); fi
run() {
  QLT_CONFIG=$here/config.rb CENSUS_MODE=$([ "$mode" = yjit ] && echo yjit || echo interpreter) "$here/../p_map/hx" "$corpus" "$app" \
    valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null \
    ruby -rbundler/setup "${flag[@]}" "$here/../p_map/request_ir.rb" "$app" "$workload" "$1" 2>&1
}
zero=$(run 0); full=$(run "$n")
a=$(grep -o 'Collected : [0-9]*' <<<"$zero" | tail -1 | grep -o '[0-9]*')
b=$(grep -o 'Collected : [0-9]*' <<<"$full" | tail -1 | grep -o '[0-9]*')
stats=$(grep -o 'PMAP compiled_blocks=[0-9-]* objects=[0-9]*' <<<"$full")
blocks=${stats#*compiled_blocks=}; blocks=${blocks%% *}; objects=${stats##*objects=}
echo "$app|$workload|$mode|${QLT_TAGS}/${QLT_PS}/${QLT_CACHE:-0}|$(( (b - a) / n ))|$(( objects / n ))|$blocks"
