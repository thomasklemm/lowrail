#!/usr/bin/env bash
set -eu
root=/home/user/workspace/repo
scratch=$root/.amp/in/orb-backup/rk3-astra
probe=$root/bench/upstream/rk3/review-astra/0046982320/adversarial.rb
for v in 2.7.3 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6 4.0.9; do
  bin=/opt/hostedtoolcache/Ruby/$v/x64/bin
  [ -x "$bin/ruby" ] || bin=$HOME/.local/share/mise/installs/ruby/$v/bin
  export PATH=$bin:/usr/bin:/bin
  ruby -v
  for tree in base rack; do
    ruby -W0 -I "$scratch/$tree/lib" "$probe" > "$scratch/results/$tree-$v-adversarial.jsonl" 2> "$scratch/results/$tree-$v-adversarial.err"
    for mode in clean util; do
      pre=(); [ "$mode" != util ] || pre=(-rcgi/util)
      ruby -W0 "${pre[@]}" -I "$scratch/$tree/lib" "$root/bench/upstream/rk3/module/replay.rb" "$root/bench/upstream/rk3/module/suite-inputs.rec" > "$scratch/results/$tree-$v-$mode-replay.txt" 2> "$scratch/results/$tree-$v-$mode-replay.err"
    done
  done
  for mode in clean util; do
    echo "$v $mode"
    ruby "$root/bench/upstream/rk3/module/compare.rb" "$scratch/results/base-$v-$mode-replay.txt" "$scratch/results/rack-$v-$mode-replay.txt"
  done
done
