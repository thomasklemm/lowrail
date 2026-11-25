#!/bin/bash
# After queue.sh: build old and new head + gcstep-dec1bb786f.patch (og, ng) on dec1bb786f, then bigslot 9 runs each,
# alternating master mg old og new ng. Explains whether the gcstep patch moved the first pass's bigslot numbers.
set -u
log=~/w/logs/bg.log
src=~/w/src-master
fx=/home/user/workspace/repo/fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-24
until grep -q "queue done" ~/w/logs/q.log; do sleep 30; done
cd $src
git checkout -q -f dec1bb786f
for v in og ng; do
  [ -x ~/w/r-$v/bin/ruby ] && continue
  git show dec1bb786f:gc/default/default.c > /tmp/default.c
  [ $v = og ] && patch -s /tmp/default.c < ~/w/old.diff
  [ $v = ng ] && patch -s /tmp/default.c < ~/w/new.diff
  patch -s /tmp/default.c < $fx/gcstep-dec1bb786f.patch || { echo "$(date +%T) patch $v failed" >> $log; exec sleep infinity; }
  cp /tmp/default.c gc/default/default.c
  make -j2 > ~/w/logs/make-$v.log 2>&1 || { echo "$(date +%T) make $v failed" >> $log; exec sleep infinity; }
  rm -rf ~/w/rprefix && make install > ~/w/logs/install-$v.log 2>&1 && mv ~/w/rprefix ~/w/r-$v
  echo "$(date +%T) built $v $(~/w/r-$v/bin/ruby -e 'print GC.respond_to?(:__step_log)')" >> $log
done
mkdir -p ~/w/bigslot2
for i in 1 2 3 4 5 6 7 8 9; do
  for v in master mg old og new ng; do
    f=~/w/bigslot2/$v-$i.txt; [ -s $f ] && continue
    RING=200 BIG=70 N=40000 ~/w/r-$v/bin/ruby /home/user/workspace/repo/fixtures/corpus/ruby-master-round-2/bigslot.rb > $f 2>&1
  done
done
echo "$(date +%T) bigslot2 done" >> $log
exec sleep infinity
