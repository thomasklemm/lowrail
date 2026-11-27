#!/usr/bin/env bash
# Saves every completed attempt of the given Perf runs, one log and summary per Duel job (YJIT and ZJIT).
# Usage: collect.sh OUTDIR "NAME=RUNID ..."
set -uo pipefail
out=$1; specs=$2
for spec in $specs; do
  name=${spec%%=*}; id=${spec#*=}
  attempts=$(gh api "repos/thomasklemm/hashie/actions/runs/$id" --jq .run_attempt)
  for a in $(seq 1 "$attempts"); do
    gh api "repos/thomasklemm/hashie/actions/runs/$id/attempts/$a/jobs" > /tmp/jobs.$$.json || continue
    jq -c '.jobs[]|select(.status=="completed")' /tmp/jobs.$$.json | while read -r job; do
      jid=$(jq -r .id <<<"$job"); jname=$(jq -r .name <<<"$job")
      jit=yjit; [[ $jname == *zjit* ]] && jit=zjit
      base=$out/$jit/$name-$id-a$a
      mkdir -p "$out/$jit"
      [ -s "$base.log" ] && continue
      echo "$job" > "$base.json"
      gh api --allow-escape-sequences "repos/thomasklemm/hashie/actions/jobs/$jid/logs" | sed 's/\x1b\[[0-9;]*m//g' > "$base.log"
      {
        echo "== $name-$id-a$a $(jq -r '.head_sha + " " + .conclusion + " job " + .started_at + " -> " + .completed_at' <<<"$job")"
        grep -a -E "ruby 4|Comparing|REGRESSION|regressed|slower|benchmarks in|across the board| n=[0-9]+ " "$base.log" | cut -f3- | sed -E 's/^[^ ]+Z //' | sort -u
      } > "$base.summary.txt"
    done
  done
done
rm -f /tmp/jobs.$$.json
