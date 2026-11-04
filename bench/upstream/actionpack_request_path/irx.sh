#!/bin/bash
# irx.sh WT CASE [ruby flags]  -> Ir per call (N=3000 minus N=0), uses EXTRA env if set
wt=$1; c=$2; shift 2
export PATH=${RUBYBIN:-$HOME/.local/share/mise/installs/ruby/4.0.9/bin}:$PATH
cd ~/w/wt/$wt; export RAILS=$PWD BUNDLE_GEMFILE=${GEMFILE:-$PWD/Gemfile.lowrail}
N=${N:-3000}
smc=""; [ -n "$1" ] && smc="--smc-check=all"
a=$(valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby "$@" ~/w/bench/${MICRO:-micro_ap.rb} $c $N ir 2>&1 | sed -n 's/.*Collected : //p')
z=$(valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby "$@" ~/w/bench/${MICRO:-micro_ap.rb} $c 0 ir 2>&1 | sed -n 's/.*Collected : //p')
echo "$wt $c $* $(( (a - z) / N ))"
