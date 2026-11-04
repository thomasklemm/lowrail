#!/usr/bin/env bash
# usage (from ~/src/diff-bis during git bisect run): run.sh CHECK.rb   exit 0 = old behaviour, 1 = new, 125 = skip
. $HOME/src/diff/env.sh
export BUNDLE_GEMFILE=$HOME/src/diff-main/Gemfile
W=$HOME/src/diff-bis
I="-I$W/activesupport/lib -I$W/activemodel/lib -I$W/activerecord/lib -I$W/actionpack/lib -I$W/actionview/lib"
out=$(cd $HOME/src/diff-main && timeout 120 bundle exec ruby $I "$1" 2>&1 | tail -1)
case "$out" in OLD*) exit 0;; NEW*) exit 1;; *) echo "skip: $out" >&2; exit 125;; esac
