#!/bin/bash
# queue5.sh: one sequential queue, nothing else runs on the orb while it does. Every cell skips when its output exists.
#  1. shipit, rounds 1-6: HARNESS=gcstep, 15 warm-up + 40 measured iterations, interp + YJIT, builds
#     master old new m760 mg in an order rotated by one each round. No GCSTEP_LOG (no step log).
#  2. shipit attribution, rounds h1-h3: as 1 with GCMAJORS_SO (per-GC records), builds master old new.
#  3. bigslot (RING=200 BIG=70 N=40000), 9 runs per build, alternating master old new m760.
#  4. census, rounds 1-5: blog fizzy lobsters, interp + YJIT, CENSUS_GC_OPS=$OPS CENSUS_GC_MAJOR_BY=1
#     CENSUS_REQUESTS=0 (no GC-disabled traced window), builds master old new rotated per round
#     (m760 ran only round 1 interp Blog: dropped for time after an orb pause stalled the queue).
# shipit rounds 4-6 drop mg. Log ~/w/logs/q.log.
repo=/home/user/workspace/repo
fx=$repo/fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-24
log=~/w/logs/q.log
OPS=${OPS:-1000}
until grep -q "build done" ~/w/logs/build.log 2>/dev/null && grep -q "setup done" ~/w/logs/setup.log 2>/dev/null; do sleep 30; done
rot() { local r=$1; shift; local a=("$@"); local n=${#a[@]} k=$(( r % $# )); for ((i=0;i<n;i++)); do echo -n "${a[$(( (i + k) % n ))]} "; done; }
shipit() { # round mode build [so]
  local d=~/w/gcrb/$3-$1 flags=""; mkdir -p $d
  [ $2 = yjit ] && flags=--yjit
  [ -f $d/shipit-$2.json ] && return
  echo "$(date +%T) start shipit $1 $2 $3 boot=$(uptime -s)" >> $log
  (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-$3/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
    ${4:+GCMAJORS_SO=$4} GCSTEP_OUT=$d/shipit-$2.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$2.log 2>&1)
  echo "$(date +%T) shipit $1 $2 $3 rc=$?" >> $log
}
for r in 1 2 3 4 5 6; do
  for mode in interp yjit; do
    if [ $r -le 3 ]; then bs="master old new m760 mg"; else bs="master old new m760"; fi
    for v in $(rot $r $bs); do shipit $r $mode $v; done
  done
done
for r in 1 2 3; do
  for mode in interp yjit; do
    for v in $(rot $r master old new); do shipit h$r $mode $v ~/w/gcmajors/$v/gcmajors.so; done
  done
done
mkdir -p ~/w/bigslot
for i in 1 2 3 4 5 6 7 8 9; do
  for v in $(rot $i master old new m760); do
    f=~/w/bigslot/$v-$i.txt; [ -s $f ] && continue
    RING=200 BIG=70 N=40000 ~/w/r-$v/bin/ruby $repo/fixtures/corpus/ruby-master-round-2/bigslot.rb > $f 2>&1
    echo "$(date +%T) bigslot $i $v rc=$?" >> $log
  done
done
for r in 1 2 3 4 5; do
  for mode in interp yjit; do
    for a in blog fizzy lobsters; do
      for v in $(rot $r master old new); do
        m=$mode; [ $m = interp ] && m=interpreter; [ -f $repo/.lowrail/private/census/gc$v-$r/$a-$m.json ] && continue
        echo "$(date +%T) start census $r $mode $a $v boot=$(uptime -s)" >> $log
        (cd $repo && CENSUS_GC_OPS=$OPS CENSUS_GC_MAJOR_BY=1 CENSUS_REQUESTS=0 \
          mise exec -- script/census run --label gc$v-$r --ruby ~/w/r-$v --modes $mode --apps $a --corpus census5 \
          > ~/w/logs/census-$v-$r-$a-$mode.log 2>&1)
        echo "$(date +%T) census $r $mode $a $v rc=$?" >> $log
      done
    done
  done
done
echo "$(date +%T) queue done" >> $log
exec sleep infinity
