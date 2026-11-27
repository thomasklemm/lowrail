set -e
export PATH=$(mise where ruby@4.0.10)/bin:$HOME/.cargo/bin:$PATH
cd ~/w/ruby-src
./autogen.sh
mkdir -p build && cd build
../configure --prefix=$HOME/rubies/master-42a644f6e0 --enable-zjit --enable-yjit --disable-install-doc --with-baseruby=$(which ruby) optflags=-O3
make -j2
make install
