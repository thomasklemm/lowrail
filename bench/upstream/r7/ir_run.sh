#!/bin/bash
# ir_run.sh: Callgrind Ir per call for every R7 case x variant x mode; writes /tmp/w/r7/ir/*.out
out=/tmp/w/r7/ir; mkdir -p $out
W=/home/user/workspace/rails-wt
jobs=/tmp/w/r7/ir-jobs.txt; : > $jobs
add() { # case base cand modes
  for m in $4; do for v in main:$2 aa:$2 cand:$3; do for n in 0 5000; do
    echo "$1 ${v%%:*} ${v#*:} $m $n" >> $jobs
  done; done; done
}
add tag_div_class_array r7-main r7-tag-values-without-copies "i40 y40 z41"
add class_names_hash r7-main r7-tag-values-without-copies "i40 y40 z41"
add tag_div_aria_array r7-main r7-tag-values-without-copies "i40 y40 z41"
add hash_as_json r7-main r7-hash-as-json-symbol-names "i40 y40"
add render_json_hash r7-main r7-hash-as-json-symbol-names "i40 y40"
add through_read r7-main r7-through-stale-state-without-array "i40 y40 z41"
add radio_button r7-main2 r7-sanitized "i40 y40 z41"
one() {
  c=$1 v=$2 d=$3 m=$4 n=$5
  case $m in
    i40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f="" ;;
    y40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f="--yjit" ;;
    z41) P=/home/user/workspace/ruby-src/install-9aa/bin; f="--zjit" ;;
  esac
  smc=""; [ -n "$f" ] && smc="--smc-check=all"
  cd $W/$d && BUNDLE_ONLY=default:test:rubocop:cable:db PATH=$P:$PATH /tmp/vg/bin/valgrind --tool=callgrind --collect-atstart=no \
    --toggle-collect=rb_ary_cycle $smc --callgrind-out-file=/dev/null ruby $f /tmp/w/r7/cpu_r7.rb $c $n ir \
    > $out/$c-$v-$m-$n.out 2>&1
}
export -f one; export W out
xargs -P 7 -L 1 bash -c 'one "$@"' _ < $jobs
echo IRDONE
