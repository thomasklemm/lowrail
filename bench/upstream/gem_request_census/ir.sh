#!/usr/bin/env bash
# ir.sh LIB_DIR SETUP_RB EXPR [N] [WARMUP]: Callgrind instructions per evaluation of EXPR with GC disabled,
# (Ir(N) - Ir(0)) / N after WARMUP calls (default 500). LIB_DIR goes first on the load path, SETUP_RB
# loads the gem and defines what EXPR uses. RUBY_BIN picks the Ruby, RUBYFLAGS adds --yjit or --zjit.
export PATH=${RUBY_BIN:-$HOME/.local/share/mise/installs/ruby/4.0.7/bin}:$PATH
lib=$1 setup=$2 expr=$3 n=${4:-5000} warm=${5:-500}
run() {
  valgrind --tool=callgrind --callgrind-out-file=/dev/null ruby $RUBYFLAGS -I"$lib" -e \
    "load '$setup'; f = -> { $expr }; $warm.times { f.() }; GC.start; GC.disable; $1.times { f.() }" 2>&1 |
    grep -o 'Collected : [0-9]*' | grep -o '[0-9]*'
}
a=$(run 0); b=$(run "$n")
echo $(( (b - a) / n ))
