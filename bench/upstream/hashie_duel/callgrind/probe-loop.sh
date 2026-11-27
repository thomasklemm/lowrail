#!/usr/bin/env bash
# Reruns the counters probe TARGET times and saves each attempt's log. Usage: probe-loop.sh OUTDIR RUNID TARGET
set -uo pipefail
out=$1 id=$2 target=$3
mkdir -p "$out"
while :; do
  read -r attempt status < <(gh api "repos/thomasklemm/hashie/actions/runs/$id" --jq '"\(.run_attempt) \(.status)"')
  if [ "$status" = completed ]; then
    for a in $(seq 1 "$attempt"); do
      [ -s "$out/probe-a$a.log" ] || gh run view "$id" --attempt "$a" -R thomasklemm/hashie --log 2>/dev/null | cut -f3- | sed -E 's/^[^ ]+Z //' | grep -v '36;1m' > "$out/probe-a$a.log"
    done
    [ "$attempt" -ge "$target" ] && break
    gh run rerun "$id" -R thomasklemm/hashie > /dev/null 2>&1
  fi
  sleep 30
done
echo probe-done
