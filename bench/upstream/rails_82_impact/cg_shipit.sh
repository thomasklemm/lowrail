#!/bin/bash
# Callgrind window of a ruby-bench benchmark under ruby-bench's harness/cgsample.rb
# (copy harness-cgsample.rb there). Trees in ~/src/wt/VARIANT, Gemfile.VARIANT as in
# docs/upstream/rails-82-impact.md; fixed heap; the census 8 sampling Valgrind
# (`script/cpu-census build --prefix ~/c8-valgrind`) and cpu_sampler.c built in ~/src/ext.
#   cg_shipit.sh BENCH VARIANT [ITERATIONS]           sampled Ruby methods (JSON)
#   CG_PLAIN=~/src/ext/lowrail_callgrind.so cg_shipit.sh ...   plain dump for C functions
b=$1; v=$2; n=${3:-2}
SFX=${CG_PLAIN:+-plain}
O=/home/user/workspace/repo/.lowrail/private/imp2/cg; mkdir -p $O
cd /home/user/src/ruby-bench
export PATH=$(mise where ruby@4.0.9)/bin:$PATH
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
export CG_PLAIN CG_PROFILE=/home/user/workspace/repo/bench/upstream/rails_82_impact/cg_profile.rb BUNDLE_GEMFILE=$PWD/benchmarks/$b/Gemfile.$v HARNESS=cgsample WARMUP_ITRS=2 BENCH_ITRS=$n CG_OUT=$O/$b-$v$SFX.json CG_RAILS=/home/user/src/wt/$v CENSUS_CPU_EXT=/home/user/src/ext/census_cpu_sampler.so
[ $b = railsbench ] && export DATABASE_URL=sqlite3:/tmp/cg-$b-$v.sqlite3
sh -c 'ulimit -d unlimited; exec "$@"' sh /home/user/c8-valgrind/bin/valgrind --tool=callgrind --instr-atstart=no --collect-atstart=yes --callgrind-out-file=$O/$b-$v$SFX.callgrind ruby benchmarks/$b/benchmark.rb > $O/$b-$v$SFX.log 2>&1
echo "EXIT $?" >> $O/$b-$v$SFX.log
