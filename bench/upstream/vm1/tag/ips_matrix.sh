#!/usr/bin/env bash
# Interleaved benchmark-ips runs of SCRIPT (default ips.rb) in several Rails trees, pinned to one core:
#   ips_matrix.sh OUT MODE ROUNDS label=DIR ...   (MODE: yjit | interp | zjit; RUBY_BIN, CORE, SCRIPT)
set -euo pipefail
out=$1 mode=$2 rounds=$3; shift 3
here=$(cd "$(dirname "$0")" && pwd)
script=${SCRIPT:-$here/ips.rb}
flag=(); [ "$mode" = yjit ] && flag=(--yjit); [ "$mode" = zjit ] && flag=(--zjit)
: > "$out"
for r in $(seq "$rounds"); do
  for tree in "$@"; do
    label=${tree%%=*} dir=${tree#*=}
    echo "== $label round $r" >> "$out"
    (cd "$dir" && RUBYOPT=-W0 taskset -c "${CORE:-3}" "${RUBY_BIN:-ruby}" "${flag[@]}" "$script" "$dir" >> "$out" 2>&1)
  done
done
