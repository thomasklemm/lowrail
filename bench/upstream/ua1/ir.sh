#!/usr/bin/env bash
# Callgrind Ir and objects per call: (Ir(N rounds) - Ir(0)) / (N x 21 user agents).
#   ir.sh RUBY_BIN GEMFILE_DIR interp|yjit check|parse [N]
# Prints: GEMFILE_DIR|MODE|WHAT|Ir per call|objects per call|blocks compiled in the window
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
bin=$1 dir=$2 mode=$3 what=$4 n=${5:-20}
flag=() smc=()
if [ "$mode" = yjit ]; then flag=(--yjit) smc=(--smc-check=all); fi
run() {
  BUNDLE_GEMFILE=$dir/Gemfile PATH="$bin:$PATH" valgrind --tool=callgrind --collect-atstart=no \
    --toggle-collect=rb_ary_cycle "${smc[@]}" --callgrind-out-file=/dev/null \
    "$bin/ruby" "${flag[@]}" -rbundler/setup "$here/ir.rb" "$what" "$1" 2>&1
}
calls=$(( n * 21 ))
zero=$(run 0); full=$(run "$n")
a=$(grep -o 'Collected : [0-9]*' <<<"$zero" | tail -1 | grep -o '[0-9]*')
b=$(grep -o 'Collected : [0-9]*' <<<"$full" | tail -1 | grep -o '[0-9]*')
stats=$(grep -o 'UA1 compiled_blocks=[0-9-]* objects=[0-9]*' <<<"$full")
blocks=${stats#*compiled_blocks=}; blocks=${blocks%% *}; objects=${stats##*objects=}
echo "$(basename "$dir")|$mode|$what|$(( (b - a) / calls ))|$(awk "BEGIN{printf \"%.1f\", $objects/$calls}")|$blocks"
