#!/usr/bin/env bash
# Ir per iteration of ir_micro.rb: (Ir(N) - Ir(0)) / N.
#   ir_micro.sh RUBY MODE TREE [N]   (MODE: interp | yjit | zjit)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ruby=$1 mode=$2 tree=$3 n=${4:-2000}
flag=() smc=()
[ "$mode" = yjit ] && flag=(--yjit) smc=(--smc-check=all)
[ "$mode" = zjit ] && flag=(--zjit) smc=(--smc-check=all)
run() { valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null "$ruby" "${flag[@]}" "$here/ir_micro.rb" "$tree" "$1" 2>&1 | grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'; }
a=$(run 0); b=$(run "$n")
echo "$(( (b - a) / n ))"
