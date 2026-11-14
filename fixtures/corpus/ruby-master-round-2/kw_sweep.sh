#!/bin/bash
# kw_sweep.sh LABEL RUBY_PREFIX CGEXT [ruby flags]
set -e
label=$1 prefix=$2 cgext=$3; shift 3
out=$HOME/w/kw/$label; rm -rf $out; mkdir -p $out
valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=$out/cg.%p $prefix/bin/ruby -I $cgext "$@" /home/user/workspace/repo/.amp/in/orb-backup/kw_sweep.rb $out/cases.json > $out/log 2>&1
echo done $label
