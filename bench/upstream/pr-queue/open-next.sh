#!/bin/bash
# Opens queued rails/rails PRs while fewer than 15 of thomasklemm's non-draft PRs are open
# (GitHub's limit for users without write access). Each queue line: body file (first line
# "### Title", then a blank line, then the body), fork branch, short name. Opened lines move
# to opened.tsv. Run from the Lowrail checkout root; commit the changed .tsv files afterwards.
set -u; d=bench/upstream/pr-queue
ready=$(gh api "search/issues?q=repo:rails/rails+author:thomasklemm+is:pr+is:open+draft:false&per_page=1" --jq .total_count)
echo "ready_open=$ready"
while [ "$ready" -lt 15 ] && [ -s "$d/queue.tsv" ]; do
  IFS=$'\t' read -r body branch name < "$d/queue.tsv"
  title=$(head -1 "$body" | sed 's/^### //'); tail -n +3 "$body" > /tmp/pr-body.md
  out=$(gh api repos/rails/rails/pulls -f title="$title" -f head="thomasklemm:$branch" -f base=main -F body=@/tmp/pr-body.md --jq '[.number,.head.sha]|@tsv' 2>&1) || { echo "FAILED $name: $out"; break; }
  echo "OPENED $name $out"; printf '%s\t%s\t%s\n' "$name" "$branch" "$out" >> "$d/opened.tsv"
  tail -n +2 "$d/queue.tsv" > "$d/q.tmp" && mv "$d/q.tmp" "$d/queue.tsv"; ready=$((ready+1)); sleep 5
done
echo "queue_left=$(wc -l < "$d/queue.tsv")"
