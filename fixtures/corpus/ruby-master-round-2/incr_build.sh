#!/bin/bash
# incr_build.sh SRC_WORKTREE BUILD_DIR PREFIX
# Incremental out-of-tree build of a master variant from ~/w/build-master: copies generated source files and the
# build dir, ages every source file, then marks only files that differ from b7e8fad022 as new.
set -e
src=$1 build=$2 prefix=$3
cd ~/w/src-master && git ls-files --others --ignored --exclude-standard --directory | grep -v "^autom4te" > /tmp/ign.$$
tar cf - -T /tmp/ign.$$ | (cd $src && tar xpf -)
cd $src && changed=$( (git diff --name-only b7e8fad022; git diff --name-only) | sort -u)
find . -path ./.git -prune -o -type f -print0 | xargs -0 touch -h -d '2026-01-01'
[ -n "$changed" ] && touch $changed
echo "changed: $changed"
rm -rf $build && cp -a ~/w/build-master $build && cd $build
BR=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
srcrel=$(realpath --relative-to=$build $src)
$src/configure --prefix=$prefix --with-baseruby=$BR --enable-yjit --enable-zjit --disable-install-doc > configure.log 2>&1
make -j3 > make.log 2>&1 && make install > install.log 2>&1
mv $prefix/lib/ruby/gems/4.1.0+6 $prefix/lib/ruby/gems/4.1.0+6.orig && ln -s ~/w/rm/lib/ruby/gems/4.1.0+6 $prefix/lib/ruby/gems/4.1.0+6
echo BUILD-OK $(grep -c "^compiling" make.log) compiled
