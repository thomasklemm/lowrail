#!/bin/bash
# ir3.sh <libtag> <rep> <n>
t=$1; r=$2; n=$3
cd /tmp/gqb/env
export BUNDLE_PATH=/tmp/gqb/env/vendor RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/tmp/gqb/cg/rb.$t.$r.$n.out $R /tmp/gqscripts/ir3.rb /tmp/gqb/$t/lib $n > /tmp/gqb/cg/rb.$t.$r.$n.log 2>&1
