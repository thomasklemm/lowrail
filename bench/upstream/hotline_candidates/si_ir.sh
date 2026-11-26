#!/usr/bin/env bash
# si_ir.sh CASE N : Ir per call, base vs (...), interpreter; total Ir of N minus N=0, two runs each (A/A)
set -euo pipefail
export GEM_HOME=/home/user/work/gems GEM_PATH=/home/user/work/gems
ruby=$(mise where ruby@4.0.9)/bin/ruby
c=$1; n=$2
ir() { valgrind --tool=callgrind --callgrind-out-file=/dev/null "$ruby" --disable-yjit bench/upstream/hotline_candidates/si_micro.rb "$1" "$2" "$c" 2>&1 | awk '/Collected/ {print $4}'; }
for t in concurrent-ruby concurrent-ruby cr-fwd cr-fwd; do
  z=$(ir /home/user/work/$t 0); f=$(ir /home/user/work/$t $n)
  echo "$c $t $(( (f - z) / n ))"
done
