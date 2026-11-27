#!/usr/bin/env bash
# apav-run.sh LANE RUBYDIR LABEL : actionpack and actionview on Rails main, seed 4242, stall watchdog
lane=$1 ruby=$2 label=$3
out=$HOME/rdiff/apav/runs/$label; mkdir -p $out
for comp in actionpack actionview; do
  grep -q "^$comp status" $out/summary.txt 2>/dev/null && continue
  cd ~/rdiff/apav/rails-$lane/$comp
  start=$(date +%s)
  env PATH=$ruby/bin:$PATH BUNDLE_PATH=$HOME/rdiff/apav/bundle-$lane BUNDLE_FROZEN=true BUNDLE_WITHOUT="rubocop:mdl:doc:job:cable:storage:db" \
    SEED=4242 TESTOPTS="--seed=4242 -v" timeout 3600 bundle exec rake test > $out/$comp.log 2>&1 &
  pid=$!
  while kill -0 $pid 2>/dev/null; do
    sleep 15
    if [ $(( $(date +%s) - $(stat -c %Y $out/$comp.log) )) -gt 300 ]; then
      echo "$comp stalled, killed after $(( $(date +%s) - start ))s" >> $out/summary.txt; pkill -TERM -P $pid; kill -TERM $pid
    fi
  done
  wait $pid; echo "$comp status=$? secs=$(( $(date +%s) - start ))" >> $out/summary.txt
done
echo DONE >> $out/summary.txt; exec sleep infinity
