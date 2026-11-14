#!/bin/bash
# stats_queue.sh OUT BENCH...  -- gap stats runs: ZJIT on the stats-iseq build (~/w/rs, gems from ~/w/rm), YJIT on ~/w/rm
root=/home/user/workspace/repo; out=$1; shift
gems=$(echo $HOME/w/rm/lib/ruby/gems/*)
for b in "$@"; do
  RUBY_PREFIX=$HOME/w/rs GEM_HOME=$gems GEM_PATH=$gems $root/bench/upstream/zjit_yjit_gap_run.sh stats $b zjit-$b $out --zjit --zjit-stats-iseq --zjit-exec-mem-size=512 --zjit-mem-size=1024; echo "$(date +%T) zjit $b $?"
  RUBY_PREFIX=$HOME/w/rm $root/bench/upstream/zjit_yjit_gap_run.sh stats $b yjit-$b $out --yjit --yjit-stats=quiet; echo "$(date +%T) yjit $b $?"
done
