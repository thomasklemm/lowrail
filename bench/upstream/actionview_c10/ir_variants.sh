#!/usr/bin/env bash
# Callgrind Ir per call of tag_micro.rb cases for several Rails variants:
#   ir_variants.sh RUBY "FLAGS" N "CASES" VARIANT...   (VARIANT: a dir under ~/w/avb with a Gemfile)
# Ir per call = (Ir(N) - Ir(0)) / N, GC disabled, collected inside Array#cycle.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ruby=$1 flags=$2 n=$3 cases=$4
shift 4
smc=""
[[ "$flags" == *jit* ]] && smc="--smc-check=all"
ir() {
  local out
  out=$(mktemp)
  BUNDLE_GEMFILE=$HOME/w/avb/$1/Gemfile valgrind --tool=callgrind --callgrind-out-file="$out" --collect-atstart=no \
    --toggle-collect=rb_ary_cycle $smc "$ruby" $flags "$here/${SCRIPT:-tag_micro.rb}" "$2" "$3" ir >/dev/null 2>"$out.err" \
    || { cat "$out.err" >&2; exit 1; }
  callgrind_annotate "$out" 2>/dev/null | awk '/PROGRAM TOTALS/ { gsub(",", "", $1); print $1; exit }'
  rm -f "$out" "$out.err"
}
for c in $cases; do
  line="$c"
  for v in "$@"; do
    zero=$(ir "$v" "$c" 0)
    full=$(ir "$v" "$c" "$n")
    line+=$'\t'"$v=$(( (full - zero) / n ))"
  done
  echo "$line"
done
