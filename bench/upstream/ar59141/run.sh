#!/bin/bash
# run.sh SCRIPT [TREE...]: run a plain Active Record script on each Rails tree (base = #59141's parent, cand = main,
# merge = #59141 itself; p59634/m59634 = parent/merge of rails#59634). Trees: ~/src/readiness/round-59141/rails-{base,cand}
# (the readiness runner checks them out), ~/src/eco/rails-{merge,p59634,m59634} (git worktrees of rails/rails).
here=$(cd "$(dirname "$0")" && pwd); script=$(realpath "$1"); shift
for t in ${@:-base cand}; do
  case $t in merge) dir=$HOME/src/eco/rails-merge ;; p59634|m59634) dir=$HOME/src/eco/rails-$t ;; *) dir=$HOME/src/readiness/round-59141/rails-$t ;; esac
  echo "== $t ($(git -C $dir rev-parse --short=10 HEAD))"
  (cd $here && BUNDLE_GEMFILE=$here/Gemfile RAILS_DIR=$dir mise exec ruby@4.0.9 -- bash -c "bundle install --quiet >/dev/null 2>&1 || bundle install; bundle exec ruby $script" 2>&1)
done
