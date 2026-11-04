#!/usr/bin/env bash
# usage: lane.sh LANE LABEL... ; runs every component for each label in turn.
lane=$1; shift
comps=${COMPS:-"activesupport activemodel activerecord-sqlite3 activerecord-postgresql actionpack actionview actionmailer actionmailbox activejob actioncable activestorage actiontext railties"}
here=$(dirname "$(readlink -f "$0")")
for label in "$@"; do
  grep -q DONE "$HOME/src/runs/$label/summary.txt" 2>/dev/null && continue
  for c in $comps; do
    grep -q "^$c status" "$HOME/src/runs/$label/summary.txt" 2>/dev/null && continue
    "$here/run.sh" "$lane" "$label" "$c"
  done
  echo DONE >> "$HOME/src/runs/$label/summary.txt"
done
