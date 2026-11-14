#!/bin/bash
grep -q "gc17251s done" ~/w/logs/r2q.log 2>/dev/null && exec sleep infinity
# ruby/ruby#17251 (41c689571a on b7e8fad022) + the measurement-only gcstep.patch (default pool mode, so #17251's own
# budget), build ~/w/r17251s: the same shipit and census cells as gc_shipit.sh / gc_census.sh, with sweep-step logs.
# shipit -> ~/w/gcrb/pr17251s-R, census label gc17251s-R, steps ~/w/gcsteps/17251s-R. Log ~/w/logs/gc-17251s.log.
set -u
log=~/w/logs/gc-17251s.log
repo=/home/user/workspace/repo
src=~/w/s5/src-master
if [ ! -x ~/w/r17251s/bin/ruby ]; then
  (cd $src && { git apply --check $repo/fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch 2>/dev/null &&
    git apply $repo/fixtures/corpus/ruby-41-watch/gcstep/gcstep.patch; true; })
  bash $repo/fixtures/corpus/ruby-master-round-2/incr_build.sh $src ~/w/build-17251s ~/w/r17251s >> $log 2>&1
  echo "$(date +%T) build rc=$?" >> $log
fi
~/w/r17251s/bin/ruby -e 'p GC.respond_to?(:gcstep_pool_mode) || true; puts RUBY_DESCRIPTION' >> $log 2>&1
for r in a b; do
  for mode in interp yjit; do
    flags=""; [ $mode = yjit ] && flags=--yjit
    d=~/w/gcrb/pr17251s-$r; mkdir -p $d
    (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r17251s/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
      GCSTEP_LOG=$d/shipit-$mode GCSTEP_OUT=$d/shipit-$mode.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$mode.log 2>&1)
    echo "$(date +%T) shipit $r $mode rc=$?" >> $log
  done
  for a in blog fizzy lobsters; do
    mkdir -p ~/w/gcsteps/17251s-$r
    (cd $repo && CENSUS_GC_OPS=500 CENSUS_GC_MAJOR_BY=1 GCSTEP_LOG=$HOME/w/gcsteps/17251s-$r/$a-yjit \
      mise exec -- script/census run --label gc17251s-$r --ruby ~/w/r17251s --modes yjit --apps $a --corpus census5 \
      > ~/w/logs/gc-census-17251s-$r-$a.log 2>&1)
    echo "$(date +%T) census $r $a rc=$?" >> $log
  done
done
echo "$(date +%T) gc17251s done" >> ~/w/logs/r2q.log
exec sleep infinity
