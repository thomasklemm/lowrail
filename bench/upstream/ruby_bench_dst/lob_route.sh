#!/bin/bash
# lob.sh DATE FIXNAME [extra env...]  (FIXNAME: none, s81, s81fix; DATE: real or YYYY-MM-DD)
d=$1 fx=$2; shift 2
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH RUBY_BENCH_DIR=${RUBY_BENCH_DIR:-$HOME/src/ruby-bench}
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
ft=(); [ "$d" != real ] && ft=(LD_PRELOAD=/usr/lib/x86_64-linux-gnu/faketime/libfaketime.so.1 FAKETIME_DONT_FAKE_MONOTONIC=1 "FAKETIME=@$d 12:00:00")
fix=(); [ "$fx" != none ] && fix=(FIX=$HOME/w/bench/as_$fx.rb)
cd $RUBY_BENCH_DIR && env "${ft[@]}" "${fix[@]}" "$@" ${CG:+setarch -R valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle --callgrind-out-file=/dev/null} \
  ruby -r $HOME/w/bench/dst_route_harness.rb benchmarks/lobsters/benchmark.rb 2>&1 | grep -E "^DST|Collected|rror" 
