#!/bin/bash
# cgv.sh LIBDIR TAG SCEN N : cachegrind of ver.rb against LIBDIR, output /tmp/cg/TAG.SCEN.N.out
lib=$1; tag=$2; s=$3; n=$4
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
R=$(mise exec ruby@4.0.9 -- which ruby)
cd /tmp
valgrind --tool=cachegrind --cache-sim=no --cachegrind-out-file=/tmp/cg/$tag.$s.$n.out $R -I$lib /tmp/gqscripts/ver.rb $s $n > /tmp/cg/$tag.$s.$n.log 2>&1
