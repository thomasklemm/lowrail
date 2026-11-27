#!/bin/bash
# build.sh NAME : autogen, out-of-tree configure, make, install to ~/w/rubies/NAME
set -e
n=$1; src=~/w/$n; b=~/w/build-$n
cd $src && ./autogen.sh >/tmp/autogen-$n.log 2>&1
mkdir -p $b && cd $b
$src/configure --prefix=$HOME/w/rubies/$n --disable-install-doc --disable-yjit --disable-zjit --with-baseruby=$(mise where ruby@4.0.9)/bin/ruby > /tmp/configure-$n.log 2>&1
make -j6 > /tmp/make-$n.log 2>&1
make install > /tmp/install-$n.log 2>&1
echo "done $n"
