#!/bin/bash
# build.sh: ruby/ruby#17251 split into its parts, all on master f6278067b6 (the head's parent). One in-tree build,
# --enable-yjit --enable-zjit; the variants differ only in gc/default/default.c:
#   base  = f6278067b6
#   c1    = base + c1.diff   (git diff f6278067b6 b4cb7e52d8 -- gc/default/default.c, commit 1 only)
#   head  = base + head.diff (git diff f6278067b6 9715d0224e -- gc/default/default.c, both commits)
#   nocad = head with GC_HEAP_OLDOBJECT_RECLAIM_RATIO 2.0 instead of 0.1: a major's yield (at most 1) never reaches
#           it, so gc_oldgen_limit_update never enters the 1.25x oldgen cadence and the limit stays 2x. Everything else
#           in the head (per-heap deficits, the 1.25x-growth nofree trigger, min_free_slots) is unchanged.
#   base2 = byte-identical copy of the base install (A/A).
# Relocatable installs ~/w/r-NAME. Log ~/w/logs/build.log.
set -u
log=~/w/logs/build.log
src=~/w/src-master
fx=$(cd "$(dirname "$0")" && pwd)
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
J=${J:-16}
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
for v in base c1 head nocad; do
  [ -x ~/w/r-$v/bin/ruby ] && continue
  git show f6278067b6:gc/default/default.c > /tmp/default.c
  case $v in
    c1) patch -s /tmp/default.c < $fx/c1.diff ;;
    head) patch -s /tmp/default.c < $fx/head.diff ;;
    nocad) patch -s /tmp/default.c < $fx/head.diff
      sed -i 's/^#define GC_HEAP_OLDOBJECT_RECLAIM_RATIO 0.1$/#define GC_HEAP_OLDOBJECT_RECLAIM_RATIO 2.0/' /tmp/default.c
      grep -q '^#define GC_HEAP_OLDOBJECT_RECLAIM_RATIO 2.0$' /tmp/default.c || exit 1 ;;
  esac
  cp /tmp/default.c ~/w/logs/default-$v.c
  cmp -s /tmp/default.c gc/default/default.c || cp /tmp/default.c gc/default/default.c
  build $v
done
git checkout -q -f f6278067b6 -- gc/default/default.c
[ -x ~/w/r-base2/bin/ruby ] || cp -a ~/w/r-base ~/w/r-base2
echo "$(date +%T) build done" >> $log
