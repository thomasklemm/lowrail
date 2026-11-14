#!/bin/bash
# git bisect run helper: Ir per h[:b] on a 3-pair symbol Hash, whole miniruby run (1M - 0 iterations), pinned Valgrind.
# good (0) below CUT, bad (1) at or above. Usage (in ~/w/bis): git bisect run bisect_hashlookup.sh CUT ; CUT=print just prints.
CUT=${1:?}
export PATH=$HOME/w/vg319brk/bin:$PATH
src=$(pwd); b=$HOME/w/bisect-build
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
mkdir -p $b && cd $b
if [ ! -f Makefile ] || [ $src/configure.ac -nt Makefile ]; then
  (cd $src && ./autogen.sh >/dev/null 2>&1); $src/configure --with-baseruby=$BR --disable-install-doc --disable-yjit --disable-zjit >/dev/null 2>&1 || exit 125
fi
nice make -j2 miniruby >/dev/null 2>&1 || { make clean >/dev/null 2>&1; nice make -j2 miniruby >/dev/null 2>&1 || exit 125; }
ir() { valgrind --tool=callgrind --callgrind-out-file=/dev/null ./miniruby -e "h = {a: 1, b: 2, c: 3}; def run(n, h); i = 0; x = nil; while i < n; x = h[:b]; i += 1; end; x; end; run($1, h)" 2>&1 | tee -a $HOME/w/logs/bisect-lookup-vg.log | awk '/Collected/ {print $4}'; }
a=$(ir 1000000); z=$(ir 0)
d=$(( (a - z) / 1000000 ))
echo "$(git -C $src rev-parse --short HEAD) $d" >> $HOME/w/logs/bisect-lookup.log
[ "$CUT" = print ] && exit 0
[ $d -lt $CUT ] && exit 0
exit 1
