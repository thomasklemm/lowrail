#!/usr/bin/env bash
# Callgrind instructions per call for each lbl1_form_ir.rb scenario: (Ir(part) - Ir(cycle(0) part)) / N.
#   lbl1_form_ir.sh RAILS_CHECKOUT MODE [N]   (MODE: interp | yjit; Ruby 4.0.9, the checkout's bundle)
set -euo pipefail
rails=$(cd "$1" && pwd) mode=$2 n=${3:-1000}
here=$(cd "$(dirname "$0")" && pwd)
export PATH=$(~/.local/bin/mise where ruby@4.0.9)/bin:$PATH BUNDLE_GEMFILE=$rails/Gemfile
flag=() smc=()
[ "$mode" = yjit ] && flag=(--yjit) smc=(--smc-check=all)
out=$(mktemp -d)
names=$(valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --dump-after=rb_ary_cycle \
  "${smc[@]}" --callgrind-out-file="$out/cg" ruby "${flag[@]}" -rbundler/setup "$here/lbl1_form_ir.rb" "$rails" "$n" 2>&1 |
  sed -n 's/^scenarios: //p')
parts=$(ls "$out"/cg.* | sort -t. -k2 -n)
ir=()
for p in $parts; do ir+=("$(sed -n 's/^summary: //p; s/^totals: //p' "$p" | head -1 | awk '{print $1}')"); done
IFS=, read -r -a labels <<< "$names"
[ "${#ir[@]}" -eq $(( ${#labels[@]} + 1 )) ] || { echo "expected $(( ${#labels[@]} + 1 )) parts, got ${#ir[@]}" >&2; exit 1; }
rev=$(git -C "$rails" rev-parse --short=10 HEAD)
for i in "${!labels[@]}"; do
  echo "$rev $mode ${labels[$i]} $(( (ir[i + 1] - ir[0]) / n ))"
done
rm -rf "$out"
