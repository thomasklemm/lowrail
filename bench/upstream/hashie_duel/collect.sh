#!/usr/bin/env bash
# Saves every completed Perf run of the fork's calibration PRs: the Duel job log (escape codes removed),
# the run metadata and the Duel summary lines. Usage: duel-collect.sh OUTDIR
set -euo pipefail
out=$1
mkdir -p "$out"
gh api 'repos/thomasklemm/hashie/actions/runs?per_page=100' \
  --jq '.workflow_runs[]|select(.name=="Perf" and .status=="completed")|"\(.id) \(.run_attempt) \(.head_branch) \(.head_sha) \(.conclusion)"' |
while read -r id attempt branch sha conclusion; do
  name=${branch#calib/}-$id-a$attempt
  [ -s "$out/$name.log" ] && continue
  job=$(gh run view "$id" --attempt "$attempt" -R thomasklemm/hashie --json jobs --jq '.jobs[0].databaseId')
  gh run view "$id" --attempt "$attempt" -R thomasklemm/hashie --json jobs,headSha,headBranch,conclusion,createdAt,updatedAt > "$out/$name.json"
  gh run view -R thomasklemm/hashie --log --job "$job" | sed 's/\x1b\[[0-9;]*m//g' > "$out/$name.log"
  {
    echo "== $name $sha $conclusion job $(jq -r '.jobs[0].startedAt + " -> " + .jobs[0].completedAt' "$out/$name.json")"
    grep -a -E "ruby 4|Comparing|REGRESSION|regressed|slower|benchmarks in|across the board|  (Mash|Dash|Trash)" "$out/$name.log" | cut -f3- | sed -E 's/^[^ ]+Z //' | sort -u
  } > "$out/$name.summary.txt"
done
cat "$out"/*.summary.txt
