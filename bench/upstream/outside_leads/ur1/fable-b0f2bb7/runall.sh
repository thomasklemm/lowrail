#!/bin/bash
# runall.sh OUT: suite, differential and warnings for the head and each variant on the Rubies this orb has.
out=$1; mkdir -p $out; here=$(cd "$(dirname "$0")" && pwd); ur1=/home/user/workspace/repo/bench/upstream/outside_leads/ur1
MRI=$HOME/.local/share/mise/installs/ruby/4.0.9/bin/ruby
TR=/tmp/rt/truffleruby-community-40.0.0-linux-amd64/bin/ruby
suite() { # name ruby dir [opts]
  n=$1; rb=$2; d=$3; shift 3
  (cd $here/$d && $rb "$@" -W:no-experimental -Ilib -Itest/lib -rhelper -e 'Dir["test/**/test_*.rb"].sort.each {|f| require "./#{f}" }' > $out/suite-$d-$n.log 2>&1)
  echo "suite $d | $n | $(grep -aE '^[0-9]+ tests' $out/suite-$d-$n.log) | $(grep -aoE 'test_common\.rb:[0-9]+:in .*test_decode_\w+' $out/suite-$d-$n.log | sort -u | tr '\n' ' ')"
}
diffs() { # name ruby dir [opts]
  n=$1; rb=$2; d=$3; shift 3
  for m in decode_www_form_component decode_uri_component; do
    METHOD=$m SINGLETON_B=1 $rb "$@" -I $here/$d/lib $ur1/diff.rb > $out/diff-$d-$n-$m.log 2>&1
    METHOD=$m $rb "$@" -I $here/$d/lib $ur1/probe.rb > $out/probe-$d-$n-$m.log 2>&1
    echo "diff $d | $n | $m | diff.rb: $(tail -n 1 $out/diff-$d-$n-$m.log) | probe.rb: $(tail -n 1 $out/probe-$d-$n-$m.log)"
  done
}
for d in "${@:2}"; do
  (
  suite 4.0.9 $MRI $d
  suite 4.0.9-no_c_decoder $MRI $d -r$ur1/rework/tests/no_c_decoder.rb
  suite 4.0.9-ruby_decoder $MRI $d -r$ur1/rework/tests/ruby_decoder.rb
  suite 4.0.9-pure_cgi $MRI $d -r$ur1/pure_cgi.rb
  suite truffleruby-40.0.0 $TR $d
  diffs 4.0.9 $MRI $d
  diffs 4.0.9-pure_cgi $MRI $d -r$ur1/pure_cgi.rb
  diffs truffleruby-40.0.0 $TR $d
  echo "warnings $d | $($MRI -w -I $here/$d/lib -e 'require "uri"; p URI.decode_www_form_component("a%41+b"), URI.decode_uri_component("a%41+b")' 2>&1 | tr '\n' ' ')"
  ) > $out/summary-$d.txt 2>&1 &
done
wait
cat $out/summary-*.txt
