#!/bin/bash
# attrib.sh: after queue.sh's shipit lane, shipit attribution rounds h1-h3 as in queue5.sh: GCMAJORS_SO (the
# vs17251-2026-11-24/gcmajors tracepoint, built per Ruby in ~/w/gcmajors/V) records each completed GC's major_by,
# time and old_objects; builds base and head alternating, interp, YJIT and ZJIT. Log ~/w/logs/q-attrib.log.
log=~/w/logs/q-attrib.log
until grep -q "queue done" ~/w/logs/q-shipit.log 2>/dev/null; do sleep 30; done
for r in 1 2 3; do
  for mode in interp yjit zjit; do
    if [ $((r % 2)) = 1 ]; then bs="base head"; else bs="head base"; fi
    for v in $bs; do
      d=~/w/gcrb/$v-h$r flags=""; mkdir -p $d
      [ $mode = yjit ] && flags=--yjit; [ $mode = zjit ] && flags=--zjit
      [ -f $d/shipit-$mode.json ] && continue
      echo "$(date +%T) start shipit h$r $mode $v" >> $log
      (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-$v/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
        GCMAJORS_SO=$HOME/w/gcmajors/$v/gcmajors.so GCSTEP_OUT=$d/shipit-$mode.json ruby $flags \
        benchmarks/shipit/benchmark.rb > $d/shipit-$mode.log 2>&1)
      echo "$(date +%T) shipit h$r $mode $v rc=$?" >> $log
    done
  done
done
echo "$(date +%T) queue done" >> $log
