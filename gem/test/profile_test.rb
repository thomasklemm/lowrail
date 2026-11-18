# frozen_string_literal: true

# exe/lowrail-profile on the minimal Rails app of test_helper.rb: objects per
# source line inside requests only, warm and repeat-run columns, census-style
# keys, the app line and action that lead to a gem's allocations, and jobs and
# mails counted apart from requests; and what it must never do to the app or
# to the files around it.
#   ruby -Igem/lib -Igem/test gem/test/profile_test.rb

require "test_helper"
require "uri"

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

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")

  def profile_env(dir) = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")

  def profile(dir, *args, env: {}) = Open3.capture3(profile_env(dir).merge(env), RUBY, PROFILE, *args, chdir: dir)

  # Recording keeps request values as data: a routed format becomes a quoted
  # string, never Ruby; values the app's filter_parameters hides (a password,
  # a nested API token, a query token) are not exported anywhere; a GET's query
  # stays; and a request that cannot replay as recorded is commented out.
  def test_record_keeps_request_values_as_data_and_filters_secrets
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      injected = "html); $lowrail_injected = true; #"
      LowrailTest.write_rails_app(dir,
        "config/initializers/filter.rb" => "Rails.application.config.filter_parameters += [:password, :api_token, :token]\n",
        "config/routes.rb" => "Rails.application.routes.draw { resources :widgets, only: %i[index show create] }\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            skip_forgery_protection
            def index = head(:ok)
            def show = head(:ok)
            def create = head(:created)
          end
        RUBY
        "boot.rb" => "require_relative \"config/environment\"\nWidget.create!(name: \"first\", password: \"x\")\n",
        "requests.rb" => <<~RUBY)
          require_relative "boot"
          require "rack/mock"
          call = ->(path, **opts) { Rails.application.call(Rack::MockRequest.env_for("http://localhost\#{path}", opts)) }
          3.times { call.("/widgets?q=needle") }
          call.("/widgets.\#{ERB::Util.url_encode(#{injected.inspect})}")
          call.("/widgets/1?token=query-secret-1")
          call.("/widgets?token=query-secret-2", method: "POST",
            params: { widget: { name: "n", password: "pw-secret-3", api: { api_token: "api-secret-4" } } })
        RUBY
      out, err, status = profile(dir, "--out", "profile", "--record", "--", RUBY, "requests.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      recorded = File.read(File.join(dir, "lowrail/workloads.rb"))
      written = [recorded, *Dir[File.join(dir, "profile/**/*")].select { File.file?(_1) }.map { File.read(_1) }]
      %w[query-secret-1 query-secret-2 pw-secret-3 api-secret-4].each do |secret|
        assert written.none? { _1.include?(secret) }, "#{secret} was exported:\n#{recorded}"
      end
      assert_includes recorded, %(get widgets_path, name: "GET /widgets", params: {"q" => "needle"}\n)
      assert_match(/^# post widgets_path, name: "POST \/widgets", params: .*"password" => "\[FILTERED\]".*"api_token" => "\[FILTERED\]"/, recorded)
      assert_match(/^# get widget_path\(widget\), name: "GET \/widgets\/:id", params: \{"token" => "\[FILTERED\]"\}$/, recorded)
      # Only a commented-out request uses the record, so its lookup is commented out too.
      assert_includes recorded, "# widget = Widget.first!\n"

      check = <<~'RUBY'
        require "./boot"
        require "json"
        require "lowrail/workloads"
        requests = Lowrail::Workloads.load("lowrail/workloads.rb").requests
        puts JSON.generate(injected: $lowrail_injected, requests: requests.map { [_1.name, _1.path] })
      RUBY
      evaluated = ruby_json(check, chdir: dir, setup: false, env: { "RAILS_ENV" => "test", "RUBYOPT" => "-I#{GEM_LIB}" })
      assert_nil evaluated["injected"], recorded
      name, path = evaluated["requests"].find { _1[0].include?("lowrail_injected") }
      assert_equal "GET /widgets.#{injected}", name
      assert_equal "/widgets.#{injected}", URI.decode_uri_component(path)
    end
  end

  # Every path value, the format included, is filtered before it is kept, by
  # the app's filter list as it is when the request runs (here appended to
  # after the first request); a JSON GET is recorded as a GET with its Accept
  # and query, not as a JSON body.
  def test_record_filters_every_value_and_keeps_json_gets_as_gets
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "config/initializers/filter.rb" => "Rails.application.config.filter_parameters += [:format]\n",
        "config/routes.rb" => "Rails.application.routes.draw { resources :widgets, only: %i[index show]; get \"/lookup\" => \"widgets#lookup\" }\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index = head(:ok)
            def show = head(:ok)
            def lookup = render(json: { method: request.request_method, query: request.query_parameters, body: request.request_parameters })
          end
        RUBY
        "boot.rb" => "require_relative \"config/environment\"\nWidget.create!(name: \"first\", password: \"x\")\n",
        "requests.rb" => <<~'RUBY')
          require_relative "boot"
          require "rack/mock"
          call = ->(path, **opts) { Rails.application.call(Rack::MockRequest.env_for("http://localhost#{path}", opts)) }
          call.("/widgets.format-secret")
          Rails.application.env_config["action_dispatch.parameter_filter"] << :credential
          call.("/widgets/1?credential=changed-filter-secret")
          call.("/lookup?q=needle", "HTTP_ACCEPT" => "application/json")
        RUBY
      out, err, status = profile(dir, "--out", "profile", "--record", "--", RUBY, "requests.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      recorded = File.read(File.join(dir, "lowrail/workloads.rb"))
      written = [recorded, *Dir[File.join(dir, "profile/**/*")].select { File.file?(_1) }.map { File.read(_1) }]
      %w[format-secret changed-filter-secret].each do |secret|
        assert written.none? { _1.include?(secret) }, "#{secret} was exported:\n#{recorded}"
      end
      assert_match(/^# get "\/widgets\.\[FILTERED\]"|^# get widgets_path\(format: "\[FILTERED\]"\)/, recorded)
      assert_match(/^# get widget_path\(widget\), .*params: \{"credential" => "\[FILTERED\]"\}$/, recorded)

      check = <<~'RUBY'
        require "./boot"
        require "json"
        require "rack/mock"
        require "lowrail/workloads"
        r = Lowrail::Workloads.load("lowrail/workloads.rb").requests.find { _1.path.start_with?("/lookup") }
        sent = Lowrail::Workloads::MockClient.new(Rails.application, "localhost").request(r.verb, r.path, params: r.params, headers: r.headers, body: r.body)
        puts JSON.generate(declared: [r.verb, r.params, r.body, r.headers["HTTP_ACCEPT"]], seen: JSON.parse(sent.body))
      RUBY
      replay = ruby_json(check, chdir: dir, setup: false, env: { "RAILS_ENV" => "test", "RUBYOPT" => "-I#{GEM_LIB}" })
      assert_equal ["get", { "q" => "needle" }, nil, "application/json"], replay["declared"], recorded
      assert_equal({ "method" => "GET", "query" => { "q" => "needle" }, "body" => {} }, replay["seen"])
    end
  end

  # --workloads captures compare by what they measured: two of the same file
  # in different output directories compare, and a block that sends another
  # request in one of them does not, though the file is the same.
  def test_workloads_captures_compare_by_what_they_measured
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "bin/rails" => "#!#{RUBY}\nabort unless ARGV.shift == \"runner\"\nscript = ARGV.shift\nrequire_relative \"../config/environment\"\nload script\n",
        "lowrail/workloads.rb" => "get(\"/widgets\", name: \"variant\") { |n| { path: ENV.fetch(\"REPLAY_PATH\") } }\n")
      File.chmod(0o755, File.join(dir, "bin/rails"))
      { "base" => "/widgets?v=1", "head" => "/widgets?v=1", "other" => "/widgets?v=2" }.each do |out, path|
        _, err, status = profile(dir, "--out", out, "--workloads", env: { "REPLAY_PATH" => path })
        assert status.success?, err
      end
      compare = ->(a, b) { Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "#{a}/report.json", "#{b}/report.json", "--json", chdir: dir) }
      out, err, status = compare.("base", "head")
      assert_equal 0, status.exitstatus, "#{out}\n#{err}"
      out, _, status = compare.("base", "other")
      assert_equal 2, status.exitstatus, out
      assert_match(/differ in identity/, JSON.parse(out)["problems"].join)
    end
  end

  # The native counter's public snapshot: a line's first window is the one
  # that reached it first, whichever closes first; and windows left open in
  # abandoned fibers are bounded, so most such fibers can be collected.
  def test_first_window_is_first_reached_and_open_windows_are_bounded
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "probe.rb"), <<~'RUBY')
        require "weakref"
        P = Lowrail::Profile
        def at_one_site(n) = n.times { String.new }
        go, started = Queue.new, Queue.new
        a = Thread.new { P.enter(0); at_one_site(10); started << 1; go.pop; P.leave }
        started.pop
        Thread.new { P.enter(0); at_one_site(2); P.leave }.join
        go << 1
        a.join
        row = P.snapshot[3].find { _1[0] == __FILE__ && _1[1] == 3 && _1[2] == 5 }
        puts "site #{row.values_at(3, 4, 5).join(" ")}"
        refs = 1100.times.map { f = Fiber.new { P.enter(1); Fiber.yield }; f.resume; WeakRef.new(f) }
        3.times { GC.start }
        puts "alive #{refs.count(&:weakref_alive?)}"
      RUBY
      out, err, = profile(dir, "--out", "profile", "--runs", "1", "--", RUBY, "probe.rb")
      assert_includes out, "site 12 2 10\n", err
      assert_operator out[/^alive (\d+)$/, 1].to_i, :<=, 1024, out
    end
  end

  # --record notes Rack requests only: a Cable subscription returns what it
  # returned, and its exceptions, and a job's, pass through as the same
  # objects, in both runs.
  def test_recording_leaves_cable_subscriptions_and_exceptions_unchanged
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "cable.rb" => <<~'RUBY')
        require "active_job/railtie"
        require_relative "config/environment"
        require "action_cable"
        require "action_cable/channel/test_case"
        require "rack/mock"
        class OkChannel < ActionCable::Channel::Base
          def subscribed = nil
        end
        class BadChannel < ActionCable::Channel::Base
          def subscribed = raise($boom = RuntimeError.new("boom"))
        end
        class BoomJob < ActiveJob::Base
          def perform = raise($job_boom = ArgumentError.new("job"))
        end
        connection = ActionCable::Channel::ConnectionStub.new
        puts "subscribed #{OkChannel.new(connection, "{}", {}).subscribe_to_channel.inspect} #{connection.transmissions.size}"
        begin
          BadChannel.new(connection, "{}", {}).subscribe_to_channel
        rescue => e
          puts "channel raised #{e.class} #{e.equal?($boom)}"
        end
        begin
          BoomJob.perform_now
        rescue => e
          puts "job raised #{e.class} #{e.equal?($job_boom)}"
        end
        status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
        puts "request #{status}"
      RUBY
      plain, err, status = Open3.capture3(profile_env(dir), RUBY, "cable.rb", chdir: dir)
      assert status.success?, err
      expected = "subscribed true 1\nchannel raised RuntimeError true\njob raised ArgumentError true\nrequest 200\n"
      assert_equal expected, plain
      out, err, status = profile(dir, "--out", "profile", "--record", "--", RUBY, "cable.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      assert_equal 2, out.scan(expected).size, "#{out}\n#{err}"
      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      assert_equal [{ "OkChannel#subscribed" => [1, 1], "BadChannel#subscribed" => [1, 1] }],
        [report["outside_requests"]["cable"]["actions"].to_h { [_1["name"], _1["windows"]] }]
    end
  end

  # --out refuses a directory it did not create, and in one it did, clears
  # only its own runs and reports.
  def test_out_never_clears_a_directory_it_did_not_create
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        File.write("ran.txt", "")
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
      RUBY
      FileUtils.mkdir_p(File.join(dir, "mine"))
      File.write(File.join(dir, "mine/must-keep.txt"), "x")
      out, err, status = profile(dir, "--out", "mine", "--", RUBY, "requests.rb")
      refute status.success?, out
      assert_match(/was not created by lowrail-profile/, err)
      assert File.exist?(File.join(dir, "mine/must-keep.txt"))
      refute File.exist?(File.join(dir, "ran.txt")), "the command ran"
      _, err, status = profile(dir, "--out", ".", "--", RUBY, "requests.rb")
      refute status.success?, err
      assert File.exist?(File.join(dir, "config/environment.rb"))

      _, err, status = profile(dir, "--out", "profile", "--runs", "3", "--", RUBY, "requests.rb")
      assert status.success?, err
      File.write(File.join(dir, "profile/notes.txt"), "x")
      _, err, status = profile(dir, "--out", "profile", "--", RUBY, "requests.rb")
      assert status.success?, err
      assert_equal %w[.lowrail-profile capture.json command.txt notes.txt report.json report.md run1 run2],
        Dir.children(File.join(dir, "profile")).sort
    end
  end

  # A counter of another version is refused before anything is hooked, and a
  # framework hook that cannot be installed (into a frozen class) leaves the
  # app's load as it was.
  def test_an_unusable_counter_or_hook_leaves_the_app_alone
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        # The API of an older counter (enter without a kind, no Profile::API).
        "old_counter.rb" => <<~'RUBY',
          module Lowrail
            module Profile
              %i[start leave reset].each { |m| define_singleton_method(m) { nil } }
              def self.enter = nil
              def self.label(*) = nil
              def self.snapshot = [[0] * 4, [0] * 4, 0, [], [], []]
            end
          end
        RUBY
        "requests.rb" => <<~'RUBY',
          require_relative "config/environment"
          require "rack/mock"
          status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
          puts "request #{status}"
        RUBY
        "frozen.rb" => <<~'RUBY')
          require "action_controller"
          ActionController::Metal.freeze
          ActionController::Base
          puts "loaded Base"
        RUBY
      env = profile_env(dir).merge("LOWRAIL_PROFILE" => File.join(dir, "out"), "LOWRAIL_PROFILE_EXT" => File.join(dir, "old_counter.rb"),
        "RUBYOPT" => "-I#{GEM_LIB} -rlowrail/profile")
      FileUtils.mkdir_p(File.join(dir, "out"))
      out, err, = Open3.capture3(env, RUBY, "requests.rb", chdir: dir)
      assert_equal "request 200\n", out, err
      assert_match(/\[lowrail-profile\] off: LoadError: .*old_counter\.rb is not this lowrail-profile's counter/, err)

      out, err, = profile(dir, "--out", "profile", "--", RUBY, "frozen.rb")
      assert_equal 2, out.scan("loaded Base\n").size, err
      assert_match(/ActionController::Metal#dispatch not profiled: FrozenError/, err)
    end
  end

  # Everything after the first -- is the command's, a second -- and
  # profiler-looking flags included.
  def test_arguments_after_the_separator_belong_to_the_command
    realpath_tmpdir do |dir|
      out, err, = profile(dir, "--out", "profile", "--runs", "1", "--", RUBY, "-e", "p ARGV", "--", "--workloads", "--out", "x")
      assert_equal "[\"--workloads\", \"--out\", \"x\"]\n", out, err
      assert_match(/no report: no runs with requests/, err)
    end
  end

  def report(warm, runs: 2, exit: [0] * runs, actions: [])
    meta = { "format" => 2, "identity" => { "mode" => "command", "argv" => %w[bin/rails test] }, "argv" => %w[bin/rails test],
      "seed" => "1234", "exit" => exit, "runs" => runs, "ruby" => ["ruby 4"], "rails_env" => ["test"], "dropped" => [0] * runs,
      # 76be8b58's fields, so a case that must be refused is not refused only for lacking them there
      "command" => "bin/rails test", "workloads" => nil }
    { "command" => "bin/rails test", "summary" => Array.new(runs) { { "windows" => { "request" => 10 } } }, "meta" => meta,
      "ranked" => [{ "site" => "GEM/x/lib/x.rb:1", "warm" => warm }], "actions" => actions,
      "outside_requests" => %w[job mail cable].to_h { [_1, { "actions" => [], "ranked" => [] }] } }
  end

  def compare(dir, base, head)
    File.write(File.join(dir, "base.json"), JSON.generate(base))
    File.write(File.join(dir, "head.json"), JSON.generate(head))
    out, err, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base.json", "head.json", "--json", chdir: dir)
    [status.exitstatus, (JSON.parse(out) rescue err)]
  end

  # compare gates only on valid evidence (exit 2 otherwise), takes the noise
  # floor from every run, and leaves out actions one side cannot measure.
  def test_compare_needs_complete_comparable_captures
    realpath_tmpdir do |dir|
      assert_equal 2, compare(dir, {}, {})[0]
      assert_equal 2, compare(dir, report([10.0, 10.0]), {})[0]
      assert_equal 2, compare(dir, report([10.0], runs: 1), report([30.0], runs: 1))[0], "one run has no noise floor"
      assert_equal 2, compare(dir, report([10.0, 10.0], exit: [0, 1]), report([30.0, 30.0]))[0]
      assert_equal 1, compare(dir, report([10.0, 10.0]), report([30.0, 30.0]))[0]
      status, result = compare(dir, report([10.0, 1000.0, 10.0], runs: 3), report([20.0, 1010.0, 20.0], runs: 3))
      assert_equal 0, status, "a middle run's spread is noise too: #{result}"
      status, result = compare(dir, report([1.0, 1.0], actions: [{ "name" => "A#b", "warm" => [nil, nil] }]),
        report([1.0, 1.0], actions: [{ "name" => "A#b", "warm" => [100.0, 100.0] }]))
      assert_equal [0, [{ "kind" => "request", "name" => "A#b", "reason" => "no warm value" }]], [status, result["not_compared"]]

      # Incomplete reports: a missing collection, a short warm vector, no identity or seed.
      assert_equal 2, compare(dir, report([10.0, 10.0]), report([10.0, 10.0]).except("ranked"))[0], "no ranked lines is not zero"
      assert_equal 2, compare(dir, report([10.0, 10.0]), report([10.0]))[0], "one warm value for two runs"
      bare = ->(r) { r.merge("meta" => r["meta"].except("identity", "seed", "command")) }
      assert_equal 2, compare(dir, bare.(report([10.0, 10.0])), bare.(report([10.0, 10.0])))[0]
      jobs = report([10.0, 10.0]).merge("summary" => [{ "windows" => { "job" => 3 } }] * 2)
      status, result = compare(dir, report([10.0, 10.0]), jobs)
      assert_equal 2, status, "nothing comparable: #{result}"
    end
  end

  # The CI step docs/profile.md shows fails the job on a regression, run the
  # way GitHub Actions runs it (an explicit shell: bash adds pipefail).
  def test_documented_ci_compare_step_fails_on_a_regression
    require "yaml"
    realpath_tmpdir do |dir|
      yaml = File.read(File.join(GEM_ROOT, "../docs/profile.md"))[/```yaml\n(.*?)```/m, 1]
      step = YAML.safe_load(yaml).values.first.fetch("steps").find { _1["name"] == "Compare" }
      shell = { nil => %w[bash -e], "bash" => %w[bash --noprofile --norc -eo pipefail] }.fetch(step["shell"])
      FileUtils.mkdir_p(File.join(dir, "bin"))
      File.write(File.join(dir, "bin/bundle"), "#!/bin/sh\nshift 2\nexec #{RUBY} #{PROFILE} \"$@\"\n")
      File.chmod(0o755, File.join(dir, "bin/bundle"))
      %w[base head].zip([10.0, 30.0]) do |name, warm|
        FileUtils.mkdir_p(File.join(dir, "tmp", name))
        File.write(File.join(dir, "tmp", name, "report.json"), JSON.generate(report([warm, warm])))
      end
      File.write(File.join(dir, "step.sh"), step.fetch("run"))
      env = CLEAN_ENV.merge("PATH" => "#{File.join(dir, "bin")}:#{ENV["PATH"]}", "GITHUB_STEP_SUMMARY" => File.join(dir, "summary.md"))
      _, _, status = Open3.capture3(env, *shell, "step.sh", chdir: dir)
      refute status.success?, "the documented Compare step passes on a regression"
      assert_match(/Regressions: 1/, File.read(File.join(dir, "summary.md")))
    end
  end
end
