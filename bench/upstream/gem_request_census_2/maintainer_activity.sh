#!/usr/bin/env bash
# Maintainer activity per repo (docs/upstream/gem-request-census-2.md): last default-branch commit, PRs merged in the
# last 60 days, open PRs, and the five most recent merges as "#PR date by author/merger".
#   bash maintainer_activity.sh OWNER/REPO...
# The two counts use GitHub's search API, which rate-limits; an empty count means the search was refused, not zero.
since=$(date -u -d '60 days ago' +%Y-%m-%d)
for repo in "$@"; do
  last=$(gh api "repos/$repo/commits?per_page=1" --jq '.[0] | "\(.commit.committer.date[0:10]) \(.commit.author.name)"' 2>/dev/null)
  merged=$(gh search prs --repo "$repo" --merged-at ">=$since" --limit 100 --json number --jq 'length' 2>/dev/null)
  mergers=$(gh pr list --repo "$repo" --state merged --limit 15 --json number,mergedAt,author,mergedBy \
    --jq '[.[] | "#\(.number) \(.mergedAt[0:10]) by \(.author.login)/\(.mergedBy.login // "?")"] | .[0:5] | join("; ")' 2>/dev/null)
  open=$(gh search prs --repo "$repo" --state open --limit 200 --json number --jq length 2>/dev/null)
  echo "$repo | last commit $last | merged PRs since $since: $merged | open PRs: $open | recent merges: $mergers"
done
