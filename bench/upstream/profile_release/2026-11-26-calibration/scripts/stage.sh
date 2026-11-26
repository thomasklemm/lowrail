#!/usr/bin/env bash
# stage.sh APP: copy capture.json, command.txt, report.json.gz, plant patches and wall.txt into the receipt.
set -eu
D=/home/user/workspace/repo/bench/upstream/profile_release/2026-11-26-calibration/captures/$1; src=/home/user/cal/out/$1
mkdir -p "$D"; cd "$src"
for s in ${STEPS:-s1 s2 s3 s4 s5 s6 s7 s8 planted planted2}; do
  mkdir -p "$D/$s"; cp "$s/capture.json" "$s/command.txt" "$D/$s/"; gzip -9nc "$s/report.json" > "$D/$s/report.json.gz"
done
cp planted.patch planted2.patch "$D/"; [ -f installed-from.txt ] && cp installed-from.txt "$D/"
grep -v ALL summary.txt > "$D/wall.txt"
