#!/usr/bin/env bash
# Ir per iteration (8 appends) of ir_append.rb: (Ir(N) - Ir(0)) / N.
#   ir_append.sh RUBY MODE TREE [N] [PATCH]   (MODE: interp | yjit)
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ruby=$1 mode=$2 tree=$3 n=${4:-2000} patch=${5:-}
flag=() smc=()
[ "$mode" = yjit ] && flag=(--yjit) smc=(--smc-check=all)
run() { valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null "$ruby" "${flag[@]}" "$here/ir_append.rb" "$tree" "$1" $patch 2>&1 | grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'; }
a=$(run 0); b=$(run "$n")
echo "$(( (b - a) / n ))"
