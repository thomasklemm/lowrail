#!/usr/bin/env bash
# usage: all.sh LABEL RUBYBIN EXTRA COMPONENTS...  (idles once a pass is DONE)
label=$1 rubybin=$2 extra=$3; shift 3
sum=$HOME/src/runs/$label/summary.txt
if ! grep -q DONE "$sum" 2>/dev/null; then
  for c in "$@"; do ~/src/runs/run.sh "$label" "$rubybin" "$c" "$extra"; done
  echo DONE >> "$sum"
fi
exec sleep infinity
