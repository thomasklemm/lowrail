#!/bin/bash
# cell.sh LABEL ROUND APP MODE : one census GC window run, reaps the sqlite3 exit deadlock
# Builds: gsm = master 9aa0898240 + gcstep.patch, gsp = 9aa0898240 + ruby/ruby#17251 (f5e41985e9) + gcstep.patch;
# RUBY_GC_POOL_MODE=slots gives the pool-budget fix at run time.
label=$1; round=$2; a=$3; mode=$4
case $label in
  master) rb=gsm pm=bytes ;; pr) rb=gsp pm=bytes ;; pool) rb=gsm pm=slots ;; both) rb=gsp pm=slots ;;
esac
base=/home/user/workspace/repo/.lowrail/private/ruby-41-watch
out=$base/gs-$label-$round; steps=/tmp/w/gsteps/$label-$round
mkdir -p $out $steps
rm -f $out/$a-$mode.json $steps/$a-$mode-*
export CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1 GCSTEP_LOG=$steps/$a-$mode RUBY_GC_POOL_MODE=$pm
/home/user/workspace/repo/fixtures/corpus/ruby-41-watch/c4.sh $rb $a $mode profile $out/$a-$mode.json > /tmp/w/logs/gs-$label-$round-$a-$mode.log 2>&1 &
pid=$!
while kill -0 $pid 2>/dev/null; do
  sleep 5
  if [ -f $out/$a-$mode.json ] && [ $(( $(date +%s) - $(stat -c %Y $out/$a-$mode.json) )) -gt 20 ]; then
    pkill -KILL -f "profile $a $out/$a-$mode.json" 2>/dev/null; echo "reaped $label $round $a $mode" >> /tmp/w/logs/reaped
  fi
done
[ -f $out/$a-$mode.json ] || echo "MISSING $label $round $a $mode" >> /tmp/w/logs/missing
