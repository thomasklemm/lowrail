#!/usr/bin/env bash
# Callgrind instructions per call for each revive_jit.rb scenario: (Ir(part) - Ir(cycle(0) part)) / N.
#   revive_jit.sh RAILS_CHECKOUT MODE [N]   (MODE: interp | yjit | zjit; Ruby 4.0.9 or $RUBY, $BUNDLE_GEMFILE or the checkout's bundle)
set -euo pipefail
rails=$(cd "$1" && pwd) mode=$2 n=${3:-1000}
here=$(cd "$(dirname "$0")" && pwd)
export PATH=$($HOME/.local/bin/mise where ruby@4.0.9)/bin:$PATH BUNDLE_GEMFILE=${BUNDLE_GEMFILE:-$rails/Gemfile}
flag=() smc=()
[ "$mode" = yjit ] && flag=(--yjit) smc=(--smc-check=all)
[ "$mode" = zjit ] && flag=(--zjit --zjit-stats) smc=(--smc-check=all)
out=$(mktemp -d)
names=$(valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --dump-after=rb_ary_cycle \
  "${smc[@]}" --callgrind-out-file="$out/cg" "${RUBY:-ruby}" "${flag[@]}" -rbundler/setup "$here/revive_jit.rb" "$rails" "$n" 2>&1 |
  tee "$out/stderr" | sed -n 's/^scenarios: //p')
parts=$(ls "$out"/cg.* | awk -F. '{print $NF, $0}' | sort -n | cut -d" " -f2)
ir=()
for p in $parts; do ir+=("$(sed -n 's/^summary: //p; s/^totals: //p' "$p" | head -1 | awk '{print $1}')"); done
IFS=, read -r -a labels <<< "$names"
skip=$(sed -n "s/^skip_parts: //p" "$out/stderr")
ir=("${ir[0]}" "${ir[@]:$((1 + ${skip:-0}))}")
[ "${#ir[@]}" -eq $(( ${#labels[@]} + 1 )) ] || { echo "expected $(( ${#labels[@]} + 1 )) parts, got ${#ir[@]}" >&2; exit 1; }
rev=$(git -C "$rails" rev-parse --short=10 HEAD)
for i in "${!labels[@]}"; do
  echo "$rev $mode ${labels[$i]} $(( (ir[i + 1] - ir[0]) / n ))"
done
sed -n "s/^jit_window: /$rev $mode jit_window /p" "$out/stderr"
rm -rf "$out"
