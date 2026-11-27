#!/usr/bin/env bash
# run.sh URI_DIR OUT: the differential matrix for both changed methods; one log per Ruby x method x harness.
uri=$1; out=$2; here=$(cd "$(dirname "$0")/../.." && pwd)
export PATH=$(mise where java@temurin-21)/bin:$PATH
rb() { [ "$1" = master ] && echo $HOME/rubies/master-0d399335b7/bin/ruby || echo $(mise where ruby@$1)/bin/ruby; }
for m in decode_www_form_component decode_uri_component; do
  for v in 4.0.10 master 3.4.12 jruby-10.1.3.0 truffleruby-40.0.0; do
    METHOD=$m SINGLETON_B=1 $(rb $v) -I $uri/lib $here/diff.rb > $out/diff-$m-$v.log 2>&1 &
  done
  METHOD=$m SINGLETON_B=1 $(rb 4.0.10) -r $here/pure_cgi.rb -I $uri/lib $here/diff.rb > $out/diff-$m-4.0.10-pure_cgi.log 2>&1 &
  wait
  for v in 2.5.9 3.1.2 4.0.10 master jruby-10.1.3.0 truffleruby-40.0.0; do
    METHOD=$m $(rb $v) -I $uri/lib $here/probe.rb > $out/probe-$m-$v.log 2>&1 &
  done
  METHOD=$m $(rb 4.0.10) -r $here/pure_cgi.rb -I $uri/lib $here/probe.rb > $out/probe-$m-4.0.10-pure_cgi.log 2>&1 &
  METHOD=$m $(rb 3.4.12) -r $here/pure_cgi.rb -I $uri/lib $here/probe.rb > $out/probe-$m-3.4.12-pure_cgi.log 2>&1 &
  wait
done
