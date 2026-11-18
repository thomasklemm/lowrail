#!/usr/bin/env bash
# bundle.sh NAME: install railsbench/lobsters/shipit gems into ~/rb/NAME
set -uo pipefail
export PATH=$HOME/rb/$1/bin:$PATH; unset RUBYOPT
for b in railsbench lobsters shipit; do
  cd ~/w/rb/benchmarks/$b && (bundle check >/dev/null 2>&1 || bundle install -j2 >/tmp/bundle-$1-$b.log 2>&1) && echo "$1 $b ok" || echo "$1 $b FAILED"
done
