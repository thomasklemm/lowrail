# frozen_string_literal: true

# exe/lowrail-profile on the minimal Rails app of test_helper.rb: objects per
# source line inside requests only, warm and repeat-run columns, census-style
# keys and the app line that leads to a gem's allocations.
#   ruby -Igem/lib -Igem/test gem/test/profile_test.rb

require "test_helper"

class ProfileTest < Minitest::Test
  include LowrailTest

  REQUESTS = 6

  def test_counts_only_inside_requests_and_attributes_them_to_the_app
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "gems/probe-1.0/lib/probe.rb" => "# frozen_string_literal: true\n\nmodule Probe\n  def self.three = [String.new, String.new]\nend\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index = (@probe = Probe.three; @widgets = Widget.all)
            def show = @widget = Widget.find(params[:id])
          end
        RUBY
        "requests.rb" => <<~RUBY)
          require_relative "gems/probe-1.0/lib/probe"
          require_relative "config/environment"
          require "rack/mock"
          1000.times { Probe.three }
          #{REQUESTS}.times do
            status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
            raise "HTTP \#{status}" unless status == 200
          end
          1000.times { Probe.three }
          puts "lowrail loaded: \#{defined?(Lowrail) ? true : false}"
        RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--top", "200",
        "--", RUBY, "requests.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      assert_equal 2, out.scan("lowrail loaded: true").size

      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      assert_equal [REQUESTS, REQUESTS], report["summary"].map { _1["requests"] }
      probe = report["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      refute_nil probe, "probe line not ranked"
      # Three objects per request; the 2000 calls outside requests are not counted.
      assert_equal [3.0, 3.0], probe["all"]
      assert_equal [3.0 * (REQUESTS - 1) / REQUESTS] * 2, probe["warm"]
      assert_equal [REQUESTS, REQUESTS], probe["reached"]
      assert report["ranked"].any? { _1["site"].start_with?("RAILS/actionpack/lib/") }
      assert report["ranked"].all? { _1["site"].start_with?("RAILS/", "GEM/", "RUBY/") }

      row = report["rows"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      assert_equal [{ "caller" => "APP/app/controllers/widgets_controller.rb:2", "share" => 1.0 }], row["callers"]
      assert_equal 0.0, row["noise"]

      plain, = Open3.capture3(env, RUBY, "requests.rb", chdir: dir)
      assert_includes plain, "lowrail loaded: false"
    end
  end

  # B -> --record -> a workloads file -> replayed: the suite's request shapes
  # come back as route helpers on each model's first row, and replaying the
  # file counts the same line per request again.
  def test_record_writes_a_workloads_file_that_replays
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "gems/probe-1.0/lib/probe.rb" => "# frozen_string_literal: true\n\nmodule Probe\n  def self.three = [String.new, String.new]\nend\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index = (@probe = Probe.three; @widgets = Widget.all)
            def show = (@probe = Probe.three; @widget = Widget.find(params[:id]))
          end
        RUBY
        "app/views/widgets/show.html.erb" => "<%= @widget.name %>\n",
        "boot.rb" => <<~'RUBY',
          require_relative "gems/probe-1.0/lib/probe"
          require_relative "config/environment"
          Widget.create!(name: "first", password: "x")
          Widget.create!(name: "second", password: "x")
        RUBY
        "requests.rb" => <<~'RUBY')
          require_relative "boot"
          require "rack/mock"
          [*["/widgets"] * 3, "/widgets/2"].each do |path|
            status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost#{path}"))
            raise "HTTP #{status}" unless status == 200
          end
        RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--record",
        "--", RUBY, "requests.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      recorded = File.read(File.join(dir, "lowrail/workloads.rb"))
      assert_match(/^widget = Widget\.first!$/, recorded)
      # Most frequent first; the record is the model's first row, not the one the test used.
      assert_operator recorded.index("get widgets_path,"), :<, recorded.index("get widget_path(widget),")

      replay = File.join(GEM_ROOT, "lib/lowrail/profile_workloads.rb")
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "replay", "--top", "200",
        "--", RUBY, "-r./boot", replay, "lowrail/workloads.rb", "replay.json", chdir: dir)
      assert status.success?, "replay failed:\n#{err}\n#{out}"
      report = JSON.parse(File.read(File.join(dir, "replay/report.json")))
      assert_equal [40, 40], report["summary"].map { _1["requests"] }
      assert_equal [3.0, 3.0], report["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }["all"]
      manifest = JSON.parse(File.read(File.join(dir, "replay.json")))["manifest"]
      assert_equal [["get", "/widgets"], ["get", "/widgets/1"]], manifest["requests"].map { _1.values_at("method", "path") }
    end
  end
end
