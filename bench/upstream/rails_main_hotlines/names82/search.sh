#!/usr/bin/env bash
# search.sh QUERIES OUT.jsonl: GitHub code search (REST, default branches) per query line, total count and the first
# 100 hits (repo, path, url), one JSON object per query. Paced for the 10/minute code-search limit.
set -euo pipefail
in=$1 out=$2
: > "$out"
while IFS= read -r q; do
  [[ -z "$q" || "$q" == \#* ]] && continue
  gh api -X GET search/code -f q="$q" -f per_page=100 \
    --jq "{query: \"$(printf '%s' "$q" | sed 's/"/\\"/g')\", total: .total_count, hits: [.items[] | {repo: .repository.full_name, path, url: .html_url}]}" >> "$out" \
    || echo "{\"query\": \"$(printf '%s' "$q" | sed 's/"/\\"/g')\", \"error\": true}" >> "$out"
  sleep 7
done < "$in"
