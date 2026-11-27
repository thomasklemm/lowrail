#!/usr/bin/env bash
# uri_suite.sh URI_DIR [RUBYOPT extra]: runs ruby/uri's suite in URI_DIR on every Ruby, one summary line each
dir=$1; extra=$2
export PATH=$(mise where java@temurin-21)/bin:$PATH
for v in 4.0.10 2.5.9 3.1.2 3.4.12 jruby-10.1.3.0 truffleruby-40.0.0 master; do
  if [ $v = master ]; then B=$HOME/rubies/master-0d399335b7/bin; else B=$(mise where ruby@$v)/bin; fi
  out=$(cd $dir && $B/ruby $extra -Ilib -Itest/lib -rhelper -e 'Dir["test/**/test_*.rb"].sort.each { |f| require "./#{f}" }' 2>&1)
  echo "$v: $(echo "$out" | grep -E '^[0-9]+ tests')"
  echo "$out" | grep -E '^(Failure|Error):' -A4 | head -30
done
