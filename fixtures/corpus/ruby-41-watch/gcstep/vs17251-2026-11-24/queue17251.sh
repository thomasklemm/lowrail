#!/bin/bash
# After setup: shipit (HARNESS=gcstep, 15 warmup + 40 measured, interp + YJIT) then census (CENSUS_GC_OPS=500,
# CENSUS_GC_MAJOR_BY=1, blog fizzy lobsters, interp + YJIT), builds master/old/new alternating, rounds a b.
# Every cell skips when its output exists. Log ~/w/logs/q.log.
repo=/home/user/workspace/repo
log=~/w/logs/q.log
until grep -q "setup done" ~/w/logs/setup.log 2>/dev/null; do sleep 30; done
for r in a b; do
  for mode in interp yjit; do
    flags=""; [ $mode = yjit ] && flags=--yjit
    for v in master old new; do
      d=~/w/gcrb/$v-$r; mkdir -p $d
      [ -f $d/shipit-$mode.json ] && continue
      (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-$v/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
        GCSTEP_LOG=$d/shipit-$mode GCSTEP_OUT=$d/shipit-$mode.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$mode.log 2>&1)
      echo "$(date +%T) shipit $r $mode $v rc=$?" >> $log
    done
  done
done
for r in a b; do
  for mode in interp yjit; do
    for a in blog fizzy lobsters; do
      for v in master old new; do
        m=$mode; [ $m = interp ] && m=interpreter; [ -f $repo/.lowrail/private/census/gc$v-$r/$a-$m.json ] && continue
        mkdir -p ~/w/gcsteps/$v-$r
        (cd $repo && CENSUS_GC_OPS=500 CENSUS_GC_MAJOR_BY=1 GCSTEP_LOG=$HOME/w/gcsteps/$v-$r/$a-$mode \
          mise exec -- script/census run --label gc$v-$r --ruby ~/w/r-$v --modes $mode --apps $a --corpus census5 \
          > ~/w/logs/census-$v-$r-$a-$mode.log 2>&1)
        echo "$(date +%T) census $r $mode $a $v rc=$?" >> $log
      done
    done
  done
done
echo "$(date +%T) queue done" >> $log
exec sleep infinity
