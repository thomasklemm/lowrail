#!/usr/bin/env bash
# After-fix runs on the branch worktree; waits for the main A/A collection to finish.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
out=/home/user/workspace/aa/data
until grep -q ALLDONE $out/progress 2>/dev/null; do sleep 15; done
cd /home/user/workspace/repos/ruby-bench-dev
# A/B: deliberate 2% and 5% slowdowns and the interpreter, against YJIT, 5 processes each
start=$(date +%s)
./run_benchmarks.rb --no-sudo --runs 5 --pvalue -e 'base::ruby --yjit' \
  -e "slow2::env SLOW_PCT=2 ruby --yjit -r/home/user/workspace/aa/slow.rb" \
  -e "slow5::env SLOW_PCT=5 ruby --yjit -r/home/user/workspace/aa/slow.rb" -e 'interp::ruby' \
  --out-name $out/ab_runs5 railsbench fib str_concat > $out/ab_runs5.log 2>&1
echo "done ab_runs5 $(( $(date +%s) - start ))s" >> $out/progress
# A/A end to end: 4 identical YJIT executables, 5 processes each
start=$(date +%s)
./run_benchmarks.rb --no-sudo --runs 5 --pvalue -e 'A::ruby --yjit' -e 'B::ruby --yjit' -e 'C::ruby --yjit' -e 'D::ruby --yjit' \
  --out-name $out/aa_branch_runs5 railsbench lobsters fib str_concat respond_to > $out/aa_branch_runs5.log 2>&1
echo "done aa_branch_runs5 $(( $(date +%s) - start ))s" >> $out/progress
echo ALLDONE2 >> $out/progress
