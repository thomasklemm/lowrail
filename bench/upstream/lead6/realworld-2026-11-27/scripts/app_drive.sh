#!/bin/bash
# app_drive.sh OUT ROUNDS "MODES" "ARMS": one fresh process per (round, mode, arm), arm order rotated per round.
out=$1; rounds=$2; modes=$3; arms=($4)
for ((r=0; r<rounds; r++)); do
  for mode in $modes; do
    n=${#arms[@]}
    for ((i=0; i<n; i++)); do
      arm=${arms[$(( (i + r) % n ))]}
      ROUND=$r ./app_run.sh $arm $mode 2>>/tmp/app_drive.err | tail -1 | sed "s/\"mode\":\"[a-z]*\"/\"mode\":\"$mode\"/" >> $out
      echo "round $r $mode $arm" >&2
    done
  done
done
