#!/bin/bash
# usage: ir.sh variant rep n
v=$1; r=$2; n=$3
cd /tmp/gqv/$v
export BUNDLE_PATH=/tmp/gqv/$v/vendor RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=$(mise which ruby -C /tmp 2>/dev/null || mise exec ruby@4.0.9 -- which ruby)
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/tmp/gqv/cg.$v.$r.$n.out $R /tmp/gqscripts/ir.rb /tmp/rb/benchmarks/graphql-native/negotiate.gql $n > /tmp/gqv/cg.$v.$r.$n.log 2>&1
