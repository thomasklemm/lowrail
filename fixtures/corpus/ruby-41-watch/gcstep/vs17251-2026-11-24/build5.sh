#!/bin/bash
# build5.sh: on master dec1bb786f (the PR's base): master, + 41c689571a (old head), + 57eb4b4274 (new head),
# and master + gcstep-dec1bb786f.patch (control for the measurement patch); then master 760125a4c5 (current
# master, which the new head conflicts with). No gcstep patch except in "mg". One in-tree build; the dec1bb786f
# variants differ only in gc/default/default.c. Relocatable installs ~/w/r-{master,old,new,mg,m760}.
# Idempotent (runs as a supervised service; ends in sleep).
set -u
log=~/w/logs/build.log
src=~/w/src-master
fx=/home/user/workspace/repo/fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-24
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
cd $src
build() { # $1 = variant name; tree is prepared
  make -j2 > ~/w/logs/make-$1.log 2>&1; rc=$?
  echo "$(date +%T) make $1 rc=$rc" >> $log
  [ $rc = 0 ] || exec sleep infinity
  rm -rf ~/w/rprefix && make install > ~/w/logs/install-$1.log 2>&1 && mv ~/w/rprefix ~/w/r-$1
  echo "$(date +%T) install $1 rc=$? $(~/w/r-$1/bin/ruby -v)" >> $log
}
[ "$(git rev-parse HEAD)" = "$(git rev-parse dec1bb786f)" ] || [ -x ~/w/r-mg/bin/ruby ] || git checkout -q -f dec1bb786f
if [ ! -f Makefile ]; then
  ./autogen.sh >> $log 2>&1
  ./configure --prefix=$HOME/w/rprefix --enable-load-relative --with-baseruby=$BR --enable-yjit \
    --disable-install-doc > ~/w/logs/configure.log 2>&1
  echo "$(date +%T) configure rc=$?" >> $log
fi
for v in master old new mg; do
  [ -x ~/w/r-$v/bin/ruby ] && continue
  git show dec1bb786f:gc/default/default.c > /tmp/default.c
  case $v in
    old) patch -s /tmp/default.c < ~/w/old.diff ;;
    new) patch -s /tmp/default.c < ~/w/new.diff ;;
    mg) patch -s /tmp/default.c < $fx/gcstep-dec1bb786f.patch ;;
  esac
  cmp -s /tmp/default.c gc/default/default.c || cp /tmp/default.c gc/default/default.c
  build $v
done
if [ ! -x ~/w/r-m760/bin/ruby ]; then
  git checkout -q -f 760125a4c5
  build m760
fi
echo "$(date +%T) build done" >> $log
exec sleep infinity
