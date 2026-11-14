#!/bin/bash
# point.sh OUT SHA [WIDTH...]: update1 Ir at each width (default 30 300) for a Rails commit, in a worktree
# ~/c9/b-SHA of ~/c9/rails-git. Prints "SHA w30 w300".
set -u
out=$1 sha=$(git -C ~/c9/rails-git rev-parse --short=10 "$2"); shift 2
[ -d ~/c9/b-$sha ] || git -C ~/c9/rails-git worktree add --quiet --detach ~/c9/b-$sha $sha
here=$(cd "$(dirname "$0")" && pwd)
for w in ${@:-30 300}; do [ -s $out/b-$sha-w$w.txt ] || "$here/ir.sh" "$out" b-$sha $w > /dev/null; done
echo "$sha $(for w in ${@:-30 300}; do awk '{printf "%d ", $2}' $out/b-$sha-w$w.txt; done)"
