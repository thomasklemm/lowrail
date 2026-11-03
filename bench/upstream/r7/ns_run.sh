#!/bin/bash
# ns_run.sh: interleaved wall time per call (ns), 7 rounds, main / A/A / candidate, one process per measurement.
out=/tmp/w/r7/ns.tsv; : > $out
W=/home/user/workspace/rails-wt
export BUNDLE_ONLY=default:test:rubocop:cable:db
cases="tag_div_class_array:r7-main:r7-tag-values-without-copies:i40,y40,z41
class_names_hash:r7-main:r7-tag-values-without-copies:i40,y40,z41
tag_div_aria_array:r7-main:r7-tag-values-without-copies:i40,y40,z41
hash_as_json:r7-main:r7-hash-as-json-symbol-names:i40,y40
to_json_except:r7-main:r7-hash-as-json-symbol-names:i40,y40
through_read:r7-main:r7-through-stale-state-without-array:i40,y40,z41
radio_button:r7-main2:r7-sanitized:i40,y40,z41"
for r in 1 2 3 4 5 6 7; do
  for line in $cases; do
    IFS=: read c base cand modes <<< "$line"
    for m in ${modes//,/ }; do
      case $m in
        i40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f="" ;;
        y40) P=/home/user/.local/share/mise/installs/ruby/4.0.7/bin; f="--yjit" ;;
        z41) P=/home/user/workspace/ruby-src/install-9aa/bin; f="--zjit" ;;
      esac
      order="main aa cand"; [ $((r % 2)) = 0 ] && order="cand aa main"
      for v in $order; do
        d=$base; [ $v = cand ] && d=$cand
        ns=$(cd $W/$d && PATH=$P:$PATH ruby $f /tmp/w/r7/cpu_r7.rb $c 20000 ns 2>/dev/null)
        echo -e "$r\t$c\t$m\t$v\t$ns" >> $out
      done
    done
  done
done
echo NSDONE
