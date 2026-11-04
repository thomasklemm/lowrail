#!/usr/bin/env bash
# Callgrind instructions per call: (Ir(N) - Ir(0)) / N, collected only inside
# Array#cycle (rb_ary_cycle), GC disabled. JIT runs add --smc-check=all.
#   ir.sh RUBY "FLAGS" N SCRIPT [ARGS...]   (SCRIPT ir CASE N must run CASE N times)
set -euo pipefail
ruby=$1 flags=$2 n=$3 script=$4
shift 4
smc=""
[[ "$flags" == *jit* ]] && smc="--smc-check=all"
ir() {
  local out
  out=$(mktemp)
  valgrind --tool=callgrind --callgrind-out-file="$out" --collect-atstart=no --toggle-collect=rb_ary_cycle $smc \
    "$ruby" $flags "$script" "$@" >/dev/null 2>"$out.err" || { cat "$out.err" >&2; exit 1; }
  callgrind_annotate "$out" 2>/dev/null | awk '/PROGRAM TOTALS/ { gsub(",", "", $1); print $1; exit }'
  rm -f "$out" "$out.err"
}
case_args=("$@")
zero=$(ir "${case_args[@]/__N__/0}")
full=$(ir "${case_args[@]/__N__/$n}")
echo "$(( (full - zero) / n ))"
