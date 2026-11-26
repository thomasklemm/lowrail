#!/usr/bin/env bash
# Reruns completed calibration runs until each reaches its target attempt count, collecting every attempt.
# Usage: duel-round.sh OUTDIR "NAME=ID:TARGET ..."; exits when all targets are collected.
set -uo pipefail
out=$1; specs=$2
collect=/home/user/workspace/repo/.amp/in/orb-backup/duel-collect-attempt.sh
while :; do
  pending=0
  for spec in $specs; do
    name=${spec%%=*}; rest=${spec#*=}; id=${rest%%:*}; target=${rest##*:}
    read -r attempt status < <(gh api "repos/thomasklemm/hashie/actions/runs/$id" --jq '"\(.run_attempt) \(.status)"')
    if [ "$status" = completed ]; then
      for a in $(seq 1 "$attempt"); do RUNS="[$name]=$id" bash "$collect" "$out" "$a" > /dev/null 2>&1; done
      if [ "$attempt" -lt "$target" ]; then gh run rerun "$id" -R thomasklemm/hashie > /dev/null 2>&1; pending=1; fi
    else
      pending=1
    fi
  done
  [ $pending = 0 ] && break
  sleep 45
done
echo round-done
