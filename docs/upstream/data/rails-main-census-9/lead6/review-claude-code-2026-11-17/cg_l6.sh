#!/bin/bash
# cg_l6.sh: census 9 attr_micro.rb under patched Callgrind 3.19 (fixed heap), 30 columns, core 0, for L6's body rows.
here=/home/user/workspace/repo/bench/upstream/census9
R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
vg=$HOME/c8-valgrind/bin/valgrind
export GEM_PATH=$HOME/ips/gems/ruby/4.0.0 IR_COUNT_SO=$HOME/ips/ir_count.so WIDTH=30
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 \
  RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
out=${OUT:-/tmp/cg_l6}; mkdir -p $out
for mode in ${MODES:-interp yjit}; do
  for t in ${TREES:-main l6 main2 l6a}; do
    flag=; smc=; cases="update1 load1_changed? serializable_hash_warm"
    [ $mode = yjit ] && flag=--yjit && smc=--smc-check=all-non-file && cases=${CASES-"load1_changed? update1 serializable_hash_warm"}
    RAILS=$HOME/ips/$t taskset -c 0 $vg --tool=callgrind --instr-atstart=no --callgrind-out-file=/dev/null $smc \
      $R $flag $here/attr_micro.rb $cases > $out/$t-$mode.txt 2> $out/$t-$mode.log
    echo "$t $mode $(date -u +%T)" >> $out/progress
  done
done
echo done >> $out/progress
