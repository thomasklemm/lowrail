#!/usr/bin/env bash
set -eu
root=/home/user/workspace/repo
scratch=$root/.amp/in/orb-backup/rk3-astra
here=$root/bench/upstream/rk3/review-astra/0046982320
for v in 2.7.3 3.0.7 3.1.7 3.2.9 3.3.9 3.4.6 4.0.9; do
  r=/opt/hostedtoolcache/Ruby/$v/x64/bin/ruby
  [ -x "$r" ] || r=$HOME/.local/share/mise/installs/ruby/$v/bin/ruby
  for tree in base rack; do
    for mode in error to_s ancestor super remove reflection reload encoding-fiber thread; do
      echo "--- $mode"
      "$r" -W0 -I "$scratch/$tree/lib" "$here/boundaries.rb" "$mode"
    done > "$scratch/results/$tree-$v-boundaries.txt"
  done
  "$r" -W0 -I "$scratch/rack/lib" -rrack/utils -e 'Rack::Utils.module_eval { alias_method :unescape, :unescape }; load ARGV.shift' "$here/boundaries.rb" ancestor > "$scratch/results/local-alias-$v.txt"
  case $v in
    3.4.6) pre=(-r "$root/bench/upstream/rk3/pure_cgi.rb") ;;
    4.0.9) pre=(-rrbconfig -e '$LOADED_FEATURES << File.join(RbConfig::CONFIG["archdir"], "cgi/escape.so"); load ARGV.shift') ;;
    *) continue ;;
  esac
  for tree in base rack; do
    "$r" -W0 "${pre[@]}" -I "$scratch/$tree/lib" "$root/bench/upstream/rk3/module/replay.rb" "$root/bench/upstream/rk3/module/suite-inputs.rec" > "$scratch/results/$tree-$v-pure-replay.txt" 2> "$scratch/results/$tree-$v-pure-replay.err"
  done
done
r=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
for tree in base rack; do
  "$r" -ryard -e 'YARD.parse(ARGV); o=YARD::Registry.at("Rack::Utils.unescape"); p version: YARD::VERSION, parameters: o.parameters, doc: o.docstring.to_s' "$scratch/$tree/lib/**/*.rb" > "$scratch/results/$tree-yard-full.txt" 2>&1
done
python3 "$here/summarize.py" "$scratch/results" > "$scratch/results/summary.txt"
