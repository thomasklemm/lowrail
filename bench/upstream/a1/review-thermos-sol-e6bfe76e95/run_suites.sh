#!/usr/bin/env bash
set -euo pipefail
root=$(git rev-parse --show-toplevel)
out="$root/bench/upstream/a1/review-thermos-sol-e6bfe76e95/raw"
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
cd "${1:?Rails head checkout required}/activerecord"
for adapter in sqlite3 postgresql; do
  result=0
  ARCONN=$adapter ruby -w -I../railties/lib -I../activesupport/lib -I../activemodel/lib -Ilib -Itest \
    -e 'ARGV.each { |f| require File.expand_path(f) }' \
    test/cases/associations/*_test.rb test/cases/associations_test.rb \
    test/cases/reflection_test.rb test/cases/relation_test.rb test/cases/relations_test.rb \
    test/cases/relation/*_test.rb test/cases/scoping/*_test.rb > "$out/tests-head-$adapter.txt" 2>&1 || result=$?
  echo "exit $result" >> "$out/tests-head-$adapter.txt"
  test "$result" -eq 0
done
