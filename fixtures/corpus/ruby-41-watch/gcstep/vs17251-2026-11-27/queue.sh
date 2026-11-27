#!/bin/bash
# queue.sh LANE: queue5.sh's cells for base f6278067b6, base2 (a copy of base: A/A) and head 9715d0224e, builds
# rotated by one each round. Lanes run at once on the 16-CPU orb; each lane is sequential:
#   shipit: rounds 1-6, HARNESS=gcstep, 15 warm-up + 40 measured iterations, interp, YJIT, ZJIT.
#   interp | yjit | zjit: census rounds 1-5, blog fizzy lobsters, CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1
#     CENSUS_REQUESTS=0, in the mode's own app copies (census5, census5y, census5z).
# Every cell skips when its output exists. Log ~/w/logs/q-LANE.log.
lane=$1
repo=/home/user/workspace/repo
log=~/w/logs/q-$lane.log
OPS=${OPS:-1000}
until grep -q "setup done" ~/w/logs/setup.log 2>/dev/null; do sleep 30; done
rot() { local r=$1; shift; local a=("$@"); local n=${#a[@]} k=$(( r % $# )); for ((i=0;i<n;i++)); do echo -n "${a[$(( (i + k) % n ))]} "; done; }
shipit() { # round mode build
  local d=~/w/gcrb/$3-$1 flags=""; mkdir -p $d
  [ $2 = yjit ] && flags=--yjit
  [ $2 = zjit ] && flags=--zjit
  [ -f $d/shipit-$2.json ] && return
  echo "$(date +%T) start shipit $1 $2 $3" >> $log
  (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-$3/bin:$PATH HARNESS=gcstep WARMUP_ITRS=15 BENCH_ITRS=40 \
    GCSTEP_OUT=$d/shipit-$2.json ruby $flags benchmarks/shipit/benchmark.rb > $d/shipit-$2.log 2>&1)
  echo "$(date +%T) shipit $1 $2 $3 rc=$?" >> $log
}
if [ $lane = shipit ]; then
  for r in 1 2 3 4 5 6; do
    for mode in interp yjit zjit; do
      for v in $(rot $r base base2 head); do shipit $r $mode $v; done
    done
  done
else
  case $lane in interp) c=census5 m=interpreter ;; yjit) c=census5y m=yjit ;; zjit) c=census5z m=zjit ;; esac
  for r in 1 2 3 4 5; do
    for a in blog fizzy lobsters; do
      for v in $(rot $r base base2 head); do
        [ -f $repo/.lowrail/private/census/gc$v-$r/$a-$m.json ] && continue
        echo "$(date +%T) start census $r $lane $a $v" >> $log
        (cd $repo && CENSUS_GC_OPS=$OPS CENSUS_GC_MAJOR_BY=1 CENSUS_REQUESTS=0 \
          mise exec -- script/census run --label gc$v-$r --ruby ~/w/r-$v --modes $lane --apps $a --corpus $c \
          > ~/w/logs/census-$v-$r-$a-$lane.log 2>&1)
        echo "$(date +%T) census $r $lane $a $v rc=$?" >> $log
      done
    done
  done
fi
echo "$(date +%T) queue done" >> $log
