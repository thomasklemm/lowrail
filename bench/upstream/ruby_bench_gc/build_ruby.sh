#!/usr/bin/env bash
# usage: build_ruby.sh <rev> <name>
set -euxo pipefail
rev=$1; name=$2
export PATH="$HOME/.cargo/bin:$(~/.local/bin/mise where ruby@4.0.9)/bin:$PATH"
src=~/w/src-$name
rm -rf "$src"; git -C ~/w/ruby worktree add -f "$src" "$rev"
cd "$src"; ./autogen.sh
mkdir -p build && cd build
../configure --prefix=$HOME/rubies/$name --enable-yjit --enable-zjit --disable-install-doc optflags=-O3 debugflags=-ggdb3 >/dev/null
make -j2 >/dev/null 2>&1 || make -j1
make install >/dev/null
$HOME/rubies/$name/bin/ruby -v
echo DONE $name
