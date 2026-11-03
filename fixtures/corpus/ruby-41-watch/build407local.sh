#!/bin/bash
# Build Ruby 4.0.7 from source with the same compiler and configure flags as the master build.
set -e
cd /tmp/w/r407src
export PATH=$(mise where ruby@4.0.7)/bin:$PATH
./autogen.sh > /tmp/w/r407-autogen.log 2>&1
./configure --prefix=/home/user/.rubies/ruby-4.0.7-local --enable-yjit --disable-install-doc > /tmp/w/r407-configure.log 2>&1
make -j6 > /tmp/w/r407-make.log 2>&1
make install > /tmp/w/r407-install.log 2>&1
ln -sfn /home/user/.rubies/ruby-4.0.7-local /home/user/.local/share/mise/installs/ruby/4.0.7-local
echo BUILD-DONE
