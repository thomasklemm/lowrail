#!/usr/bin/env bash
# suite.sh RUBY GEMDIR LOG [minitest args...] : the profile suite as ci.yml's "Profile tests" step runs it at 7a5ee0b6.
set -uo pipefail
ruby=$1 gemdir=$2 log=$3; shift 3
export PATH="$(mise where ruby@$ruby)/bin:$PATH"
cd "$gemdir"
ruby -Ilib -Itest -e 'ARGV.select { _1.end_with?(".rb") }.each { require File.expand_path("test/#{_1}") }; ARGV.reject! { _1.end_with?(".rb") }' -- \
  profile_test.rb profile_report_test.rb profile_env_test.rb profile_compare_test.rb profile_package_test.rb workloads_test.rb load_hooks_test.rb --verbose --seed=1729 "$@" > "$log" 2>&1
echo "exit $?" >> "$log"
