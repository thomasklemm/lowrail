#!/bin/bash
# ir2.sh <rev> <rep> <n> [query]
rev=$1; r=$2; n=$3; q=${4:-/tmp/rb/benchmarks/graphql-native/negotiate.gql}; tag=${5:-neg}
cd /tmp/gqb/env
export BUNDLE_PATH=/tmp/gqb/env/vendor RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=/home/user/.local/share/mise/installs/ruby/4.0.9/bin/ruby
mkdir -p /tmp/gqb/cg
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/tmp/gqb/cg/$tag.$rev.$r.$n.out $R /tmp/gqscripts/ir2.rb /tmp/gqb/$rev/graphql-c_parser/lib $q $n > /tmp/gqb/cg/$tag.$rev.$r.$n.log 2>&1
