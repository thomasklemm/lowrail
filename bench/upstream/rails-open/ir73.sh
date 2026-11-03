#!/bin/bash
# Ir per call for R7-3 at its rebased head vs current main (open-main), with A/A.
W=/home/user/workspace/rails-wt
one() { c=through_read v=$1 m=$2 n=$3
  case $m in i40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f="";; y40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f=--yjit;; z41) P=/home/user/workspace/ruby-src/install-9aa/bin; f=--zjit;; esac
  d=open-main; [ $v = cand ] && d=r7-through-stale-state-without-array; smc=""; [ -n "$f" ] && smc=--smc-check=all
  cd $W/$d && BUNDLE_ONLY=default:test:rubocop:cable:db PATH=$P:$PATH /tmp/vg/bin/valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby $f bench/upstream/r7/cpu_r7.rb (copy to /tmp/w/r7) $c $n ir > /tmp/w/r7/ir73/$c-$v-$m-$n.out 2>&1; }
export -f one; export W
for m in i40 y40 z41; do for v in main aa cand; do for n in 0 5000; do echo "$v $m $n"; done; done; done | xargs -P 4 -L 1 bash -c 'one "$@"' _
