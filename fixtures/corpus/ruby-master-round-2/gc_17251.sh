#!/bin/bash
grep -q "gc17251 done" ~/w/logs/r2q.log 2>/dev/null && exec sleep infinity
# After chain4: ruby/ruby#17251 (41c689571a on b7e8fad022, build ~/w/r17251, no gcstep patch) in the same GC cells as
# master/fix: ruby-bench shipit (HARNESS=gcstep, interp + YJIT, rounds a b) -> ~/w/gcrb/pr17251-R, and the census
# (YJIT, blog fizzy lobsters, CENSUS_GC_OPS=500, CENSUS_GC_MAJOR_BY=1) -> labels gc17251-a/b. Log ~/w/logs/gc-17251.log.
cd /home/user/workspace/repo
until [ -f ~/w/cg59/parent-yjit/railsbench-a.json ] && grep -q "chain2 done" <(tail -1 ~/w/logs/r2q.log); do sleep 30; done
for r in a b; do
  for mode in interp yjit; do
    flags=""; [ $mode = yjit ] && flags=--yjit
    d=~/w/gcrb/pr17251-$r; mkdir -p $d
    (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r17251/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
      GCSTEP_OUT=$d/shipit-$mode.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$mode.log 2>&1)
    echo "$(date +%T) shipit $r $mode 17251 rc=$?" >> ~/w/logs/gc-17251.log
  done
  for a in blog fizzy lobsters; do
    CENSUS_GC_OPS=500 CENSUS_GC_MAJOR_BY=1 mise exec -- script/census run --label gc17251-$r --ruby ~/w/r17251 --modes yjit \
      --apps $a --corpus census5 > ~/w/logs/gc-census-17251-$r-$a.log 2>&1
    echo "$(date +%T) census $r $a 17251 rc=$?" >> ~/w/logs/gc-17251.log
  done
done
echo "$(date +%T) gc17251 done" >> ~/w/logs/r2q.log
