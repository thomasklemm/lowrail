#!/usr/bin/env bash
# mkvariant.sh NAME [rails=PATH] [sqlite=VERSION]
# Creates branch v/NAME in the ruby-bench clone from the blog head with the Gemfiles of
# blog, railsbench and lobsters pointed at a Rails checkout and/or a locally built sqlite3,
# relocks them, commits, and makes a worktree /tmp/x/rb-NAME (the audit SRC).
set -euo pipefail
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
RB=/home/user/workspace/repos/rb
BASE=${BASE:-v-exp}
name=$1; shift
rails=""; sqlite=""
for a in "$@"; do case $a in rails=*) rails=${a#rails=};; sqlite=*) sqlite=${a#sqlite=};; esac; done
wt=/tmp/x/rb-$name
git -C $RB worktree remove --force $wt 2>/dev/null || true
git -C $RB branch -D v/$name 2>/dev/null || true
git -C $RB worktree add -q -b v/$name $wt $BASE
cd $wt/benchmarks
for b in blog railsbench lobsters; do
  if [ -n "$rails" ]; then
    sed -i -E "s|^gem \"rails\", .*|gem \"rails\", path: \"$rails\"|; s|^  gem rails_gem, ['\"]~> 8.0['\"]|  gem rails_gem, path: \"$rails\"|" $b/Gemfile
  fi
  if [ -n "$sqlite" ]; then
    sed -i -E "s|^gem ['\"]sqlite3['\"].*|gem \"sqlite3\", \"$sqlite\"|" $b/Gemfile
  fi
  (cd $b && bundle lock ${sqlite:+--local} >/tmp/x/lock-$name-$b.log 2>&1 || { echo "lock failed $name $b"; tail -5 /tmp/x/lock-$name-$b.log; exit 1; })
done
cd $wt && git add -A benchmarks && { git diff --cached --quiet || git -c user.name=x -c user.email=x@x commit -q -m "variant $name"; } && git log --oneline -1
