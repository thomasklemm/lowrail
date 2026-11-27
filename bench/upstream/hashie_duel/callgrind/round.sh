#!/usr/bin/env bash
# Reruns completed Perf runs on thomasklemm/hashie until each reaches its target attempt count, collecting
# every attempt's jobs (CPU-time Duel, instructions Duel, counters probe): full log and a summary per job.
# Usage: round.sh OUTDIR "NAME=RUNID:TARGET ..."; returns when all targets are collected. Never stops early
# on a green or red result: attempts are counted, not chosen.
set -uo pipefail
out=$1; specs=$2
mkdir -p "$out"
collect() { # name id attempt
  local name=$1 id=$2 a=$3 base="$out/$1-$2-a$3"
  [ -s "$base.json" ] && return 0
  gh run view "$id" --attempt "$a" -R thomasklemm/hashie --json jobs,headSha,headBranch,conclusion,createdAt,updatedAt > "$base.tmp" || return 1
  if [ "$(jq '[.jobs[] | select(.status != "completed")] | length' "$base.tmp")" != 0 ]; then rm -f "$base.tmp"; return 1; fi
  for job in $(jq -r '.jobs[] | "\(.databaseId)=\(.name | ascii_downcase | gsub("[^a-z]+"; "-"))"' "$base.tmp"); do
    jid=${job%%=*} jname=${job#*=}
    gh api --allow-escape-sequences "repos/thomasklemm/hashie/actions/jobs/$jid/logs" | sed 's/\x1b\[[0-9;]*m//g' > "$base.$jname.log"
    {
      echo "== $name a$a $jname $(jq -r --argjson j "$jid" '.headSha + " " + (.jobs[] | select(.databaseId == $j) | .conclusion + " job " + .startedAt + " -> " + .completedAt)' "$base.tmp")"
      grep -a -E "ruby 4|Comparing|REGRESSION|regressed|slower|faster|benchmarks in|across the board|Measuring|  (Mash|Dash|Trash|KeepOriginalKeys|PermissiveRespondTo)|perf_event_open|EPYC|Xeon|Intel" "$base.$jname.log" \
        | cut -c30- | grep -v '36;1m\|print(' | sort -u
    } > "$base.$jname.summary.txt"
  done
  mv "$base.tmp" "$base.json"
}
while :; do
  pending=0
  for spec in $specs; do
    name=${spec%%=*}; rest=${spec#*=}; id=${rest%%:*}; target=${rest##*:}
    read -r attempt status < <(gh api "repos/thomasklemm/hashie/actions/runs/$id" --jq '"\(.run_attempt) \(.status)"')
    if [ "$status" = completed ]; then
      for a in $(seq 1 "$attempt"); do collect "$name" "$id" "$a" || pending=1; done
      if [ "$attempt" -lt "$target" ]; then gh run rerun "$id" -R thomasklemm/hashie > /dev/null 2>&1; pending=1; fi
    else
      pending=1
    fi
  done
  [ $pending = 0 ] && break
  sleep 60
done
echo round-done
