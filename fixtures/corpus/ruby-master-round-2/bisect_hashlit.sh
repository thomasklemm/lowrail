#!/bin/bash
# git bisect run helper: builds miniruby out of tree and prices `x = {a: v}` (Ir per literal, loop subtracted).
# good (0) below LO, bad (1) above HI, skip (125) between or on build failure. Usage: bisect_hashlit.sh [LO HI]
LO=${1:-360} HI=${2:-400}
src=$(pwd); b=$HOME/w/bisect-build
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
mkdir -p $b && cd $b
if [ ! -f Makefile ] || [ $src/configure.ac -nt Makefile ]; then
  (cd $src && ./autogen.sh >/dev/null 2>&1); $src/configure --with-baseruby=$BR --disable-install-doc --disable-yjit --disable-zjit >/dev/null 2>&1 || exit 125
fi
make -j4 miniruby >/dev/null 2>&1 || { make clean >/dev/null 2>&1; make -j4 miniruby >/dev/null 2>&1 || exit 125; }
ir() { valgrind --tool=callgrind --callgrind-out-file=/dev/null ./miniruby -e "def run(n, v); i = 0; x = nil; while i < n; x = $1; i += 1; end; x; end; GC.disable; run(200_000, 2)" 2>&1 | awk '/Collected/ {print $4}'; }
a=$(ir '{a: v}'); z=$(ir 'v')
d=$(( (a - z) / 200000 ))
echo "$(git -C $src rev-parse --short HEAD) $d" >> $HOME/w/logs/bisect-hashlit.log
[ $d -lt $LO ] && exit 0
[ $d -gt $HI ] && exit 1
exit 125
