#!/bin/bash
# nsround.sh CASE CANDWT ROUNDS [EXTRA]: pinned wall ns per call, rotated main/aa/CANDWT, interp and YJIT (Ruby 4.0.9)
c=$1; cand=$2; R=${3:-15}; export EXTRA=${4:-}
export PATH=$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH
wts=(main aa $cand)
for r in $(seq 1 $R); do
  for k in 0 1 2; do
    wt=${wts[$(( (r + k) % 3 ))]}
    for m in i y; do f=""; [ $m = y ] && f="--yjit"
      cd ~/w/wt/$wt; v=$(RAILS=$PWD BUNDLE_GEMFILE=$PWD/Gemfile.lowrail taskset -c 2 ruby $f ~/w/bench/micro_ap.rb $c ${N:-20000} ns)
      echo "$c $m $wt $v"
    done
  done
done
