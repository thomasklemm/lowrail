#!/bin/bash
# difrun.sh SCRIPT OUTDIR WT...  -> runs SCRIPT per worktree in i49 y49 i41 z41 (JIT threshold 1 too)
s=$1; o=$2; shift 2; mkdir -p $o
for wt in "$@"; do
 for m in i49 y49 y49t i41 z41 z41t; do
  case $m in
   i49) B=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="";;
   y49) B=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="--yjit";;
   y49t) B=$HOME/.local/share/mise/installs/ruby/4.0.9/bin; f="--yjit --yjit-call-threshold=1";;
   i41) B=$HOME/w/ruby-master-inst/bin; f="";;
   z41) B=$HOME/w/ruby-master-inst/bin; f="--zjit";;
   z41t) B=$HOME/w/ruby-master-inst/bin; f="--zjit --zjit-call-threshold=1";;
  esac
  (cd ~/w/wt/$wt && RAILS=$PWD BUNDLE_GEMFILE=$PWD/Gemfile.lowrail PATH=$B:$PATH ruby $f $s > $o/$wt-$m.txt 2>&1) &
 done
done
wait
