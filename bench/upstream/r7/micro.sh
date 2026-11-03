#!/bin/bash
# micro.sh -> /tmp/w/r7/micro.tsv
out=/tmp/w/r7/micro.tsv; : > $out
export BUNDLE_ONLY=default:test:rubocop:cable:db
for rb in 40 9aa; do
  if [ $rb = 40 ]; then P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; modes="interp yjit"; else P=/home/user/workspace/ruby-src/install-9aa/bin; modes="interp zjit"; fi
  for m in $modes; do
    flag=""; [ $m = yjit ] && flag=--yjit; [ $m = zjit ] && flag=--zjit
    for l in main main-aa r7-tag-values-without-copies r7-hash-as-json-symbol-names r7-through-stale-state-without-array r7-currency; do
      d=$l; [ $l = main-aa ] && d=r7-main; [ $l = main ] && d=r7-main
      (cd /home/user/workspace/rails-wt/$d && LABEL=$l PATH=$P:$PATH bundle exec ruby $flag /tmp/w/r7/micro_r7.rb >> $out 2>>/tmp/w/r7/micro.err)
    done
  done
done
echo done >> /tmp/w/r7/micro.err
