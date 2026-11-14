#!/bin/bash
# stats.sh OUT TREE WIDTH|req yjit|zjit [CASE...]: one STATS=1 run (no Valgrind), JIT counters per call.
set -euo pipefail
out=$1; tree=$2; width=$3; mode=$4; shift 4
here=$(cd "$(dirname "$0")" && pwd)
case $mode in
  yjit) bin=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; suite=suite; gems=gems409; flags="--yjit --yjit-stats=quiet" ;;
  zjit) bin=$HOME/w/ruby-master/bin; suite=suiteM; gems=gemsM; flags="--zjit --zjit-stats-quiet" ;;
esac
script=attr_bench.rb; [ "$width" = req ] && script=req_bench.rb
mkdir -p "$out"
STATS=1 RAILS=$HOME/vb1/$tree BUNDLE_GEMFILE=$HOME/vb1/$suite-$tree/Gemfile BUNDLE_PATH=$HOME/vb1/$gems WIDTH=$width \
  PATH=$bin:$PATH ruby $flags "$here/$script" "$@" | sed "s/}\$/,\"tree\":\"$tree\",\"mode\":\"$mode\"}/" \
  > "$out/$tree-$mode-w$width.jsonl"
