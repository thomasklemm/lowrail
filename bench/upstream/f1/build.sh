#!/bin/bash
# build.sh SRC PREFIX [configure flags...]: configure, make, install one Ruby tree
set -e
src=$1; prefix=$2; shift 2
cd "$src"
[ -f Makefile ] || ./configure --prefix="$prefix" --disable-install-doc --with-baseruby=/home/user/.local/share/mise/installs/ruby/4.0.7/bin/ruby "$@" > configure.log 2>&1
make -j"${JOBS:-2}" > make.log 2>&1
make install > install.log 2>&1
echo built
