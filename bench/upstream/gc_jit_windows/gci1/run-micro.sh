#!/bin/bash
# GCI1 micro: per shape, one --zjit-stats run (exit counts per arm), then 4 timed and 4 A/A processes, alternating, alone on core 1.
cd "$(dirname "$0")"; O=$PWD/micro.jsonl; C=$HOME/w/ruby-cur/bin/ruby; M=$PWD/micro.rb
fk() { (cd ~/w/rails-main && env BUNDLE_GEMFILE=$HOME/w/gf/ruby-cur-main/Gemfile PATH=$HOME/w/ruby-cur/bin:$PATH "$@" taskset -c 1 $C --zjit $ST -rbundler/setup $M); }
lp() { env "$@" taskset -c 1 $C --zjit $ST $M; }
for s in early late fk; do
  f=lp; [ $s = fk ] && f=fk
  P=$([ $s = fk ] && echo 40 || echo 400)
  ST=--zjit-stats-quiet $f SHAPE=$s PAIRS=$P | sed 's/^{/{"run":"stats",/' >> $O
  for k in 1 2 3 4; do
    ST= $f SHAPE=$s PAIRS=$P | sed 's/^{/{"run":"timed",/' >> $O
    ST= $f SHAPE=$s PAIRS=$P AA=1 | sed 's/^{/{"run":"aa",/' >> $O
  done
  echo "$(date +%T) $s done"
done
echo MICRO-DONE
