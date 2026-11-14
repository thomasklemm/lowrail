#!/usr/bin/env bash
# Callgrind instructions and objects per request for each workload, one process:
#   ir.sh APP_DIR OUT_TSV LABEL MODE N [WORKLOAD...]   (MODE interp|yjit; DEF8_OFF/DEF8_ON pass through)
# Each workload's N requests run inside one Array#cycle with GC off (fixed heap);
# collection is toggled on rb_ary_cycle and dumped after it, one dump per workload.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
app=$1 out=$2 label=$3 mode=$4 n=$5; shift 5
tmp=$(mktemp -d)
flag=() smc=()
if [ "$mode" = yjit ]; then flag=(--yjit) smc=(--smc-check=all); else export DEF8_INTERP=1; fi
cd "$app"
valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --dump-after=rb_ary_cycle "${smc[@]}" \
  --callgrind-out-file="$tmp/cg.out" ruby -rbundler/setup "${flag[@]}" "$here/harness.rb" ir "$n" "$@" 2> "$tmp/log" || { tail -20 "$tmp/log" >&2; exit 1; }
mapfile -t names < <(grep -o '^DEF8 [^ ]*' "$tmp/log" | cut -d' ' -f2)
mapfile -t stats < <(grep '^DEF8 ' "$tmp/log")
mapfile -t dumps < <(ls "$tmp"/cg.out.* | sort -t. -k3 -n)
[ "${#dumps[@]}" -eq "${#names[@]}" ] || { echo "dumps ${#dumps[@]} != workloads ${#names[@]}" >&2; ls "$tmp" >&2; exit 1; }
for i in "${!names[@]}"; do
  ir=$(grep -m1 '^summary:\|^totals:' "${dumps[$i]}" | awk '{print $2}')
  blocks=$(sed 's/.*compiled_blocks=\([0-9-]*\).*/\1/' <<<"${stats[$i]}")
  objects=$(sed 's/.*objects=\([0-9]*\).*/\1/' <<<"${stats[$i]}")
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(basename "$app")" "$label" "$mode" "${names[$i]}" $(( ir / n )) $(( objects / n )) "$blocks" >> "$out"
done
rm -rf "$tmp"
