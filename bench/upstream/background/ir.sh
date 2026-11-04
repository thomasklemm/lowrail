#!/bin/bash
# ir.sh RAILS CASE MODE (copy of census8/ir.sh for background/micro.rb): Callgrind Ir per call of micro.rb CASE, (Ir(N) - Ir(0)) / N.
# MODE: interp | yjit (RUBY409, default mise 4.0.9) | zjit (RUBYMASTER, a ZJIT build).
# Collection runs only inside Array#cycle, so boot and warmup are outside the count.
set -e
rails=$1; c=$2; mode=$3; n=${N:-5000}
here=$(cd "$(dirname "$0")" && pwd)
r409=${RUBY409:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}
case $mode in
  interp) bin=$r409; flag="" ;;
  yjit) bin=$r409; flag="--yjit" ;;
  zjit) bin=${RUBYMASTER:?set RUBYMASTER to a ZJIT build bin dir}; flag="--zjit" ;;
esac
smc=""; [ -n "$flag" ] && smc="--smc-check=all"
run() {
  RAILS=$rails PATH=$bin:$PATH ${VALGRIND:-valgrind} --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle \
    $smc --callgrind-out-file=/dev/null ruby $flag "$here/micro.rb" "$c" "$1" ir 2>&1 |
    grep -o 'Collected : [0-9]*' | tail -1 | grep -o '[0-9]*'
}
a=$(run 0); b=$(run "$n")
echo "$c $mode $(( (b - a) / n ))"
