#!/usr/bin/env bash
# batch.sh OUTDIR MODE WL_FILE: per workload one process each of main, main, head, main (reqrun.rb), in that order;
# lines in OUTDIR/results.txt, logs and dumps in OUTDIR/raw. WARM, FLAT, NOGC, GLIBC_TUNABLES pass through.
set -u
out=$1 mode=$2 wl=$3
cd "$(dirname "$0")"
mkdir -p "$out/raw"
while IFS='|' read -r app w; do
  for side in main main head main; do
    ruby reqrun.rb "$out/raw" "$app" "$w" "${N:-20}" "$mode" "$side" >> "$out/results.txt" 2>> "$out/errors.txt" ||
      echo "FAIL $app $w $mode $side" >> "$out/results.txt"
  done
done < "$wl"
echo DONE >> "$out/results.txt"
