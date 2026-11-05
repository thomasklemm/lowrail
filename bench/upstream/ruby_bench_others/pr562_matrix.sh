cd /home/user/work/ruby-bench
M=$HOME/rubies/master-zjit/bin/ruby; F=$HOME/rubies/4.0.9-zjit/bin/ruby; N=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
run() { label=$1; shift; out=$(WARMUP_ITRS=2 MIN_BENCH_ITRS=3 MIN_BENCH_TIME=0 RESULT_JSON_PATH=/tmp/r562.json "$@" -r ./harness/gc benchmarks/gcbench.rb 2>&1); if echo "$out" | grep -q Error; then echo "$label: $(echo "$out" | grep -m1 -oE '[A-Za-z]+Error.*' | cut -c1-80)"; else echo "$label: ok $( "$N" -rjson -e 'd=JSON.load_file("/tmp/r562.json"); print d.slice("side_exit_count_warmup","side_exit_count_bench").inspect' )"; fi; }
for side in before after; do
  if [ $side = before ]; then git stash -q; else git stash pop -q; fi
  echo "### $side"
  run "4.0.9 no-ZJIT build interp" $N
  run "4.0.9 no-ZJIT build --yjit" $N --yjit
  run "4.0.9 interp" $F
  run "4.0.9 --yjit" $F --yjit
  run "4.0.9 --zjit" $F --zjit
  run "4.0.9 --zjit-stats-quiet" $F --zjit-stats-quiet
  run "master interp" $M
  run "master --yjit" $M --yjit
  run "master --zjit" $M --zjit
done
