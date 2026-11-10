while [ $(wc -l < /home/user/workspace/m19659/out/reach.log) -lt 9 ]; do sleep 30; done
cd /home/user/workspace/ruby-bench
for b in railsbench lobsters; do for v in master pr19681 masterB; do echo "$b $v"; done; done | xargs -P3 -L1 bash -c '
  r=${1%B}; o=/home/user/workspace/m19681/out/cg-$0-$1
  BUNDLE_PATH=/home/user/workspace/bundle PATH=/home/user/workspace/b/$r/inst/bin:$PATH WARMUP_ITRS=0 MIN_BENCH_ITRS=3 MIN_BENCH_TIME=0 RESULT_JSON_PATH=$o.json DATABASE_URL=sqlite3:/tmp/cg-$0-$1.sqlite3 \
  valgrind --tool=callgrind --smc-check=all-non-file --callgrind-out-file=$o.cg /home/user/workspace/b/$r/inst/bin/ruby --zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024 benchmarks/$0/benchmark.rb > $o.log 2>&1
  echo "$0 $1 $?"'
echo done
