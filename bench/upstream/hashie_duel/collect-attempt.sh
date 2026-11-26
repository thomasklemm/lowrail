#!/usr/bin/env bash
# Saves one attempt of the A/A runs. Usage: duel-collect-attempt.sh OUTDIR ATTEMPT
set -euo pipefail
out=$1 attempt=$2
declare -A runs=([aa-1]=45813159416 [aa-2]=45813245406 [aa-3]=45813254922 [aa-4]=45813265368 [aa-5]=45813272820)
[ -n "${RUNS:-}" ] && eval "runs=($RUNS)"
for b in "${!runs[@]}"; do
  id=${runs[$b]} name=$b-${runs[$b]}-a$attempt
  [ -s "$out/$name.log" ] && continue
  gh run view "$id" --attempt "$attempt" -R thomasklemm/hashie --json jobs,headSha,headBranch,conclusion,createdAt,updatedAt > "$out/$name.json"
  [ "$(jq -r '.jobs[0].status' "$out/$name.json")" = completed ] || { rm "$out/$name.json"; echo "$name not done"; continue; }
  job=$(jq -r '.jobs[0].databaseId' "$out/$name.json")
  gh api --allow-escape-sequences "repos/thomasklemm/hashie/actions/jobs/$job/logs" | sed 's/\x1b\[[0-9;]*m//g' > "$out/$name.log"
  {
    echo "== $name $(jq -r '.headSha + " " + .jobs[0].conclusion + " job " + .jobs[0].startedAt + " -> " + .jobs[0].completedAt' "$out/$name.json")"
    grep -a -E "ruby 4|Comparing|REGRESSION|regressed|slower|benchmarks in|across the board|  (Mash|Dash|Trash)" "$out/$name.log" | cut -f3- | sed -E 's/^[^ ]+Z //' | sort -u
  } > "$out/$name.summary.txt"
done
