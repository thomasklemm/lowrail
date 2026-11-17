#!/usr/bin/env bash
# Callgrind instructions per call of fb1_ir.rb: (Ir(N) - Ir(0)) / N.
#   fb1_ir.sh RUBY_VERSION GEMFILE MODE FIELD PERSISTED [N]   (MODE: interp | yjit; FIELD: text_field | checkbox)
# GEMFILE points activesupport, activemodel and actionview at the Rails tree; GCON=1 keeps GC on.
set -euo pipefail
v=$1 gemfile=$2 mode=$3 field=$4 pers=$5 n=${6:-2000}
here=$(cd "$(dirname "$0")" && pwd)
export PATH=$(mise where ruby@"$v")/bin:$PATH BUNDLE_GEMFILE=$gemfile
flag=() smc=()
[ "$mode" = yjit ] && flag=(--yjit) smc=(--smc-check=all)
run() { valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null ruby "${flag[@]}" -rbundler/setup "$here/fb1_ir.rb" "$field" "$pers" "$1" 2>&1 | grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'; }
a=$(run 0); b=$(run "$n")
echo "$v $gemfile $mode $field persisted=$pers gcon=${GCON:-0} $(( (b - a) / n ))"
