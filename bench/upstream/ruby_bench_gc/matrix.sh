#!/usr/bin/env bash
# usage: matrix.sh OUTDIR ROUNDS [BENCHES] [MODES]
# Two workers pinned to separate physical cores (cpu1, cpu3) pull jobs from one queue;
# the variant order rotates each round. EXTRA_ENV adds environment (e.g. GC_PROFILE=0).
set -u
out=$1; rounds=$2; benches=${3:-"railsbench lobsters shipit"}; modes=${4:-"interp yjit zjit"}
extra_env=${EXTRA_ENV:-}
mkdir -p "$out"
H=$HOME/workspace/repo/bench/upstream/ruby_bench_gc/harness_gcsplit.rb
q=$out/queue; : > $q; echo 0 > $out/next
orders=("base-a patch base-b" "patch base-b base-a" "base-b base-a patch")
for r in $(seq 1 $rounds); do
  for b in $benches; do for m in $modes; do
    for v in ${orders[$(( (r-1) % 3 ))]}; do echo "$r $b $m $v" >> $q; done
  done; done
done
total=$(wc -l < $q)
worker() {
  local slot=$1 cpu=$2
  while :; do
    n=$(flock $out/next sh -c 'n=$(cat '$out'/next); echo $((n+1)) > '$out'/next; echo $n')
    [ "$n" -ge "$total" ] && break
    set -- $(sed -n "$((n+1))p" $q); r=$1 b=$2 m=$3 v=$4
    bin=$HOME/rubies/${v%%-*}/bin/ruby
    case $m in interp) f="";; yjit) f="--yjit";; zjit) f="--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024";; esac
    o=$out/$b.$m.$v.r$r.json
    ( cd $HOME/w/rb-slot$slot/benchmarks/$b && env GC_PROFILE=1 $extra_env RUBY_BENCH_DIR=$HOME/w/rb-slot$slot GCSPLIT_OUT=$o \
      WARMUP_ITRS=15 MIN_BENCH_ITRS=10 GC_PROBE_N=10 setarch -R taskset -c $cpu $bin $f -r$H benchmark.rb > $out/$b.$m.$v.r$r.log 2>&1 )
    echo "$(date +%T) cpu$cpu $r $b $m $v exit=$?"
  done
}
worker 1 1 & worker 2 3 & wait
echo MATRIX_DONE
sleep infinity
