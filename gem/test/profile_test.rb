# frozen_string_literal: true

# exe/lowrail-profile on the minimal Rails app of test_helper.rb: objects per
# source line inside requests only, warm and repeat-run columns, census-style
# keys, the app line and action that lead to a gem's allocations, and jobs and
# mails counted apart from requests.
#   ruby -Igem/lib -Igem/test gem/test/profile_test.rb

require "test_helper"

class ProfileTest < Minitest::Test
  include LowrailTest

  REQUESTS = 6
  INDEX = 4

  def test_counts_only_inside_requests_and_attributes_them_to_the_app
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "gems/probe-1.0/lib/probe.rb" => <<~'RUBY',
          # frozen_string_literal: true

          module Probe
            def self.three = [String.new, String.new]
            def self.many = Array.new(100) { String.new }
          end
        RUBY
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index = (@probe = Probe.three; @many = Probe.many; @widgets = Widget.all)
            def show = (ProbeJob.perform_now; @widget = Widget.find(params[:id]))
          end
        RUBY
        "app/views/widgets/show.html.erb" => "<%= @widget.name %>\n",
        "app/jobs/probe_job.rb" => "class ProbeJob < ActiveJob::Base\n  def perform = Probe.three\nend\n",
        "app/mailers/probe_mailer.rb" => <<~'RUBY',
          class ProbeMailer < ActionMailer::Base
            def hello = mail(to: "a@example.com", from: "b@example.com", subject: "Hi", body: "Hello")
          end
        RUBY
        "requests.rb" => <<~RUBY)
          require_relative "gems/probe-1.0/lib/probe"
          require "active_job/railtie"
          require "action_mailer/railtie"
          require_relative "config/environment"
          require "rack/mock"
          ActionMailer::Base.delivery_method = :test
          widget = Widget.create!(name: "w", password: "secret")
          get = ->(path) do
            status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost\#{path}"))
            raise "HTTP \#{status}" unless status == 200
          end
          1000.times { Probe.three }
          #{INDEX}.times { get.("/widgets") }
          #{REQUESTS - INDEX}.times { get.("/widgets/\#{widget.id}") }
          5.times { ProbeJob.perform_now }
          3.times { ProbeMailer.hello.deliver_now }
          1000.times { Probe.three }
          puts "lowrail loaded: \#{defined?(Lowrail) ? true : false}"
        RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")
      # A ledger whose index has an open and a released pull request on
      # Probe.many; the app runs probe 1.0.
      File.write(File.join(dir, "contributions.md"), "")
      many, three = "def self.many = Array.new(100) { String.new }", "def self.three = [String.new, String.new]"
      file = ->(method, removed: [], added: []) { [{ path: "lib/probe.rb", methods: { method => { removed: removed, added: added } } }] }
      File.write(File.join(dir, "contributions-index.json"), JSON.generate(pulls: [
        { ref: "x/probe#1", repo: "x/probe", allocation_work: true, state: "merged", released_in: "1.1", files: file.("many", removed: [many]) },
        { ref: "x/probe#2", repo: "x/probe", allocation_work: true, state: "open", files: file.("many", removed: [many]) },
        { ref: "x/probe#3", repo: "x/probe", allocation_work: true, state: "merged", released_in: "0.9", files: file.("three", added: [three]) },
        # Same method and file, but another line of it: no match.
        { ref: "x/probe#5", repo: "x/probe", allocation_work: true, state: "open", files: file.("three", removed: ["[String.new]"]) },
        # A correctness fix on the line, and another gem's file of the same name.
        { ref: "x/probe#6", repo: "x/probe", allocation_work: false, state: "open", files: file.("three", removed: [three]) },
        { ref: "x/other#4", repo: "x/other", allocation_work: true, state: "open", files: file.("three", removed: [three]) }]))
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--top", "200",
        "--ledger", "contributions.md", "--", RUBY, "requests.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      assert_equal 2, out.scan("lowrail loaded: true").size, err

      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      assert_equal [REQUESTS, REQUESTS], report["summary"].map { _1["requests"] }
      probe = report["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      refute_nil probe, "probe line not ranked"
      # Three objects per index request and per job inside a show request; the
      # 2000 calls and 5 jobs outside requests are not requests.
      assert_equal [3.0, 3.0], probe["all"]
      assert_equal [3.0 * (REQUESTS - 1) / REQUESTS] * 2, probe["warm"]
      assert_equal [REQUESTS, REQUESTS], probe["reached"]
      assert report["ranked"].any? { _1["site"].start_with?("RAILS/actionpack/lib/") }
      assert report["ranked"].all? { _1["site"].start_with?("RAILS/", "GEM/", "RUBY/") }

      row = report["rows"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      assert_equal [{ "caller" => "APP/app/controllers/widgets_controller.rb:2", "share" => 0.67 },
        { "caller" => "APP/app/jobs/probe_job.rb:2", "share" => 0.33 }], row["callers"]
      assert_equal 0.0, row["noise"]
      assert_equal ["x/probe#3 merged, in 0.9, which this app runs"], row["ledger"]
      many = report["rows"].find { _1["site"] == "GEM/probe/lib/probe.rb:5" }
      assert_equal ["x/probe#1 fixed in 1.1", "x/probe#2 open upstream work"], many["ledger"]

      # Your code: the index line leads to Probe.many's 101 objects per index
      # request, warm over all requests leaving out the action's first one.
      line = report["app_lines"].find { _1["line"] == "APP/app/controllers/widgets_controller.rb:2" }
      assert_equal({ "name" => "GEM/probe/lib/probe.rb:5", "share" => line["sites"][0]["share"] }, line["sites"][0])
      assert_operator line["warm"], :>=, 101.0 * (INDEX - 1) / REQUESTS + 3.0 * (INDEX - 1) / REQUESTS
      assert_equal [{ "name" => "WidgetsController#index", "share" => 1.0 }], line["actions"]

      actions = report["actions"].to_h { [_1["name"], _1] }
      assert_equal [[INDEX, INDEX], [REQUESTS - INDEX, REQUESTS - INDEX]],
        actions.values_at("WidgetsController#index", "WidgetsController#show").map { _1["windows"] }
      index = actions.fetch("WidgetsController#index")
      assert_equal "WidgetsController#index", report["actions"][0]["name"], "the heavier action ranks first"
      assert_equal({ "name" => "GEM/probe/lib/probe.rb:5", "warm" => 101.0 }, index["sites"][0])

      jobs = report["outside_requests"]["job"]
      assert_equal [5, 5], report["summary"].map { _1["windows"]["job"] }
      assert_equal [["ProbeJob#perform", [5, 5]]], jobs["actions"].map { [_1["name"], _1["windows"]] }
      job_probe = jobs["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      assert_equal [3.0, 3.0], job_probe["all"]
      mails = report["outside_requests"]["mail"]["actions"].to_h { [_1["name"], _1["windows"]] }
      assert_equal({ "ProbeMailer#hello" => [3, 3], "ProbeMailer.deliver_mail" => [3, 3] }, mails)

      # compare: the same report is no regression; one more Probe.many per
      # index request is, for the line and the action.
      compare = ->(*paths) { Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "compare", *paths, "--json", chdir: dir) }
      _, _, status = compare.("profile/report.json", "profile/report.json")
      assert_equal 0, status.exitstatus
      head = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      head["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:5" }["warm"].map! { _1 + 50 }
      head["actions"].find { _1["name"] == "WidgetsController#index" }["warm"].map! { _1 + 101 }
      File.write(File.join(dir, "head.json"), JSON.generate(head))
      out, _, status = compare.("profile/report.json", "head.json")
      assert_equal 1, status.exitstatus
      assert_equal [["action", "WidgetsController#index"], ["line", "GEM/probe/lib/probe.rb:5"]],
        JSON.parse(out)["regressions"].map { [_1["what"], _1["name"]] }.sort

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
