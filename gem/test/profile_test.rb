# frozen_string_literal: true

# exe/lowrail-profile on the minimal Rails app of test_helper.rb: objects per
# source line inside requests only, warm and repeat-run columns, census-style
# keys, the app line and action that lead to a gem's allocations, and jobs and
# mails counted apart from requests; windows the counter cannot close; a
# counter or hook that cannot be used leaving the app alone; and the profiler
# in the processes the suite starts. --record and --workloads are in
# profile_record_test.rb, the command's options and exit in profile_cli_test.rb.
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
        "--ledger", "contributions-index.json", "--", RUBY, "requests.rb", chdir: dir)
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
      # Among its top lines, not always first: Ruby 3.3 charges a one-time compile in the second request to line 0.
      assert_includes index["sites"], { "name" => "GEM/probe/lib/probe.rb:5", "warm" => 101.0 }

      jobs = report["outside_requests"]["job"]
      assert_equal [5, 5], report["summary"].map { _1["windows"]["job"] }
      assert_equal [["ProbeJob#perform", [5, 5]]], jobs["actions"].map { [_1["name"], _1["windows"]] }
      job_probe = jobs["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:4" }
      assert_equal [3.0, 3.0], job_probe["all"]
      mails = report["outside_requests"]["mail"]["actions"].to_h { [_1["name"], _1["windows"]] }
      assert_equal({ "ProbeMailer#hello" => [3, 3], "ProbeMailer.deliver_mail" => [3, 3] }, mails)

      # compare: the same report lists no regression; one more Probe.many per
      # index request is listed, for the line and the action (a report: exit 0).
      compare = ->(*paths) { Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "compare", *paths, "--json", chdir: dir) }
      _, _, status = compare.("profile/report.json", "profile/report.json")
      assert_equal 0, status.exitstatus
      head = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      head["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:5" }["warm"].map! { _1 + 50 }
      head["actions"].find { _1["name"] == "WidgetsController#index" }["warm"].map! { _1 + 101 }
      File.write(File.join(dir, "head.json"), JSON.generate(head))
      FileUtils.cp(File.join(dir, "profile/report.json"), File.join(dir, "aa.json"))
      out, _, status = compare.("profile/report.json", "head.json", "--aa", "aa.json")
      assert_equal 0, status.exitstatus
      assert_equal [["action", "WidgetsController#index"], ["line", "GEM/probe/lib/probe.rb:5"]],
        JSON.parse(out)["regressions"].map { [_1["what"], _1["name"]] }.sort

      plain, = Open3.capture3(env, RUBY, "requests.rb", chdir: dir)
      assert_includes plain, "lowrail loaded: false"
    end
  end

  # Found on Hackatime in one process: ViteRuby probes its dev server
  # (Socket.tcp, at most once a second), so which requests pay a probe follows
  # timing. What Socket.tcp allocates while it connects is counted apart, in
  # every kind and run; a socket read, and the block Socket.tcp yields to, are
  # the app's own work and stay in its action and lines.
  def test_socket_connects_are_counted_apart_and_socket_reads_are_not
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "config/routes.rb" => <<~'RUBY',
          Rails.application.routes.draw do
            get "net/ready" => "net#ready"
            get "net/plain" => "net#plain"
            get "net/probe" => "net#probe"
            get "net/reads" => "net#reads"
            get "net/block" => "net#block"
          end
        RUBY
        "app/controllers/net_controller.rb" => <<~'RUBY',
          class NetController < ApplicationController
            def ready = (Connect.call; PAIR[0].recv_nonblock(1); head :ok)
            def plain = (@a = [String.new, String.new]; head :ok)
            def probe = (@a = [String.new, String.new]; Connect.call; head :ok)
            def reads = (@a = [String.new, String.new]; 10.times { PAIR[0].recv_nonblock(1) }; head :ok)
            def block = (@a = [String.new, String.new]; Socket.tcp("127.0.0.1", PORT) { 50.times { String.new } }; head :ok)
          end
        RUBY
        "app/jobs/probe_job.rb" => "class ProbeJob < ActiveJob::Base\n  def perform = Refused.call\nend\n",
        # The profiler starts before RubyGems does.
        "boot.rb" => "require \"rubygems\"\nrequire_relative \"requests\"\n",
        "requests.rb" => <<~'RUBY')
          require "socket"
          require "active_job/railtie"
          require_relative "config/environment"
          require "rack/mock"
          # A server that is not running, as ViteRuby's dev server is in a suite, and one that is.
          Refused = -> { Socket.tcp("127.0.0.1", 1, connect_timeout: 1).close rescue nil }
          SERVER = TCPServer.new("127.0.0.1", 0)
          PORT = SERVER.addr[1]
          Connect = -> { Socket.tcp("127.0.0.1", PORT, connect_timeout: 1).close }
          PAIR = Socket.pair(:UNIX, :STREAM)
          PAIR[1].write("x" * 1000)
          get = lambda do |action|
            status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost/net/#{action}"))
            raise "HTTP #{status}" unless status == 200
          end
          # The app's one-time work goes to an action not compared here.
          4.times { get.("ready") }
          4.times { %w[plain probe reads block].each(&get) }
          3.times { ProbeJob.perform_now }
        RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--top", "500",
        "--no-ledger", "--", RUBY, "--disable-gems", "boot.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"

      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      actions = report["actions"].to_h { [_1["name"], _1] }
      plain, probe, reads, block = actions.values_at(*%w[plain probe reads block].map { "NetController##{_1}" })
      # The same objects with and without a probe, and the probe's counted apart: but one, which the
      # call allocates before the hook marks the connect.
      probe["warm"].zip(plain["warm"]) { |p, q| assert_includes [q, q + 1], p, probe["warm"].inspect }
      assert probe["network"].all?(&:positive?), probe["network"].inspect
      assert_equal [[0, 0], [0, 0], [0, 0]], [plain["network"], reads["network"], block["network"]]
      assert_equal report["summary"].map { _1["network"]["request"] }, report["actions"].map { _1["network"] }.transpose.map(&:sum)
      jobs = report["summary"].map { _1["network"]["job"] }
      assert jobs.all?(&:positive?), jobs.inspect
      # Ten one-byte reads: a String each, in its action and on a socket.rb line.
      reads["warm"].zip(plain["warm"]) { |r, p| assert_operator r, :>=, p + 10 }
      assert reads["sites"].any? { _1["name"].start_with?("RUBY/socket.rb:") && _1["warm"] == 10.0 }, reads["sites"].inspect
      assert report["ranked"].any? { _1["site"].start_with?("RUBY/socket.rb:") }
      # With a block, Socket.tcp is counted whole: the connect and the block's 50 Strings.
      block["warm"].zip(probe["warm"]) { |b, p| assert_operator b, :>=, p + 50 }
      md = File.read(File.join(dir, "profile/report.md"))
      requests = report["summary"].map { _1["network"]["request"] }
      assert_includes md, "inside `Socket.tcp`, by run #{requests.join(" / ")} in requests, #{jobs.join(" / ")} in jobs"
    end
  end

  # A file ActionDispatch::Static serves answers before routing, so no
  # controller names it: in a field test most of a system-test slice's
  # requests were assets, under "(no action name)". They are named after the
  # file handler and counted in the header.
  def test_static_files_are_named_and_counted_apart
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "public/robots.txt" => "User-agent: *\n", "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        %w[/robots.txt /robots.txt /robots.txt /robots.txt /widgets /widgets].each do |path|
          status, = Rails.application.call(Rack::MockRequest.env_for("http://localhost#{path}"))
          raise "HTTP #{status} for #{path}" unless status == 200
        end
      RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--no-ledger",
        "--", RUBY, "requests.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      names = report["actions"].to_h { [_1["name"], _1["windows"]] }
      assert_equal({ "ActionDispatch::FileHandler#serve" => [4, 4], "WidgetsController#index" => [2, 2] }, names)
      assert_equal [4, 4], report["summary"].map { _1["static_requests"] }
      assert_includes File.read(File.join(dir, "profile/report.md")), "Static files: 4 of run 1's requests"

      # Only static files, with no app line on the stack of any allocation.
      File.write(File.join(dir, "static.rb"), File.read(File.join(dir, "requests.rb")).sub(" /widgets /widgets]", "]"))
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "static", "--no-ledger",
        "--", RUBY, "static.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      assert_equal [nil, nil], JSON.parse(File.read(File.join(dir, "static/report.json")))["summary"].map { _1["objects_per_dynamic_request"] }
    end
  end

  # The Socket.tcp hook waits for the app to load socket: a window does not
  # resolve an autoload of Socket (invariant 7), and once the app loads it a
  # later window hooks it; another Ractor's connects are left alone.
  def test_the_socket_hook_resolves_no_autoload
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "windows.rb"), <<~'RUBY')
        autoload :Socket, "socket"
        2.times { Lowrail::Profile.close(Lowrail::Profile.open(0)) }
        puts "autoload: #{Object.autoload?(:Socket).inspect}, loaded: #{$LOADED_FEATURES.any? { _1.end_with?("/socket.rb") }}"
        Socket.tcp("127.0.0.1", 1, connect_timeout: 1) rescue nil
        Lowrail::Profile.close(Lowrail::Profile.open(0))
        puts "hooked: #{Socket.singleton_class.ancestors.first == Lowrail::Profile::Connect}"
        # Outside the main Ractor the hook stays out of the way (the counter is the main Ractor's).
        server = TCPServer.new("127.0.0.1", 0)
        Warning[:experimental] = false
        ractor = Ractor.new(server.addr[1]) do |port|
          [port, 1].map { |p| (Socket.tcp("127.0.0.1", p, connect_timeout: 1).close; "connected") rescue $!.class.name }
        end
        puts "ractor: #{(ractor.respond_to?(:value) ? ractor.value : ractor.take).join(", ")}"
      RUBY
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"))
      out, err, status = Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "--out", "profile", "--no-ledger",
        "--", RUBY, "windows.rb", chdir: dir)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      assert_equal 2, out.scan(%(autoload: "socket", loaded: false)).size, out
      assert_equal 2, out.scan("hooked: true").size, out
      assert_equal 2, out.scan("ractor: connected, Errno::ECONNREFUSED").size, out
    end
  end

  # An engine's suite: run from the engine (api/), its dummy app's Rails.root
  # below it, a sibling gem from a path (core/, as Bundler's path: loads it)
  # and a file in no gem. Path-gem lines rank as that gem's, the engine's lines are
  # keyed relative to the directory they were attributed through, and what is
  # left over is reported with its share, not dropped.
  def test_path_gems_and_an_engine_root_are_classified
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      api = File.join(dir, "api")
      LowrailTest.write_rails_app(File.join(api, "spec/dummy"),
        "app/controllers/widgets_controller.rb" => <<~'RUBY')
          class WidgetsController < ApplicationController
            def index = (Engine.call; Phr.many; head(:ok))
          end
        RUBY
      { "api/app/lib/engine.rb" => "module Engine\n  def self.call = (Core.many; Loose.many)\nend\n",
        "core/lib/core.rb" => "module Core\n  def self.many = Array.new(40) { String.new }\nend\n",
        "loose/loose.rb" => "module Loose\n  def self.many = Array.new(10) { String.new }\nend\n",
        "src/posthog-rails-3.18.6/lib/phr.rb" => "module Phr\n  def self.many = Array.new(20) { String.new }\nend\n" }.each do |rel, src|
        FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
        File.write(File.join(dir, rel), src)
      end
      # A path: gem reached through a symlink (posthog-rails on Dawarich): Ruby names its files by the real path.
      File.symlink(File.join(dir, "src/posthog-rails-3.18.6"), File.join(dir, "phr"))
      File.write(File.join(api, "requests.rb"), <<~'RUBY')
        spec = Gem::Specification.new { |s| (s.name, s.version) = "solidus_core", "1.0" }
        spec.full_gem_path = File.expand_path("../core", __dir__)
        Gem.loaded_specs["solidus_core"] = spec
        phr = Gem::Specification.new { |s| (s.name, s.version) = "posthog-rails", "3.18.6" }
        phr.full_gem_path = File.expand_path("../phr", __dir__)
        Gem.loaded_specs["posthog-rails"] = phr
        $LOAD_PATH << File.join(phr.full_gem_path, "lib")
        require "phr"
        # The profiler itself as a path gem (a Lowrail checkout in the Gemfile).
        own = Gem::Specification.new { |s| (s.name, s.version) = "lowrail", "0" }
        own.full_gem_path = ENV.fetch("PROFILER_DIR")
        Gem.loaded_specs["lowrail"] = own
        require_relative "../core/lib/core"
        require_relative "../loose/loose"
        require_relative "app/lib/engine"
        require_relative "spec/dummy/config/environment"
        require "rack/mock"
        6.times { Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets")) }
      RUBY
      _, err, status = profile(api, "--out", "p", "--", RUBY, "requests.rb",
        env: { "XDG_CACHE_HOME" => File.join(dir, "cache"), "PROFILER_DIR" => GEM_ROOT })
      assert status.success?, err
      report = JSON.parse(File.read(File.join(api, "p/report.json")))
      core = report["ranked"].find { _1["site"] == "GEM/solidus_core/lib/core.rb:2" }
      assert core, report["ranked"].map { _1["site"] }.first(10).inspect
      assert_equal "gem: solidus_core", core["group"]
      phr = report["ranked"].find { _1["site"] == "GEM/posthog-rails/lib/phr.rb:2" }
      assert_equal "gem: posthog-rails", phr&.dig("group"), report["ranked"].map { _1["site"] }.first(10).inspect
      assert_empty report["ranked"].select { _1["site"].start_with?("GEM/lowrail/") }, "the profiler's own lines are not ranked"
      assert_includes report["groups"].map { _1["group"] }, "lowrail-profile"
      assert_in_delta 41.0, core["all"].last, 1.0
      callers = report["rows"].find { _1["site"] == core["site"] }["callers"].map { _1["caller"] }
      # The engine's code, not its dummy app (spec/ is the test suite's).
      assert_equal ["APP/app/lib/engine.rb:2"], callers
      assert_includes report["app_lines"].map { _1["line"] }, "APP/app/lib/engine.rb:2"
      missing = report["unclassified"]
      assert_equal File.join(dir, "loose/loose.rb"), missing["files"].first["path"]
      assert_in_delta 11.0, missing["objects_per_request"], 1.0
      assert_operator missing["share"], :>, 0
      assert_match(/Not attributed: [\d.]+ objects per request \([\d.]+% of all\).*loose\.rb/, File.read(File.join(api, "p/report.md")))
    end
  end

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")

  def profile_env(dir) = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")

  def profile(dir, *args, env: {}) = Open3.capture3(profile_env(dir).merge(env), RUBY, PROFILE, *args, chdir: dir)

  # A request left open in an abandoned fiber is counted in the run's
  # windows but merged into no line or action: the report says so and
  # compare refuses it.
  def test_unfinished_windows_are_not_comparable
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "app/controllers/widgets_controller.rb" => <<~'RUBY',
          class WidgetsController < ApplicationController
            def index = (Fiber.yield if params[:abandon]; render(plain: "ok"))
          end
        RUBY
        "requests.rb" => <<~'RUBY')
          require_relative "config/environment"
          require "rack/mock"
          call = ->(path) { Rails.application.call(Rack::MockRequest.env_for("http://localhost#{path}")) }
          Fiber.new { call.("/widgets?abandon=1") }.resume
          3.times { call.("/widgets") }
        RUBY
      out, err, status = profile(dir, "--out", "profile", "--", RUBY, "requests.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      report = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      assert_equal [[4, 3]] * 2, report["summary"].map { [_1["windows"]["request"], _1["completed"]["request"]] }
      assert_includes out, "left windows unfinished (1 request)"
      out, _, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "profile/report.json", "profile/report.json", "--json", chdir: dir)
      assert_equal 2, status.exitstatus, out
      assert_match(/windows that never finished/, JSON.parse(out)["problems"].join)
    end
  end

  def test_requests_of_controller_tests_are_reported_as_not_counted
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "suite_test.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        require "minitest/autorun"
        class WidgetsControllerTest < ActionController::TestCase
          setup { @routes = Rails.application.routes }
          def test_index = 3.times { get :index; assert_response :success }
        end
        unless ENV["ONLY_CONTROLLER_TESTS"]
          class WidgetsRequestTest < ActiveSupport::TestCase
            def test_index = assert_equal(200, Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))[0])
          end
        end
      RUBY
      env = { "MT_NO_PLUGINS" => "1" }
      out, err, status = profile(dir, "--out", "mixed", "--", RUBY, "suite_test.rb", env: env)
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      report = JSON.parse(File.read(File.join(dir, "mixed/report.json")))
      assert_equal [[1, 3]] * 2, report["summary"].map { [_1["requests"], _1["controller_tests"]] }
      assert_includes File.read(File.join(dir, "mixed/report.md")), "* Not counted in run 1: 3 requests made by controller " \
        "tests (`ActionController::TestCase`, rspec-rails controller specs), which call the controller directly"

      out, err, status = profile(dir, "--out", "only", "--", RUBY, "suite_test.rb", env: env.merge("ONLY_CONTROLLER_TESTS" => "1"))
      refute status.success?, out
      assert_includes err, "are not counted; run 1 made 3 requests from controller tests)"
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

  # Code evaluated from line -1 (Sidekiq's Web views) allocates at lines -1
  # and 0: both count at line 0, not as dropped samples, which compare refuses.
  def test_code_evaluated_at_a_negative_line_is_counted
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "probe.rb"), <<~'RUBY')
        P = Lowrail::Profile
        P.enter(0)
        eval("String.new\nString.new", nil, "view.erb", -1)
        P.leave
        _, _, dropped, rows = P.snapshot
        strings = rows.select { _1[0] == "view.erb" && P::TYPES[_1[2]] == "String" }
        puts "dropped #{dropped} strings #{strings.map { _1.values_at(1, 3) }}"
      RUBY
      out, err, = profile(dir, "--out", "profile", "--runs", "1", "--", RUBY, "probe.rb")
      assert_includes out, "dropped 0 strings [[0, 2]]\n", err
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
          # Rails before 8.1 memoizes Metal's config when Base loads.
          ActionController::Metal.config if ActionController::Metal.respond_to?(:config)
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

  # A child Ruby that sets its own RUBYLIB still loads the profiler, though the
  # checkout's gem is on no gem path: lib travels in RUBYOPT too.
  def test_a_child_with_its_own_rubylib_loads_the_profiler
    realpath_tmpdir do |dir|
      child = 'system({ "RUBYLIB" => "/nonexistent" }, RbConfig.ruby, "-e", ' \
        '"puts defined?(Lowrail::Profile::API) ? :profiler_loaded : :profiler_missing") or exit 9'
      out, err, result = profile(dir, "--runs", "1", "--out", "o", "--", RUBY, "-e", child)
      assert_equal "profiler_loaded\n", out, err
      refute_equal 9, result.exitstatus
    end
  end

  # A process the suite starts (Dawarich's after(:suite) runs rspec again for
  # rswag) sees what it sees in a plain run: the caller's SEED, SPEC_OPTS,
  # RUBYOPT and RUBYLIB, no profiler, also through Bundler.with_original_env
  # and with_unbundled_env. The suite itself runs with the seed and
  # is profiled; a process started before the suite (a rake parent's) is too.
  def test_processes_the_suite_starts_run_as_without_the_profiler
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    rspec = Open3.capture3(CLEAN_ENV, RUBY, "-e", 'require "rspec/core"')[2].success?
    realpath_tmpdir do |dir|
      start = <<~'RUBY'
        # As `bundle exec` saves it, with lowrail-profile's -r: what with_unbundled_env would restore.
        ENV["BUNDLER_ORIG_RUBYOPT"] ||= ENV["RUBYOPT"]
        require_relative "config/environment"
        require "rack/mock"
        require "bundler"
        # Also as an engine or after(:suite) starts another bundle: from Bundler's copy of the environment.
        def child(name)
          run = -> { IO.popen([RbConfig.ruby, "child.rb"], &:read) }
          out = ENV.fetch("OUT")
          File.write("#{out}-#{name}.txt", [run.(), Bundler.with_original_env(&run), Bundler.with_unbundled_env(&run)].join("--\n"))
        end
      RUBY
      LowrailTest.write_rails_app(dir,
        "child.rb" => 'puts ENV.keys.grep(/\ALOWRAIL_PROFILE|\A(?:SEED|SPEC_OPTS|RUBYOPT|RUBYLIB|BUNDLER_ORIG_RUBYOPT)\z/).sort.map { "#{_1}=#{ENV[_1]}" }, ' \
          '"profiler #{defined?(Lowrail::Profile).inspect}"',
        "start.rb" => start,
        "suite_test.rb" => <<~'RUBY',
          require_relative "start"
          require "active_support/test_case"
          require "minitest/autorun"
          class SuiteTest < ActiveSupport::TestCase
            def test_request
              Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
              child("test")
            end
          end
        RUBY
        "suite_spec.rb" => <<~'RUBY')
          require_relative "start"
          RSpec.configure { |c| c.after(:suite) { child("after_suite") } }
          RSpec.describe("widgets") { it("serves") { Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets")) } }
        RUBY
      # MT_NO_PLUGINS: the app is not bundled, so Minitest 5 would load every
      # installed minitest's plugins (a 6.x beside 5.27 replaces it, 0 tests run).
      caller_env = { "SEED" => "99", "SPEC_OPTS" => "--no-color", "RUBYOPT" => "-W0", "RUBYLIB" => File.join(dir, "lib"),
        "MT_NO_PLUGINS" => "1" }
      seen = "RUBYLIB=#{caller_env["RUBYLIB"]}\nRUBYOPT=-W0\nSEED=99\nSPEC_OPTS=--no-color\nprofiler nil\n"
      # Bundler took its copy of the environment before start.rb saved BUNDLER_ORIG_RUBYOPT.
      plain = ["BUNDLER_ORIG_RUBYOPT=-W0\n#{seen}", seen, seen].join("--\n")
      suites = { "minitest" => [[RUBY, "suite_test.rb"], "test", /^1 runs, \d+ assertions, 0 failures, 0 errors/] }
      suites["rspec"] = [[RUBY, "-e", 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)', "suite_spec.rb"], "after_suite", /^1 example, 0 failures/] if rspec
      suites.each do |name, (command, child, ran)|
        out, err, status = Open3.capture3(profile_env(dir).merge(caller_env, "OUT" => "plain-#{name}"), *command, chdir: dir)
        assert status.success?, "#{name} plain: #{status.inspect}\n#{err}\n#{out}"
        assert_match ran, out, "#{name} plain: the suite ran its test"
        out, err, status = profile(dir, "--runs", "1", "--out", "p-#{name}", "--keep-runs", "--", *command, env: caller_env.merge("OUT" => "profiled-#{name}"))
        assert status.success?, "#{name} profiled: #{status.inspect}\n#{err}\n#{out}"
        assert_match ran, out, "#{name} profiled: the suite ran its test"
        assert_match(/lowrail-profile: run 1 of 1/, err, "#{name}: the caller's -W0 does not silence lowrail-profile")
        assert_match(/--seed 1234|Randomized with seed 1234/, out + err, "#{name}: the suite has the seed")
        assert_equal 1, Dir[File.join(dir, "p-#{name}/run1/*.tsv")].size, "#{name}: only the suite's process is profiled"
        assert_equal [plain, plain], %w[plain profiled].map { File.read(File.join(dir, "#{_1}-#{name}-#{child}.txt")) }, name
      end
      skip "rspec-core is not installed: only the minitest suite ran" unless rspec
    end
  end
end
