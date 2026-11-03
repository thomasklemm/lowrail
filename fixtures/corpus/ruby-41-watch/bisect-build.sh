#!/bin/bash
# bisect-build.sh TEST.rb : build miniruby in /tmp/w/bis at HEAD and run TEST; 125 = skip
cd /tmp/w/bis
export PATH=$(mise where ruby@4.0.7)/bin:$PATH
git clean -fdxq -e .bisect-keep >/dev/null 2>&1
(./autogen.sh && ./configure -q --disable-install-doc --disable-yjit --disable-zjit && make -j8 miniruby) > /tmp/w/bisect-build.log 2>&1 || exit 125
./miniruby "$1"; rc=$?; echo "rc=$rc"; exit $rc
