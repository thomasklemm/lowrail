#!/usr/bin/env bash
# t4-rspec-extra.sh APPDIR RUBY PRE_EXE FIX_EXE : in the RSpec app, whose bundle (rswag-specs) loads rspec/core when
# the app boots: `rake spec`, a Minitest file, and --workloads, with the built gem, the exe before dbe31072 (rake
# only) and the exe with smallest-fixes.patch.
set -uo pipefail
app=$1; . "$(dirname "$0")/env.sh" "$2"; pre=$3; fix=$4; cd "$app"
head=$(gem contents lowrail-profile | grep exe/lowrail-profile)
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
for name in pre head fix; do
  exe=${!name}
  bundle exec ruby "$exe" --out tmp/lp-x -- bundle exec rake spec > /tmp/pr/x.log 2>&1
  echo "$name: rake spec: exit $?; $(grep -E 'Counted|no report' /tmp/pr/x.log | cut -c1-110)"
  [ $name = pre ] && continue
  bundle exec ruby "$exe" --out tmp/lp-x -- ruby -Itest test/mixed_test.rb -v > /tmp/pr/x.log 2>&1
  echo "$name: Minitest file: exit $?; seeds used: $(grep -o -- '--seed [0-9]*' /tmp/pr/x.log | tr '\n' ' '); capture.json seed $(ruby -rjson -e 'print JSON.parse(File.read("tmp/lp-x/capture.json"))["seed"]')"
  bundle exec ruby "$exe" --out tmp/lp-x --workloads > /tmp/pr/x.log 2>&1; s=$?
  bundle exec ruby "$exe" compare tmp/lp-x/report.json tmp/lp-x/report.json > /tmp/pr/x-cmp.log 2>&1; c=$?
  echo "$name: --workloads: exit $s; measured $(ruby -rjson -e 'print JSON.parse(File.read("tmp/lp-x/report.json"))["meta"]["identity"]["measured"].map { _1 && _1["requests"] }.inspect'); compare exit $c; $(grep -E '^\* ' /tmp/pr/x-cmp.log | head -1 | cut -c1-90)"
done
rm -rf test lowrail tmp/lp-x; git checkout -q swagger; git status --short
