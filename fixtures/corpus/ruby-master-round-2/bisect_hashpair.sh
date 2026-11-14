#!/bin/bash
# git bisect run helper: Ir per extra Hash pair, (x = {a: v, b: v, c: v}) - (x = {a: v}) per iteration, GC enabled,
# whole miniruby run. good (0) below CUT, bad (1) at or above. Usage: bisect_hashpair.sh CUT
CUT=${1:?}
src=$(pwd); b=$HOME/w/bisect-build
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
mkdir -p $b && cd $b
if [ ! -f Makefile ] || [ $src/configure.ac -nt Makefile ]; then
  (cd $src && ./autogen.sh >/dev/null 2>&1); $src/configure --with-baseruby=$BR --disable-install-doc --disable-yjit --disable-zjit >/dev/null 2>&1 || exit 125
fi
make -j4 miniruby >/dev/null 2>&1 || { make clean >/dev/null 2>&1; make -j4 miniruby >/dev/null 2>&1 || exit 125; }
ir() { valgrind --tool=callgrind --callgrind-out-file=/dev/null ./miniruby -e "def run(n, v); i = 0; x = nil; while i < n; x = $1; i += 1; end; x; end; run(200_000, 2)" 2>&1 | awk '/Collected/ {print $4}'; }
a=$(ir '{a: v, b: v, c: v}'); z=$(ir '{a: v}')
d=$(( (a - z) / 200000 ))
echo "$(git -C $src rev-parse --short HEAD) $d" >> $HOME/w/logs/bisect-hashpair.log
[ $d -lt $CUT ] && exit 0
exit 1
