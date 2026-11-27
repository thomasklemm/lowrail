#!/usr/bin/env bash
# bstep.sh COMMIT : build miniruby (no JIT) at COMMIT and print Ir per cached ivar write
set -e
c=$1; W=$HOME/rdiff/src/bisect; B=$HOME/rdiff/bisect-build
cd $W; git checkout -q --detach $c
rm -rf $B; mkdir -p $B; cd $W; ./autogen.sh >/dev/null 2>&1
cd $B; $W/configure --disable-install-doc --disable-yjit --disable-zjit --with-baseruby=$HOME/.local/share/mise/installs/ruby/4.0.7/bin/ruby >/tmp/bconf.log 2>&1
make -j2 miniruby >/tmp/bmake.log 2>&1
V=$HOME/c8-valgrind/bin/valgrind; M=$HOME/workspace/repo/.amp/in/orb-backup/nhc/iv2.rb
ir() { $V --tool=callgrind --callgrind-out-file=/tmp/b.out $B/miniruby $M $1 $2 >/dev/null 2>&1; grep '^summary' /tmp/b.out | cut -d' ' -f2; }
n1=$(ir 2000 none); n2=$(ir 6000 none); s1=$(ir 2000 set1); s2=$(ir 6000 set1)
echo "$c $(git -C $W log -1 --format=%ad --date=short) none=$(( (n2-n1)/4000 )) set1=$(( (s2-s1)/4000 )) per_write=$(( ((s2-s1)-(n2-n1))/16000 ))"
