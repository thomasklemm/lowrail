#!/bin/bash
# queue.sh: one sequential lane, nothing else running. For each round r: shipit (all modes), then the ruby-bench
# suite (r <= SUITE_ROUNDS), then the 35 Rails workloads (r <= RAILS_ROUNDS). Build order rotates by one each round.
#   shipit: SHIPIT_BUILDS, HARNESS=gcstep (gcstep-harness.rb: the 11-27 harness plus VmHWM and the
#           per-iteration RSS it already read) with the gcmajors records, 15 warmups + 40 measured.
#   suite:  SUITE_BUILDS, HARNESS=split, warmups and measured iterations per benchmark from suite.tsv.
#   rails:  RAILS_BUILDS, census5 Blog, Fizzy, Lobsters, CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1 CENSUS_REQUESTS=0.
# Modes interp, YJIT, ZJIT everywhere. ~/w/rounds.env, read before each round, can lower the round counts. Every cell skips when its output exists. Output ~/w/out, log ~/w/logs/queue.log.
repo=/home/user/workspace/repo
fx=$repo/fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28
log=~/w/logs/queue.log
out=~/w/out
ROUNDS=${ROUNDS:-6} SUITE_ROUNDS=${SUITE_ROUNDS:-3} RAILS_ROUNDS=${RAILS_ROUNDS:-5}
SHIPIT_BUILDS=${SHIPIT_BUILDS:-"base base2 c1 head nocad"}
SUITE_BUILDS=${SUITE_BUILDS:-"base base2 head nocad"}
RAILS_BUILDS=${RAILS_BUILDS:-"base base2 head nocad"}
until grep -q "setup done" ~/w/logs/setup.log 2>/dev/null; do sleep 30; done
rot() { local r=$1; shift; local a=($@); local n=${#a[@]}; for ((i=0;i<n;i++)); do echo -n "${a[$(( (i + r) % n ))]} "; done; }
flags() { case $1 in yjit) echo --yjit ;; zjit) echo --zjit ;; esac; }
rb() { # round mode build bench harness warmups itrs
  local d=$out/$5/$3-$1 o=$out/$5/$3-$1/$4-$2; mkdir -p $d
  [ -f $o.json ] && return
  local f=benchmarks/$4/benchmark.rb; [ -f ~/w/ruby-bench/benchmarks/$4.rb ] && f=benchmarks/$4.rb
  echo "$(date +%T) start $5 $1 $2 $4 $3" >> $log
  (cd ~/w/ruby-bench && env -u RUBYOPT PATH=$HOME/w/r-$3/bin:$PATH HARNESS=$5 WARMUP_ITRS=$6 BENCH_ITRS=$7 \
    GCMAJORS_SO=$HOME/w/gcmajors/$3/gcmajors.so GCSTEP_OUT=$o.json ruby $(flags $2) $f < /dev/null > $o.log 2>&1)
  echo "$(date +%T) $5 $1 $2 $4 $3 rc=$?" >> $log
}
for r in $(seq 1 $ROUNDS); do
  [ -f ~/w/rounds.env ] && . ~/w/rounds.env # round counts can be cut while the queue runs
  [ $r -le $ROUNDS ] || break
  for mode in interp yjit zjit; do
    for v in $(rot $r $SHIPIT_BUILDS); do rb $r $mode $v shipit gcstep 15 40; done
  done
  if [ $r -le $SUITE_ROUNDS ]; then
    for mode in interp yjit zjit; do
      grep -v '^#' $fx/suite.tsv | while read b w n; do
        for v in $(rot $r $SUITE_BUILDS); do rb $r $mode $v $b split $w $n; done
      done
    done
  fi
  if [ $r -le $RAILS_ROUNDS ]; then
    for m in interp yjit zjit; do
      for a in blog fizzy lobsters; do
        for v in $(rot $r $RAILS_BUILDS); do
          mm=$m; [ $m = interp ] && mm=interpreter
          [ -f $repo/.lowrail/private/census/sp$v-$r/$a-$mm.json ] && continue
          echo "$(date +%T) start census $r $m $a $v" >> $log
          (cd $repo && CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1 CENSUS_REQUESTS=0 \
            mise exec -- script/census run --label sp$v-$r --ruby ~/w/r-$v --modes $m --apps $a --corpus census5 \
            < /dev/null > ~/w/logs/census-$v-$r-$a-$m.log 2>&1)
          echo "$(date +%T) census $r $m $a $v rc=$?" >> $log
        done
      done
    done
  fi
done
echo "$(date +%T) queue done" >> $log
