#!/usr/bin/env bash
# usage: run.sh LABEL RUBY_BIN_DIR COMPONENT [RUBYOPT_EXTRA]
# Runs one Rails component's test task and records its log and exit status.
set -u
label=$1 rubybin=$2 comp=$3 extra=${4:-}
rails=${RAILS_DIR:-$HOME/src/rails-main}
out=$HOME/src/runs/$label
mkdir -p "$out"
task=test
dir=$comp
case $comp in
  activerecord) task=test:sqlite3 ;;
  activerecord-ractor) dir=activerecord task=test:sqlite3:ractor ;;
  activejob) task="test:inline test:async test:test" ;;
esac
cd "$rails/$dir" || exit 1
start=$(date +%s)
env PATH="$rubybin:$PATH" BUNDLE_PATH=$HOME/src/bundle REDIS_URL=redis://localhost:$RP/0 REDIS_URLS=redis://localhost:$RP/0,redis://localhost:$RP/1 MEMCACHE_SERVERS=localhost:$MP RUBYOPT="$extra" SEED=${SEED:-4242} TESTOPTS="--seed=${SEED:-4242}" \
  timeout ${LIMIT:-3600} bundle exec rake $task > "$out/$comp.log" 2>&1
status=$?
echo "$comp status=$status secs=$(( $(date +%s) - start ))" >> "$out/summary.txt"
