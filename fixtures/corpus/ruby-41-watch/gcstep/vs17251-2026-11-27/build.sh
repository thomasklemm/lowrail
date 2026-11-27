#!/bin/bash
# build.sh: the rebased ruby/ruby#17251 against its base. On master f6278067b6 (the parent of head 9715d0224e):
# base, and base + head.diff (= git diff f6278067b6 9715d0224e -- gc/default/default.c; the head's other changes are
# NEWS, man page and a test). One in-tree build, --enable-yjit --enable-zjit; the two variants differ only in
# gc/default/default.c. Relocatable installs ~/w/r-{base,head}; ~/w/r-base2 is a copy of r-base (A/A).
# Same recipe as vs17251-2026-11-24/build5.sh. Log ~/w/logs/build.log.
set -u
log=~/w/logs/build.log
src=~/w/src-master
fx=/home/user/workspace/repo/fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
J=${J:-12}
cd $src
build() { # $1 = variant name; tree is prepared
  make -j$J > ~/w/logs/make-$1.log 2>&1; rc=$?
  echo "$(date +%T) make $1 rc=$rc" >> $log
  [ $rc = 0 ] || exit 1
  rm -rf ~/w/rprefix && make install > ~/w/logs/install-$1.log 2>&1 && mv ~/w/rprefix ~/w/r-$1
  echo "$(date +%T) install $1 rc=$? $(~/w/r-$1/bin/ruby -v)" >> $log
}
[ "$(git rev-parse HEAD)" = "$(git rev-parse f6278067b6)" ] || git checkout -q -f f6278067b6
if [ ! -f Makefile ]; then
  ./autogen.sh >> $log 2>&1
  ./configure --prefix=$HOME/w/rprefix --enable-load-relative --with-baseruby=$BR --enable-yjit --enable-zjit \
    --disable-install-doc > ~/w/logs/configure.log 2>&1
  echo "$(date +%T) configure rc=$?" >> $log
fi
for v in base head; do
  [ -x ~/w/r-$v/bin/ruby ] && continue
  git show f6278067b6:gc/default/default.c > /tmp/default.c
  [ $v = head ] && patch -s /tmp/default.c < $fx/head.diff
  cmp -s /tmp/default.c gc/default/default.c || cp /tmp/default.c gc/default/default.c
  build $v
done
[ -x ~/w/r-base2/bin/ruby ] || cp -a ~/w/r-base ~/w/r-base2
echo "$(date +%T) build done" >> $log
