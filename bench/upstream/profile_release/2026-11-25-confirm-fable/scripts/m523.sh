#!/usr/bin/env bash
# m523.sh : Minitest 5.23.1 (no register_plugin: Lowrail::Profile::Suite is prepended to Minitest's singleton
# class) on Ruby 3.3.14 / Rails 7.2.4, since 5.23 does not install on Ruby 4.0. A copy of the RSpec app with one
# Minitest file whose test starts a child: the seed of both runs and what the child sees, plain and profiled.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd); . "$here/../env.sh" 3.3.14
gem install minitest -v 5.23.1 --no-document 2>&1 | tail -1
rm -rf /tmp/pr2/m523; cp -a /tmp/pr/a72/rspec /tmp/pr2/m523; cd /tmp/pr2/m523; rm -rf tmp/lp-* spec
printf '\ngem "minitest", "5.23.1"\n' >> Gemfile
bundle update minitest --local > /tmp/pr2/m523-bundle.log 2>&1; echo "bundle update minitest: exit $?"
mkdir -p test
cat > test/mixed_test.rb <<'RUBY'
ENV["RAILS_ENV"] = "test"
require_relative "../config/environment"
require "rails/test_help"
class MixedTest < ActionDispatch::IntegrationTest
  %w[a b c d e f].each { |n| test("order #{n}") { get articles_url; assert_response :success } }
  test "child" do
    get articles_url
    probe = 'puts ENV.select { |k, _| k =~ /\A(SEED|SPEC_OPTS|RUBYOPT|RUBYLIB|LOWRAIL_|BUNDLER_ORIG_RUBY)/ }.sort.map { |k, v| "#{k}=#{v}" }, "profiler=#{defined?(Lowrail::Profile::API).inspect}"'
    out = IO.popen([RbConfig.ruby, "-e", probe], &:read)
    out << "-- with_unbundled_env\n" << Bundler.with_unbundled_env { IO.popen([RbConfig.ruby, "-e", probe], &:read) }
    File.write(ENV.fetch("CHILD_OUT"), out)
  end
end
RUBY
bundle exec ruby -e 'require "minitest"; puts "Minitest #{Minitest::VERSION}, register_plugin: #{Minitest.respond_to?(:register_plugin)}"'
for seed in "" 99; do
  e=(env -u SEED); [ -n "$seed" ] && e=(env SEED=$seed)
  "${e[@]}" CHILD_OUT=/tmp/pr2/m523-plain.txt bundle exec ruby -Itest test/mixed_test.rb -v > /tmp/pr2/m523-plain.log 2>&1; p=$?
  "${e[@]}" CHILD_OUT=/tmp/pr2/m523-profiled.txt bundle exec lowrail-profile --out tmp/lp-m -- ruby -Itest test/mixed_test.rb -v > /tmp/pr2/m523-profiled.log 2>&1; q=$?
  echo "caller SEED='$seed': plain exit $p ($(grep -o -- '--seed [0-9]*' /tmp/pr2/m523-plain.log | tr '\n' ' ')), profiled exit $q ($(grep -o -- '--seed [0-9]*' /tmp/pr2/m523-profiled.log | tr '\n' ' ')); $(grep -c ' = [0-9.]* s = \.' /tmp/pr2/m523-plain.log) and $(grep -c ' = [0-9.]* s = \.' /tmp/pr2/m523-profiled.log) passing test lines; $(grep Counted /tmp/pr2/m523-profiled.log | cut -c1-60)"
  diff /tmp/pr2/m523-plain.txt /tmp/pr2/m523-profiled.txt && echo "child identical" || echo "child DIFFERS"
done
cat /tmp/pr2/m523-profiled.txt
