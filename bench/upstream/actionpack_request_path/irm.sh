#!/bin/bash
# irm.sh WT CASE MODE(i49|y49|i41|z41) -> Ir per call
wt=$1; c=$2; m=$3
case $m in
  i49) B=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="";;
  y49) B=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="--yjit";;
  i41) B=$HOME/w/ruby-master-inst/bin; f="";;
  z41) B=$HOME/w/ruby-master-inst/bin; f="--zjit";;
esac
RUBYBIN=$B ~/w/bench/irx.sh $wt $c $f | sed "s/\$/ $m/"
