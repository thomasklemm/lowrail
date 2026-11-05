#!/bin/bash
# run-ir.sh TAG RUBY(409|master) BENCHES VARIANT...   cachegrind Ir per ruby-bench iteration (interpreter, fixed heap)
tag=$1; r=$2; benches=$3; shift 3
cd /home/user/workspace/repo
if [ $r = master ]; then R=$HOME/ruby-master/bin/ruby; else R=$(mise where ruby@4.0.9)/bin/ruby; fi
export PATH=$(dirname $R):$PATH RUBY_BENCH_DIR=/home/user/src/ruby-bench
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
ruby bench/upstream/actionview_cpu/ruby_bench_ir.rb run --out .lowrail/private/perf/ir --valgrind /home/user/vg-brk512/bin/valgrind --ruby $R --jobs ${JOBS:-6} --tag $tag --benches $benches --modes ${MODES:-interpreter} --long ${LONG:-4} "$@"
