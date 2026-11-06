#!/usr/bin/env bash
# Wall-time checks, run after the Callgrind batch so nothing else competes for CPU.
set -u
while pgrep -f "out_path=/tmp/x/wall/sens-railsbench" >/dev/null; do sleep 15; done
R409=$HOME/.local/share/mise/installs/ruby/4.0.9/bin
RM=$HOME/rubies/master/bin
export RUBY_GC_HEAP_0_INIT_SLOTS=1000000 RUBY_GC_HEAP_1_INIT_SLOTS=250000 RUBY_GC_HEAP_2_INIT_SLOTS=100000 RUBY_GC_HEAP_3_INIT_SLOTS=20000 RUBY_GC_HEAP_4_INIT_SLOTS=10000
W=/tmp/x/wall; mkdir -p $W
log() { echo "$(date +%T) $*" >> $W/wall.log; }

# 3: sensitivity, 1% and 2% (of blog) busy loop in save/save!/destroy vs the same wrapper with 0 iterations.
cd /tmp/x/rb-pv
for b in lobsters; do
  log "sens $b start"
  extra=(); [ $b = blog ] && extra=(-e "slow1::$R409/ruby -r/tmp/x/slow1125.rb")
  PATH=$R409:$PATH ./run_benchmarks.rb --no-sudo --turbo --runs=5 --pvalue --interleave \
    -e "ctl::$R409/ruby -r/tmp/x/slow0.rb" "${extra[@]}" -e "slow2::$R409/ruby -r/tmp/x/slow2250.rb" \
    --out_path=$W/sens-$b --name_filters=$b > $W/sens-$b.txt 2>&1
  log "sens $b exit $?"
done

# 1: Rails 8.1.4.1 vs main, wall, processes alternated by hand (different trees).
for i in 1 2 3; do
  for v in r81 main; do
    cd /tmp/x/rb-$v
    PATH=$R409:$PATH ./run_benchmarks.rb --no-sudo --turbo -e "$v::$R409/ruby" \
      --out_path=$W/rails-$v-$i --name_filters=blog,railsbench > $W/rails-$v-$i.txt 2>&1
    log "rails $v $i exit $?"
  done
done

# 4: Ruby 4.0.9 vs master, interpreter/YJIT/ZJIT, blog per request kind (3 processes each).
cd /tmp/x/rb-r81
for i in 1 2; do
  for c in "i409:$R409:" "y409:$R409:--yjit" "im:$RM:" "ym:$RM:--yjit" "zm:$RM:--zjit"; do
    IFS=: read n p o <<< "$c"
    PATH=$p:$PATH RUBY_BENCH_DIR=$PWD WARM=30 ITRS=20 OUT=$W/jit-$n-$i.json \
      $p/ruby $o -r/tmp/x/wall_per_request.rb benchmarks/blog/benchmark.rb > $W/jit-$n-$i.log 2>&1
    log "jit blog $n $i exit $?"
  done
done
# 4: whole-benchmark JIT ratios for railsbench and lobsters (and blog) on the same tree.
PATH=$RM:$PATH ./run_benchmarks.rb --no-sudo --turbo --runs=1 --interleave \
  -e "i409::$R409/ruby" -e "y409::$R409/ruby --yjit" -e "im::$RM/ruby" -e "ym::$RM/ruby --yjit" -e "zm::$RM/ruby --zjit" \
  --out_path=$W/jit-all --name_filters=railsbench,lobsters > $W/jit-all.txt 2>&1
log "jit all exit $?"
echo WALL_DONE >> $W/wall.log
