#!/usr/bin/env bash
# minitest-probes.sh APPDIR : commits the probes into a fresh Minitest app.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd); cd "$1"
cp "$here/probe.rb" test/probe.rb
ruby -pi -e 'sub(/^require "rails\/test_help"\n/, %(require "rails/test_help"\nrequire_relative "probe"\nProbe.child("helper_load")\nMinitest.after_run { Probe.child("after_run"); Probe.run("after_run_nested_suite", "bin/rails", "test", "test/models/nested_test.rb") }\n))' test/test_helper.rb
ruby -pi -e 'sub(/^    fixtures :all\n/, %(    fixtures :all\n    parallelize_setup { |i| Probe.child("worker_setup") }\n))' test/test_helper.rb
cat > test/integration/probe_test.rb <<'RUBY'
require "test_helper"
class ProbeTest < ActionDispatch::IntegrationTest
  test "a child process started in a test" do
    get articles_url
    assert_response :success
    Probe.child("in_test")
    Probe.env("in_test_env")
    Probe.bundler("in_test")
    Probe.run("in_test_runner", "bin/rails", "runner", "puts Article.count; puts defined?(Lowrail::Profile).inspect")
  end
  test "a job and a mail" do
    TouchJob.perform_now
    NoticeMailer.hello.deliver_now
    assert true
  end
end
RUBY
cat > test/integration/hang_test.rb <<'RUBY'
require "test_helper"
class HangTest < ActionDispatch::IntegrationTest
  test "hangs when asked" do
    get articles_url
    assert_response :success
    if ENV["HANG"]
      trap("TERM") {} if ENV["HANG"] == "ignore"
      File.write(ENV["HANG_PID"], Process.pid.to_s) if ENV["HANG_PID"]
      sleep
    end
  end
end
RUBY
cat > test/models/nested_test.rb <<'RUBY'
require "test_helper"
# Run again by Minitest.after_run of the outer suite: prints the order the seed gave.
class NestedTest < ActiveSupport::TestCase
  %w[a b c d e f g h].each { |n| test("order #{n}") { $stdout.print(n) if ENV["PROBE_NESTED"]; assert true } }
end
RUBY
git add -A && git -c user.name=x -c user.email=x@x commit -qm probes
