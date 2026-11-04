#!/usr/bin/env bash
# usage: one.sh LABEL RUBYBIN EXTRA RAILS_DIR COMPONENT...  (one pass, then idles)
label=$1 rubybin=$2 extra=$3 dir=$4; shift 4
marker=$HOME/src/runs/$label/.one-$(basename "$dir")-done
if [ ! -f "$marker" ]; then
  for c in "$@"; do RAILS_DIR=$dir ~/src/runs/run.sh "$label" "$rubybin" "$c" "$extra"; done
  touch "$marker"
fi
exec sleep infinity
