#!/usr/bin/env bash
set -euo pipefail
root=/home/user/workspace/repo
cache="$root/.amp/in/orb-backup/sq37-review/min-versions"
side=$1 sqlite=$2
shift 2
if [[ $side == base ]]; then sha=088fc0cf61e4ba0c7987decafacc69adb3e22eec; else sha=3e348f32bdc2b5b405d31f226e6de04aa3278dc9; fi
tree="$cache/trees/$sha"
export BUNDLE_GEMFILE="$tree/.min-versions/ruby-4.0.9-sqlite-$sqlite/Gemfile"
export BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$sqlite" BUNDLE_WITHOUT=db
export LD_LIBRARY_PATH="$cache/sqlite-$sqlite/lib" PATH="$cache/sqlite-$sqlite/bin:$PATH"
export ARCONN=sqlite3 PARALLEL_WORKERS=1 MT_CPU=1
unset RUBYOPT GEM_HOME GEM_PATH BUNDLE_FROZEN BUNDLE_DEPLOYMENT
cd "$tree/activerecord"
exec mise exec ruby@4.0.9 -- bundle exec ruby -Itest "$@"
