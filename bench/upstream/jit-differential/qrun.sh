#!/bin/bash
# qrun.sh QUEUEFILE: pop lines and run them; "ruby BUILD MODE SUITE TAG" or dispatch kinds.
cd ~/jitdiff; Q=$1
while true; do
  line=$(flock $Q sh -c 'l=$(head -1 "$1"); sed -i 1d "$1"; echo "$l"' _ $Q)
  if [ -z "$line" ]; then sleep 30; continue; fi
  case "$line" in \#*) continue;; esac
  echo "$(date -u +%FT%T) start [$Q] $line" >> out/qlog.txt
  set -- $line
  if [ "$1" = ruby ]; then shift; ./rsuite.sh "$@"; else ./dispatch.sh "$@"; fi
  echo "$(date -u +%FT%T) end [$Q] $line" >> out/qlog.txt
done
