# frozen_string_literal: true

# exe/lowrail-profile on the minimal Rails app of test_helper.rb: objects per
# source line inside requests only, warm and repeat-run columns, census-style
# keys, the app line and action that lead to a gem's allocations, and jobs and
# mails counted apart from requests; and what it must never do to the app or
# to the files around it.
#   ruby -Igem/lib -Igem/test gem/test/profile_test.rb

require "test_helper"
require "uri"
require "digest"

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

      # compare: the same report is no regression; one more Probe.many per
      # index request is, for the line and the action.
      compare = ->(*paths) { Open3.capture3(env, RUBY, File.join(GEM_ROOT, "exe/lowrail-profile"), "compare", *paths, "--json", chdir: dir) }
      _, _, status = compare.("profile/report.json", "profile/report.json")
      assert_equal 0, status.exitstatus
      head = JSON.parse(File.read(File.join(dir, "profile/report.json")))
      head["ranked"].find { _1["site"] == "GEM/probe/lib/probe.rb:5" }["warm"].map! { _1 + 50 }
      head["actions"].find { _1["name"] == "WidgetsController#index" }["warm"].map! { _1 + 101 }
      File.write(File.join(dir, "head.json"), JSON.generate(head))
      out, _, status = compare.("profile/report.json", "head.json", "--aa", "profile/report.json")
      assert_equal 1, status.exitstatus
      assert_equal [["action", "WidgetsController#index"], ["line", "GEM/probe/lib/probe.rb:5"]],
        JSON.parse(out)["regressions"].map { [_1["what"], _1["name"]] }.sort

      plain, = Open3.capture3(env, RUBY, "requests.rb", chdir: dir)
      assert_includes plain, "lowrail loaded: false"
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
            def index = (Engine.call; head(:ok))
          end
        RUBY
      { "api/app/lib/engine.rb" => "module Engine\n  def self.call = (Core.many; Loose.many)\nend\n",
        "core/lib/core.rb" => "module Core\n  def self.many = Array.new(40) { String.new }\nend\n",
        "loose/loose.rb" => "module Loose\n  def self.many = Array.new(10) { String.new }\nend\n" }.each do |rel, src|
        FileUtils.mkdir_p(File.dirname(File.join(dir, rel)))
        File.write(File.join(dir, rel), src)
      end
      File.write(File.join(api, "requests.rb"), <<~'RUBY')
        spec = Gem::Specification.new { |s| (s.name, s.version) = "solidus_core", "1.0" }
        spec.full_gem_path = File.expand_path("../core", __dir__)
        Gem.loaded_specs["solidus_core"] = spec
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
  # the app's filter list as it is when the request runs (appended to, or a
  # String in it changed in place, after the first request); with a Proc in
  # the list, which may need Rails' merged params, no value is kept. A GET is
  # recorded as a GET with its Accept (JSON or XML, filtered as Rails filters
  # the env) and query, not as a JSON body.
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
            def lookup = render(json: { method: request.request_method, query: request.query_parameters, body: request.request_parameters,
              accept: request.get_header("HTTP_ACCEPT") })
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
          call.("/lookup?q=xml", "HTTP_ACCEPT" => "application/xml")
          filters = Rails.application.env_config["action_dispatch.parameter_filter"]
          saved = filters.dup
          filters.replace([:accept])
          call.("/lookup?q=safe", "HTTP_ACCEPT" => "application/xml; token=accept-secret")
          filters.replace(saved)
          mutable = +"not_a_key"
          filters.replace([mutable])
          call.("/widgets")
          mutable.replace("credential")
          call.("/widgets.string-format?credential=string-secret")
          filters.replace([/\Aformat\z/, ->(key, value, original) {
            value.replace("[FILTERED]") if key == "credential" && original["controller"] == "widgets"
          }])
          call.("/widgets/1.proc-format-secret?credential=proc-secret")
          call.("/lookup?q=proc", "HTTP_ACCEPT" => "application/xml; token=proc-accept-secret")
        RUBY
      out, err, status = profile(dir, "--out", "profile", "--record", "--", RUBY, "requests.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      recorded = File.read(File.join(dir, "lowrail/workloads.rb"))
      written = [recorded, *Dir[File.join(dir, "profile/**/*")].select { File.file?(_1) }.map { File.read(_1) }]
      %w[format-secret changed-filter-secret string-secret proc-secret accept-secret proc-accept-secret].each do |secret|
        assert written.none? { _1.include?(secret) }, "#{secret} was exported:\n#{recorded}"
      end
      assert_match(/^# get "\/widgets\.\[FILTERED\]"|^# get widgets_path\(format: "\[FILTERED\]"\)/, recorded)
      assert_match(/^# get widget_path\(widget\), .*params: \{"credential" => "\[FILTERED\]"\}$/, recorded)
      # An Accept the filter masks is filtered, so its request is commented out.
      assert_match(/^# get lookup_path, name: "GET \/lookup \(\[FILTERED\]\)", headers: \{ "Accept" => "\[FILTERED\]" \}, params: \{"q" => "safe"\}$/, recorded)
      assert_match(/^# 1 request \(the app's filter_parameters is not only names and patterns \(a Proc\).*\n# get widget_path\(widget\), name: "GET \/widgets\/:id"\n/, recorded)

      check = <<~'RUBY'
        require "./boot"
        require "json"
        require "rack/mock"
        require "lowrail/workloads"
        replays = Lowrail::Workloads.load("lowrail/workloads.rb").requests.select { _1.path.start_with?("/lookup") }.map do |r|
          sent = Lowrail::Workloads::MockClient.new(Rails.application, "localhost").request(r.verb, r.path, params: r.params, headers: r.headers, body: r.body)
          { declared: [r.verb, r.params, r.body, r.headers["HTTP_ACCEPT"]], seen: JSON.parse(sent.body) }
        end
        puts JSON.generate(replays.sort_by { _1[:declared][1]["q"] })
      RUBY
      replay = ruby_json(check, chdir: dir, setup: false, env: { "RAILS_ENV" => "test", "RUBYOPT" => "-I#{GEM_LIB}" })
      assert_equal [["get", { "q" => "needle" }, nil, "application/json"], ["get", { "q" => "xml" }, nil, "application/xml"]],
        replay.map { _1["declared"] }, recorded
      assert_equal [{ "method" => "GET", "query" => { "q" => "needle" }, "body" => {}, "accept" => "application/json" },
        { "method" => "GET", "query" => { "q" => "xml" }, "body" => {}, "accept" => "application/xml" }], replay.map { _1["seen"] }
    end
  end

  # Before Rails 8.1 a request keeps only its route's pattern, controller and
  # action, which overlapping routes share: such a request is not recorded
  # (on 8.1 the matched route itself is kept), and an unambiguous one is.
  def test_record_skips_a_request_whose_route_is_ambiguous
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "config/routes.rb" => <<~'RUBY',
          Rails.application.routes.draw do
            get "/probe(/:id)", to: "widgets#index", as: :first_probe, defaults: { id: "sentinel" }, constraints: { id: /sentinel/ }
            get "/probe(/:id)", to: "widgets#index", as: :second_probe
            get "/plain", to: "widgets#index", as: :plain
          end
        RUBY
        "app/controllers/widgets_controller.rb" => "class WidgetsController < ApplicationController\n  def index = head(:ok)\nend\n",
        "requests.rb" => <<~'RUBY')
          require_relative "config/environment"
          require "rack/mock"
          %w[/probe/7 /plain].each { Rails.application.call(Rack::MockRequest.env_for("http://localhost#{_1}")) }
        RUBY
      out, err, status = profile(dir, "--out", "profile", "--record", "--", RUBY, "requests.rb")
      assert status.success?, "lowrail-profile failed:\n#{err}\n#{out}"
      recorded = File.read(File.join(dir, "lowrail/workloads.rb"))
      assert_match(/^get plain_path/, recorded)
      refute_match(/^get first_probe_path/, recorded)
    end
  end

  # --workloads captures compare by what they measured: two of the same file
  # in different output directories compare, and a block that sends another
  # request in one of them does not, though the file is the same; nor does a
  # capture that stopped before measuring anything, or one with requests its
  # receipt does not cover (a forked child's, an at_exit one).
  def test_workloads_captures_compare_by_what_they_measured
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "bin/rails" => "#!#{RUBY}\nabort unless ARGV.shift == \"runner\"\nscript = ARGV.shift\nrequire_relative \"../config/environment\"\nload script\n",
        "lowrail/workloads.rb" => <<~'RUBY')
          parent = Process.pid
          at_exit { Rails.application.call(Rack::MockRequest.env_for("https://localhost/widgets?after=1")) } if ENV["AFTER"]
          get("/widgets", name: "variant") do |n|
            exit(0) if n == 2 && ENV["STOP"]
            if n == 11 && ENV["FORK"] && (pid = fork) then Process.wait(pid) end
            exit(0) if n == 12 && Process.pid != parent
            { path: ENV.fetch("REPLAY_PATH") }
          end
        RUBY
      File.chmod(0o755, File.join(dir, "bin/rails"))
      flags = { "stopped" => "STOP", "forked" => "FORK", "after" => "AFTER" }
      { "base" => "/widgets?v=1", "head" => "/widgets?v=1", "other" => "/widgets?v=2" }.merge(flags.transform_values { "/widgets?v=1" }).each do |out, path|
        _, err, status = profile(dir, "--out", out, "--workloads", env: { "REPLAY_PATH" => path, **(flags[out] ? { flags[out] => "1" } : {}) })
        assert status.success?, err
      end
      compare = ->(a, b) { Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "#{a}/report.json", "#{b}/report.json", "--json", chdir: dir) }
      out, err, status = compare.("base", "head")
      assert_equal 0, status.exitstatus, "#{out}\n#{err}"
      out, _, status = compare.("base", "other")
      assert_equal 2, status.exitstatus, out
      assert_match(/differ in identity/, JSON.parse(out)["problems"].join)
      out, _, status = compare.("stopped", "stopped")
      assert_equal 2, status.exitstatus, out
      assert_match(/finished measuring at least one request/, JSON.parse(out)["problems"].join)
      # A forked child's or an at_exit request is a window the receipt does not cover.
      %w[forked after].each do |capture|
        out, _, status = compare.(capture, capture)
        assert_equal 2, status.exitstatus, out
        assert_match(/not the one process's measured requests/, JSON.parse(out)["problems"].join)
      end
      # A report whose rows were emptied still claims its completed requests.
      hollow = JSON.parse(File.read(File.join(dir, "head/report.json"))).merge("ranked" => [], "actions" => [])
      File.write(File.join(dir, "hollow.json"), JSON.generate(hollow))
      out, _, status = Open3.capture3(CLEAN_ENV, RUBY, PROFILE, "compare", "base/report.json", "hollow.json", "--json", chdir: dir)
      assert_equal 2, status.exitstatus, out
      assert_match(%r{head's request actions add up to 0 / 0 windows, its summary to 20 / 20 completed}, JSON.parse(out)["problems"].join)
    end
  end

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

  # The CLI exits with the command's status: the first failed run's, a
  # signal as 128 + its number, also when no report can be made or --record
  # cannot write; capture.json records the same numbers. A passing command
  # whose --record cannot write exits 1.
  def test_a_failed_command_fails_the_profile
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
        run = File.basename(ENV.fetch("LOWRAIL_PROFILE"))
        case ENV.fetch("END")
        when "exit" then exit 7
        when "signal" then Process.kill("TERM", Process.pid); sleep 5
        when "first" then exit(run == "run1" ? 3 : 4)
        end
      RUBY
      { "exit" => [7, [7, 7]], "signal" => [143, [143, 143]], "first" => [3, [3, 4]] }.each do |ending, (status, exits)|
        out, err, result = profile(dir, "--out", ending, "--", RUBY, "requests.rb", env: { "END" => ending })
        assert_equal status, result.exitstatus, "#{ending}: #{err}"
        assert_includes out, "# lowrail-profile report", "#{ending}: the report is still written"
        assert_equal exits, JSON.parse(File.read(File.join(dir, ending, "capture.json")))["exit"]
      end
      _, err, result = profile(dir, "--out", "none", "--", RUBY, "-e", "exit 5")
      assert_equal 5, result.exitstatus, err
      assert_match(/no report/, err)
      FileUtils.mkdir_p(File.join(dir, "taken.rb"))
      { "pass" => 1, "exit" => 7 }.each do |ending, status|
        _, err, result = profile(dir, "--out", "record-#{ending}", "--record", "taken.rb", "--", RUBY, "requests.rb", env: { "END" => ending })
        assert_equal status, result.exitstatus, "--record cannot write after #{ending}: #{err}"
        assert_match(/lowrail-profile: --record: .*taken\.rb/, err)
      end
    end
  end

  # The app tree after a profile (default --out) is the tree before, but
  # tmp/lowrail-profile: no Gemfile, config or code is written.
  def test_profiling_leaves_the_app_tree_unchanged
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      app = File.join(dir, "app")
      LowrailTest.write_rails_app(app, "requests.rb" => <<~'RUBY')
        require_relative "config/environment"
        require "rack/mock"
        Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
      RUBY
      tree = -> { Dir.glob("**/*", File::FNM_DOTMATCH, base: app).reject { _1 == "tmp" || _1.start_with?("tmp/lowrail-profile") }.sort.to_h { [_1, File.file?(File.join(app, _1)) ? Digest::SHA256.file(File.join(app, _1)).hexdigest : :dir] } }
      before = tree.()
      _, err, status = Open3.capture3(profile_env(dir), RUBY, PROFILE, "--", RUBY, "requests.rb", chdir: app)
      assert status.success?, err
      assert File.file?(File.join(app, "tmp/lowrail-profile/report.json"))
      assert_equal before, tree.()
    end
  end

  # --workloads without --allow-writes sends only GETs: a write, a POST
  # sign-in, setup code or a GET with jobs: is refused before any request.
  def test_workloads_refuse_writes_without_allow_writes
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "bin/rails" => "#!#{RUBY}\nabort unless ARGV.shift == \"runner\"\nscript = ARGV.shift\nrequire_relative \"../config/environment\"\nload script\n",
        "config/routes.rb" => "Rails.application.routes.draw { resources :widgets, only: %i[index create] }\n",
        "config/initializers/override.rb" => "Rails.application.config.middleware.delete(Rack::MethodOverride) if ENV[\"NO_OVERRIDE\"]\n",
        "app/controllers/widgets_controller.rb" => <<~'RUBY')
          class WidgetsController < ApplicationController
            skip_forgery_protection
            def index = render(plain: Widget.count.to_s)
            def create = (Widget.create!(name: "w", password: "x"); head(:created))
          end
        RUBY
      File.chmod(0o755, File.join(dir, "bin/rails"))
      FileUtils.mkdir_p(File.join(dir, "lowrail"))
      {
        "post \"/widgets\"" => /POST \/widgets is a write/,
        "sign_in \"/session\", params: {}" => /sign_in POST \/session is a write/,
        "setup { Widget.delete_all }" => /setup runs code/,
        "get \"/widgets\", jobs: true" => /has jobs:/,
        # A GET whose env: or missing Rack::MethodOverride sends a POST.
        "get \"/widgets\", name: \"probe\", env: { \"REQUEST_METHOD\" => \"POST\" }, expect: [200, 201]" => /GET \/widgets is sent as POST/,
        "get \"/widgets\", name: \"probe\", as: :json, params: { q: 1 }, expect: [200, 201] # no override" => /GET \/widgets is sent as POST/
      }.each do |line, refusal|
        File.write(File.join(dir, "lowrail/workloads.rb"), "get \"/widgets\"\n#{line}\n")
        _, err, status = profile(dir, "--out", "w", "--workloads", env: line.end_with?("no override") ? { "NO_OVERRIDE" => "1" } : {})
        refute status.success?, line
        assert_match(refusal, err)
        assert_match(/needs --allow-writes/, err)
        refute_match(/run 2 of 2/, err, "a refused file is not run again")
      end
      # Each refused file sent nothing; the same JSON GET with the override is a GET.
      File.write(File.join(dir, "lowrail/workloads.rb"), "get \"/widgets\", as: :json, params: { q: 1 }\n")
      _, err, status = profile(dir, "--out", "w", "--workloads")
      assert status.success?, err
      names = JSON.parse(File.read(File.join(dir, "w/report.json")))["actions"].map { _1["name"] }
      assert_includes names, "WidgetsController#index"
      refute_includes names, "WidgetsController#create"
      # With --allow-writes the env: POST is sent as declared.
      File.write(File.join(dir, "lowrail/workloads.rb"), "get \"/widgets\", env: { \"REQUEST_METHOD\" => \"POST\" }, expect: 201\n")
      _, err, status = profile(dir, "--out", "w", "--workloads", "--allow-writes")
      assert status.success?, err
      assert_equal [20, 20], JSON.parse(File.read(File.join(dir, "w/report.json")))["actions"]
        .find { _1["name"] == "WidgetsController#create" }["windows"]
      File.write(File.join(dir, "lowrail/workloads.rb"), "get \"/widgets\"\npost \"/widgets\", expect: 201\n")
      _, err, status = profile(dir, "--out", "w", "--workloads", "--allow-writes")
      assert status.success?, err
      # Counted passes only (warmup is reset): 20 per run.
      assert_equal [20, 20], JSON.parse(File.read(File.join(dir, "w/report.json")))["actions"]
        .find { _1["name"] == "WidgetsController#create" }["windows"]
      _, err, status = profile(dir, "--allow-writes", "--", RUBY, "-e", "1")
      refute status.success?
      assert_match(/--allow-writes is for --workloads/, err)
    end
  end

  # In production, a writable database on another machine refuses --workloads
  # before the file runs: also one with database_tasks: false (configs_for hides
  # it), not a replica, whether or not Active Record is loaded yet (it is not
  # loaded for this), and a configuration that does not load is no answer.
  def test_workloads_refuse_a_remote_production_database
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        "bin/rails" => "#!#{RUBY}\nabort unless ARGV.shift == \"runner\"\nscript = ARGV.shift\nrequire_relative \"../config/environment\"\nload script\n",
        "config/environment.rb" => <<~'RUBY',
          require "logger"
          require "rails"
          require "active_record/railtie"
          require "action_controller/railtie"
          class FixtureApp < Rails::Application
            config.root = File.expand_path("..", __dir__)
            config.eager_load = false
            config.logger = Logger.new(nil)
            config.secret_key_base = "x" * 64
            config.active_support.deprecation = :silence
          end
          Rails.application.initialize!
          ActiveRecord::Base if ENV["LOAD_BASE"]
        RUBY
        "lowrail/workloads.rb" => "warn(ActiveRecord.autoload?(:Base) ? \"BASE UNLOADED\" : \"BASE LOADED\")\nabort \"EVALUATED\"\n")
      File.chmod(0o755, File.join(dir, "bin/rails"))
      secondary = ->(extra) { "production:\n  primary:\n    adapter: sqlite3\n    database: \":memory:\"\n  analytics:\n" \
        "    adapter: postgresql\n    host: db.example.invalid\n    database: analytics\n    #{extra}\n" }
      [nil, "1"].each do |load_base|
        env = { "RAILS_ENV" => "production", "LOAD_BASE" => load_base }
        File.write(File.join(dir, "config/database.yml"), secondary.("database_tasks: false"))
        _, err, status = profile(dir, "--out", "w", "--workloads", env: env)
        refute status.success?
        assert_match(/database on db\.example\.invalid; --workloads sends real requests, so it needs --allow-writes there/, err)
        refute_match(/EVALUATED/, err, "refused before the file runs (LOAD_BASE=#{load_base.inspect})")
        File.write(File.join(dir, "config/database.yml"), secondary.("replica: true"))
        _, err, = profile(dir, "--out", "w", "--workloads", env: env)
        assert_match(/EVALUATED/, err, "a replica takes no writes")
        assert_match(load_base ? /BASE LOADED/ : /BASE UNLOADED/, err)
      end
      File.write(File.join(dir, "config/database.yml"), "production:\n  adapter: <%= raise \"no secret\" %>\n")
      _, err, status = profile(dir, "--out", "w", "--workloads", env: { "RAILS_ENV" => "production" })
      refute status.success?
      assert_match(/database configuration did not load \(.*no secret\)/m, err)
      refute_match(/EVALUATED/, err)
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
  # RUBYOPT and RUBYLIB, no profiler. The suite itself runs with the seed and
  # is profiled; a process started before the suite (a rake parent's) is too.
  def test_processes_the_suite_starts_run_as_without_the_profiler
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    rspec = Open3.capture3(CLEAN_ENV, RUBY, "-e", 'require "rspec/core"')[2].success?
    realpath_tmpdir do |dir|
      start = <<~'RUBY'
        require_relative "config/environment"
        require "rack/mock"
        def child(name)
          File.write("#{ENV.fetch("OUT")}-#{name}.txt", IO.popen([RbConfig.ruby, "child.rb"], &:read))
        end
      RUBY
      LowrailTest.write_rails_app(dir,
        "child.rb" => 'puts ENV.keys.grep(/\ALOWRAIL_PROFILE|\A(?:SEED|SPEC_OPTS|RUBYOPT|RUBYLIB)\z/).sort.map { "#{_1}=#{ENV[_1]}" }, ' \
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
      caller_env = { "SEED" => "99", "SPEC_OPTS" => "--no-color", "RUBYOPT" => "-W0", "RUBYLIB" => File.join(dir, "lib") }
      plain = "RUBYLIB=#{caller_env["RUBYLIB"]}\nRUBYOPT=-W0\nSEED=99\nSPEC_OPTS=--no-color\nprofiler nil\n"
      suites = { "minitest" => [[RUBY, "suite_test.rb"], "test"] }
      suites["rspec"] = [[RUBY, "-e", 'require "rspec/core"; exit RSpec::Core::Runner.run(ARGV)', "suite_spec.rb"], "after_suite"] if rspec
      suites.each do |name, (command, child)|
        _, err, status = Open3.capture3(profile_env(dir).merge(caller_env, "OUT" => "plain-#{name}"), *command, chdir: dir)
        assert status.success?, err
        out, err, status = profile(dir, "--runs", "1", "--out", "p-#{name}", "--", *command, env: caller_env.merge("OUT" => "profiled-#{name}"))
        assert status.success?, err
        assert_match(/--seed 1234|Randomized with seed 1234/, out + err, "#{name}: the suite has the seed")
        assert_equal 1, Dir[File.join(dir, "p-#{name}/run1/*.tsv")].size, "#{name}: only the suite's process is profiled"
        assert_equal [plain, plain], %w[plain profiled].map { File.read(File.join(dir, "#{_1}-#{name}-#{child}.txt")) }, name
      end
      skip "rspec-core is not installed: only the minitest suite ran" unless rspec
    end
  end

  # Everything after the first -- is the command's, a second -- and
  # profiler-looking flags included.
  def test_arguments_after_the_separator_belong_to_the_command
    realpath_tmpdir do |dir|
      out, err, = profile(dir, "--out", "profile", "--runs", "1", "--", RUBY, "-e", "p ARGV", "--", "--workloads", "--out", "x")
      assert_equal "[\"--workloads\", \"--out\", \"x\"]\n", out, err
      assert_match(/no report: no runs with requests/, err)
      assert_match(/controller tests and controller specs call the controller directly and are not counted/, err)
    end
  end
end
