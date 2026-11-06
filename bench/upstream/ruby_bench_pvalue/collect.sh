#!/usr/bin/env bash
# A/A collection on ruby-bench main: 10 identical executables per invocation, interleaved.
set -u
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
cd /home/user/workspace/repos/ruby-bench
out=/home/user/workspace/aa/data
for rep in 1 2; do
  for mode in yjit interp; do
    flag=""; [ $mode = yjit ] && flag=" --yjit"
    exes=()
    for i in $(seq -w 1 10); do exes+=(-e "${mode}${i}::ruby${flag}"); done
    ./run_benchmarks.rb --no-sudo --interleave --pvalue "${exes[@]}" \
      --out-name "$out/aa_${mode}_rep${rep}" railsbench lobsters fib str_concat respond_to \
      > "$out/aa_${mode}_rep${rep}.log" 2>&1
    echo "done $mode rep$rep $(date)" >> $out/progress
  done
done
echo ALLDONE >> $out/progress
