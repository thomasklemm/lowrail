#!/bin/bash
# R7-2 Ir per call on Ruby 4.0.9 (i49, y49) and master 9aa0898240 (z41): main, A/A (same checkout again), candidate.
out=/tmp/w/r7o/ir; mkdir -p $out
W=/home/user/workspace/rails-wt
jobs=/tmp/w/r7o/jobs.txt; : > $jobs
for c in hash_as_json to_json_except render_json_hash; do for m in i41; do
  for v in main:r7o-main aa:r7o-main cand:hash-as-json-symbol-names; do for n in 0 5000; do
    echo "$c ${v%%:*} ${v#*:} $m $n" >> $jobs; done; done; done; done
one() {
  c=$1 v=$2 d=$3 m=$4 n=$5
  case $m in
    i49) P=/home/user/.local/share/mise/installs/ruby/4.0.9/bin; f="" ;;
    y49) P=/home/user/.local/share/mise/installs/ruby/4.0.9/bin; f="--yjit" ;;
    i41) P=/home/user/.rubies/ruby-master-9aa0898240/bin; f="" ;;
    z41) P=/home/user/.rubies/ruby-master-9aa0898240/bin; f="--zjit" ;;
  esac
  smc=""; [ -n "$f" ] && smc="--smc-check=all"
  cd $W/$d && BUNDLE_ONLY=default:test:rubocop:cable:db PATH=$P:$PATH valgrind --tool=callgrind --collect-atstart=no \
    --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby $f /tmp/w/r7o/cpu_r7.rb $c $n ir \
    > $out/$c-$v-$m-$n.out 2>&1
}
export -f one; export W out
xargs -P 6 -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
