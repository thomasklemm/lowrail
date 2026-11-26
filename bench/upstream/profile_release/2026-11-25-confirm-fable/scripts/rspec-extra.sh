#!/usr/bin/env bash
# rspec-extra.sh APPDIR RUBY : must-fix 1 again with the installed gem (7a5ee0b6). The RSpec app's bundle
# (rswag-specs) loads rspec/core when the app boots: `rake spec`, a Minitest file, and --workloads.
set -uo pipefail
app=$1; . "$(dirname "$0")/../env.sh" "$2"; cd "$app"
bin/rails runner 'puts "a process that only boots the app has RSpec::Core::Runner: #{defined?(RSpec::Core::Runner).inspect}"' 2>/dev/null | tail -1
mkdir -p test lowrail
cat > test/mixed_test.rb <<'RUBY'
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"
class MixedTest < ActionDispatch::IntegrationTest
  %w[a b c d e f].each { |n| test("order #{n}") { get articles_url; assert_response :success } }
end
RUBY
printf 'get articles_path\n' > lowrail/workloads.rb
bundle exec lowrail-profile --out tmp/lp-x -- bundle exec rake spec > /tmp/pr2/x.log 2>&1
echo "rake spec: exit $?; $(grep -E 'Counted|no report' /tmp/pr2/x.log | cut -c1-110)"
bundle exec lowrail-profile --out tmp/lp-x -- ruby -Itest test/mixed_test.rb -v > /tmp/pr2/x.log 2>&1
echo "Minitest file: exit $?; seeds used: $(grep -o -- '--seed [0-9]*' /tmp/pr2/x.log | tr '\n' ' '); capture.json seed $(ruby -rjson -e 'print JSON.parse(File.read("tmp/lp-x/capture.json"))["seed"]')"
bundle exec lowrail-profile --out tmp/lp-x --workloads > /tmp/pr2/x.log 2>&1; s=$?
bundle exec lowrail-profile compare tmp/lp-x/report.json tmp/lp-x/report.json > /tmp/pr2/x-cmp.log 2>&1; c=$?
echo "--workloads: exit $s; measured $(ruby -rjson -e 'print JSON.parse(File.read("tmp/lp-x/report.json"))["meta"]["identity"]["measured"].map { _1 && _1["requests"] }.inspect'); compare exit $c; $(grep -E '^\* ' /tmp/pr2/x-cmp.log | head -1 | cut -c1-90)"
rm -rf test lowrail tmp/lp-x; git checkout -q swagger; git status --short
