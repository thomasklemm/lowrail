#!/bin/bash
# hash_ir.sh PREFIX CGEXT OUTDIR SEED [ruby flags]: hash_ir.rb under the pinned Callgrind with a fixed heap,
# a fixed hash salt (fixseed.so, F1_SEED) and no ASLR, so every run with the same SEED sees the same hints
export PATH=$HOME/w/valgrind-brk512/bin:$PATH LD_PRELOAD=$HOME/w/shim/fixseed.so
pre=$1 ext=$2 out=$3; export F1_SEED=$4; shift 4
mkdir -p $out; rm -f $out/cg.*
if $pre/bin/ruby -e 'exit RUBY_VERSION >= "4.1"'; then
  export RUBY_GC_HEAP_INIT_BYTES=33554432
else
  export RUBY_GC_HEAP_0_INIT_SLOTS=838860 RUBY_GC_HEAP_1_INIT_SLOTS=419430 RUBY_GC_HEAP_2_INIT_SLOTS=209715 RUBY_GC_HEAP_3_INIT_SLOTS=104857 RUBY_GC_HEAP_4_INIT_SLOTS=52428
fi
setarch -R valgrind --tool=callgrind --instr-atstart=no --smc-check=all-non-file --callgrind-out-file=$out/cg.%p --trace-children=no $pre/bin/ruby -I $ext "$@" \
  /home/user/workspace/repo/bench/upstream/f1/hash_ir.rb $out/cases.json > $out/log 2>&1
rc=$?
grep -q "brk segment overflow" $out/log && echo "BRK OVERFLOW $out"
echo "rc=$rc $out"
