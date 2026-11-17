#!/usr/bin/env bash
# batch2.sh OUT MODE PATCHES... ; WL file; env N, WARM, NOGC pass through
out=$1; mode=$2; shift 2
cd "$(dirname "$0")"
eval "$(mise activate bash)"
while IFS='|' read -r app wl; do
  for p in "$@"; do
    ruby reqrun.rb "$app" "$wl" ${N:-20} $mode "$PWD/$p" >> "$out" 2>>"$out.err" || echo "FAIL $app $wl $mode $p" >> "$out"
  done
done < ${WL:-wl.txt}
echo DONE >> "$out"
