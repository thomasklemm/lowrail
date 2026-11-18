#!/usr/bin/env bash
# build.sh SRC NAME: out-of-tree release ZJIT build of the checkout SRC into ~/rb/NAME (baseruby: mise ruby 4.0.9).
set -euo pipefail
src=$1 name=$2
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$HOME/.cargo/bin:$PATH"
cd "$src"; [ -x configure ] || ./autogen.sh
b=$HOME/build/$name; rm -rf "$b"; mkdir -p "$b"; cd "$b"
"$src/configure" --prefix="$HOME/rb/$name" --enable-zjit --disable-install-doc --without-jemalloc > configure.log 2>&1
make -j2 > make.log 2>&1
make install > install.log 2>&1
"$HOME/rb/$name/bin/ruby" -v
