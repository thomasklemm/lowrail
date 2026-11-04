#!/usr/bin/env bash
# usage: run.sh LANE LABEL COMPONENT
# LANE is "m" (Ruby master) or "c" (Ruby 4.0.9 control); each lane has its own
# Rails worktree, PostgreSQL, Redis and memcached so lanes can run at once.
set -u
lane=$1 label=$2 comp=$3
case $lane in
  m) rubybin=$HOME/rubies/master/bin rails=$HOME/src/rails-m pg=5432 rp=6379 mp=11211 ;;
  c) rubybin=$HOME/.local/share/mise/installs/ruby/4.0.9/bin rails=$HOME/src/rails-c pg=5433 rp=6380 mp=11212 ;;
esac
out=$HOME/src/runs/$label
mkdir -p "$out"
task=test dir=$comp
case $comp in
  activerecord-sqlite3) dir=activerecord task=test:sqlite3 ;;
  activerecord-postgresql) dir=activerecord task="db:postgresql:rebuild test:postgresql" ;;
  activejob) task="test:inline test:async test:test" ;;
  actionpack-noractor|actionview-noractor) dir=${comp%-noractor} exclude="--exclude=/[Rr]actor/" ;;
esac
cd "$rails/$dir" || exit 1
start=$(date +%s)
env PATH="$rubybin:$PATH" BUNDLE_PATH=$HOME/src/bundle BUNDLE_FROZEN=true \
  PGHOST=localhost PGPORT=$pg PGUSER=user \
  REDIS_URL=redis://localhost:$rp/0 REDIS_URLS=redis://localhost:$rp/0,redis://localhost:$rp/1 \
  MEMCACHE_SERVERS=localhost:$mp SEED=${SEED:-4242} TESTOPTS="--seed=${SEED:-4242} ${exclude:-}" \
  timeout ${LIMIT:-3600} bundle exec rake $task > "$out/$comp.log" 2>&1 &
pid=$!
# A crashed parallel worker leaves the suite waiting forever: stop a run whose
# log has not grown for STALL seconds and record it.
while kill -0 $pid 2>/dev/null; do
  sleep 15
  if [ $(( $(date +%s) - $(stat -c %Y "$out/$comp.log") )) -gt ${STALL:-300} ]; then
    echo "$comp stalled, killed after $(( $(date +%s) - start ))s" >> "$out/summary.txt"
    pkill -TERM -P $pid; kill -TERM $pid
  fi
done
wait $pid
status=$?
echo "$comp status=$status secs=$(( $(date +%s) - start ))" >> "$out/summary.txt"
