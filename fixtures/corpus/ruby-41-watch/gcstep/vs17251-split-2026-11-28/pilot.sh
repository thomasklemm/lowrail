#!/bin/bash
# pilot.sh: time one cell of each kind on base before sizing the queue (sequential). ruby-bench benchmarks with 5
# warmups + 5 measured iterations in each mode, and one shipit cell as in queue.sh. Census cell times come from the
# 11-27 queue logs.
# Output ~/w/pilot, log ~/w/logs/pilot.log.
repo=/home/user/workspace/repo
log=~/w/logs/pilot.log
out=~/w/pilot
mkdir -p $out
flags() { case $1 in yjit) echo --yjit ;; zjit) echo --zjit ;; esac; }
for b in activerecord hexapdf liquid-c liquid-compile liquid-render lobsters mail railsbench sequel shipit ruby-lsp gcbench \
    erubi-rails chunky-png liquid-il psych-load rubocop; do
  f=benchmarks/$b/benchmark.rb; [ -f ~/w/ruby-bench/benchmarks/$b.rb ] && f=benchmarks/$b.rb
  for m in interp yjit zjit; do
    s=$(date +%s.%N)
    (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-base/bin:$PATH HARNESS=split WARMUP_ITRS=5 BENCH_ITRS=5 \
      GCMAJORS_SO=$HOME/w/gcmajors/base/gcmajors.so GCSTEP_OUT=$out/$b-$m.json ruby $(flags $m) $f > $out/$b-$m.log 2>&1)
    echo "$b $m rc=$? wall=$(echo "$(date +%s.%N) - $s" | bc)" >> $log
  done
done
s=$(date +%s)
(cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-base/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
  GCMAJORS_SO=$HOME/w/gcmajors/base/gcmajors.so GCSTEP_OUT=$out/shipit-gcstep-interp.json ruby benchmarks/shipit/benchmark.rb \
  > $out/shipit-gcstep-interp.log 2>&1)
echo "shipit-gcstep interp rc=$? wall=$(( $(date +%s) - s ))" >> $log
echo "pilot done" >> $log
