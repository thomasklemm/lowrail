#!/usr/bin/env bash
# Reruns completed runs until each reaches its target attempts, then collects every attempt.
# Usage: round.sh OUTDIR "NAME=RUNID:TARGET ..."
set -uo pipefail
out=$1; specs=$2; here=$(dirname "$0")
while :; do
  pending=0; ids=""
  for spec in $specs; do
    name=${spec%%=*}; rest=${spec#*=}; id=${rest%%:*}; target=${rest##*:}; ids="$ids $name=$id"
    read -r attempt status < <(gh api "repos/thomasklemm/hashie/actions/runs/$id" --jq '"\(.run_attempt) \(.status)"')
    if [ "$status" = completed ]; then
      if [ "$attempt" -lt "$target" ]; then bash "$here/collect.sh" "$out" "$name=$id"; gh run rerun "$id" -R thomasklemm/hashie >/dev/null 2>&1; pending=1; fi
    else pending=1; fi
  done
  [ $pending = 0 ] && { bash "$here/collect.sh" "$out" "$ids"; break; }
  sleep 45
done
echo round-done
