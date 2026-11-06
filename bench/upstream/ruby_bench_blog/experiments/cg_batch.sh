#!/usr/bin/env bash
# Callgrind batch: two audit.rb invocations at a time, two workers each.
R=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
AUD=/home/user/workspace/repo/bench/upstream/ruby_bench_round4/audit.rb
OUT=/tmp/x/cg
mkdir -p $OUT
run() { # variant src prefix reps benches... [extra args via EXTRA]
  local v=$1 src=$2 reps=$3; shift 3
  RUBY_BENCH_DIR=$src COPIES_DIR=/tmp/x/copies CG_EXT_DIR=/tmp/rb4/ext $R $AUD run --out $OUT --ruby $R --valgrind \
    --reps $reps --jobs 2 --warmup 2 --itrs 5 --variant $v --copies-prefix $v- $EXTRA "$@" >> $OUT/batch.log 2>&1
}
B="blog railsbench lobsters"
( run r81 /tmp/x/rb-r81 2 $B ) & ( run main /tmp/x/rb-main 2 $B ) & wait
( run pm1b /tmp/x/rb-pm1b 2 $B ) & ( run sqbase /tmp/x/rb-sqbase 2 $B ) & wait
( run sq769 /tmp/x/rb-sq769 2 $B ) & ( run sq770 /tmp/x/rb-sq770 2 $B ) & wait
( EXTRA="--rubyopt -r/tmp/x/slow.rb --env SLOW_N=400" run slow400 /tmp/x/rb-r81 2 blog ) &
( EXTRA="--rubyopt -r/tmp/x/slow.rb --env SLOW_N=2000" run slow2000 /tmp/x/rb-r81 1 $B ) & wait
echo BATCH_DONE >> $OUT/batch.log
