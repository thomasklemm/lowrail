#!/usr/bin/env bash
# run1.sh BENCH OUTDIR TAG [ruby flags...]: one callgrind-harness process like run_benchmarks.rb starts it
eval "$(mise env -s bash ruby@4.0.9)"; export BUNDLE_VERSION=system
b=$1 out=$2 tag=$3; shift 3
script=/home/user/work/ruby-bench/benchmarks/$b/benchmark.rb; [ -f $script ] || script=/home/user/work/ruby-bench/benchmarks/$b.rb
mkdir -p $out
cd /home/user/work/ruby-bench
/usr/bin/time -f "%e s %M KB" env HARNESS=callgrind WARMUP_ITRS=${WARMUP_ITRS:-3} MIN_BENCH_ITRS=${MIN_BENCH_ITRS:-1} $VG_ENV \
  setarch x86_64 -R ${VALGRIND:-valgrind} --tool=callgrind --instr-atstart=no --callgrind-out-file=$out/$tag.%p \
  $(command -v ruby) "$@" -r /home/user/work/ruby-bench/harness/callgrind $script > $out/$tag.log 2>&1
echo "$tag exit=$? $(tail -1 $out/$tag.log) brk=$(grep -c 'brk segment overflow' $out/$tag.log) totals=$(grep -h '^totals:' $out/$tag.*.1 | cut -d' ' -f2)"
