#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
cache="$root/.amp/in/orb-backup/min-versions"
side=$1 version=$2
shift 2
case "$side" in
  base) sha=088fc0cf61e4ba0c7987decafacc69adb3e22eec ;;
  head) sha=3e348f32bdc2b5b405d31f226e6de04aa3278dc9 ;;
  *) exit 2 ;;
esac
tree="$cache/trees/$sha"
export BUNDLE_GEMFILE="$tree/.min-versions/ruby-4.0.9-sqlite-$version/Gemfile"
export BUNDLE_PATH="$cache/bundle/ruby-4.0.9/sqlite-$version"
export BUNDLE_WITHOUT=db
export LD_LIBRARY_PATH="$cache/sqlite-$version/lib"
export PATH="$cache/sqlite-$version/bin:$PATH"
export ARCONN=sqlite3 PARALLEL_WORKERS=1 MT_CPU=1
unset RUBYOPT GEM_HOME GEM_PATH BUNDLE_FROZEN BUNDLE_DEPLOYMENT
cd "$tree/activerecord"
exec mise exec ruby@4.0.9 -- bundle exec ruby -Itest "$@"
