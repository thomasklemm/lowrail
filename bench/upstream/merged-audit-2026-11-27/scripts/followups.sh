#!/bin/bash
# For each merge M of our PR: files touched (non-CHANGELOG), lines added by our commits vs lines surviving at origin/main blame.
cd /home/user/workspace/repos/rails
while read n m; do
  M=$(git rev-parse $m)
  if [ $(git rev-list --parents -n1 $M | wc -w) = 3 ]; then ours=$(git rev-list $M^1..$M^2); else ours=$M; fi
  for f in $(git diff --name-only $M^1 $M | rg -v 'CHANGELOG'); do
    added=$(git diff $M^1 $M -- "$f" | rg -c '^\+[^+]' ); added=${added:-0}
    [ "$added" = 0 ] && continue
    git cat-file -e origin/main:"$f" 2>/dev/null || { echo "$n $f GONE"; continue; }
    echo "$ours" > /tmp/ours.txt; surv=$(git blame --line-porcelain origin/main -- "$f" 2>/dev/null | rg "^[0-9a-f]{40} " | cut -d" " -f1 | rg -c -F -f /tmp/ours.txt)
    surv=${surv:-0}
    if [ "$surv" -lt "$added" ]; then
      echo "$n $f added=$added surviving=$surv"
      git log --format="    %h %ad %an: %s" --date=short $M..origin/main -- "$f" | head -8
    fi
  done
done
