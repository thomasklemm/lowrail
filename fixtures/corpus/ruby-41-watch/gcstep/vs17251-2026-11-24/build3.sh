#!/bin/bash
# build3.sh: master dec1bb786f, + 41c689571a (old head, rebased), + 57eb4b4274 (new head), each with the
# measurement-only gcstep patch ported to dec1bb786f. One in-tree build; variants differ only in
# gc/default/default.c, so each variant rebuild recompiles that file. Relocatable installs ~/w/r-{master,old,new}.
# Idempotent (runs as a supervised service; ends in sleep).
set -u
log=~/w/logs/build3.log
src=~/w/src-master
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
cd $src
if [ ! -f Makefile ]; then
  ./autogen.sh >> $log 2>&1
  ./configure --prefix=$HOME/w/rprefix --enable-load-relative --with-baseruby=$BR --enable-yjit \
    --disable-install-doc > ~/w/logs/configure.log 2>&1
  echo "$(date +%T) configure rc=$?" >> $log
fi
for v in master old new; do
  [ -x ~/w/r-$v/bin/ruby ] && continue
  git show dec1bb786f:gc/default/default.c > /tmp/default.c
  [ $v = master ] || patch -s /tmp/default.c < ~/w/$v.diff
  patch -s /tmp/default.c < ~/w/gcstep-dec1bb786f.patch
  cmp -s /tmp/default.c gc/default/default.c || cp /tmp/default.c gc/default/default.c
  make -j2 > ~/w/logs/make-$v.log 2>&1; rc=$?
  echo "$(date +%T) make $v rc=$rc" >> $log
  [ $rc = 0 ] || exec sleep infinity
  rm -rf ~/w/rprefix && make install > ~/w/logs/install-$v.log 2>&1 && mv ~/w/rprefix ~/w/r-$v
  echo "$(date +%T) install $v rc=$? $(~/w/r-$v/bin/ruby -v)" >> $log
done
echo "$(date +%T) build3 done" >> $log
exec sleep infinity
