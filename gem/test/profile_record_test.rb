# frozen_string_literal: true

# lowrail-profile --record and --workloads: the suite's requests written as a
# workloads file that replays, request values kept as data and secrets
# filtered, the app's own results unchanged while recording, captures that
# compare by what they measured, and the writes and production databases
# --workloads refuses.
#   ruby -Igem/lib -Igem/test gem/test/profile_record_test.rb

require "test_helper"
require "uri"

class ProfileRecordTest < Minitest::Test
  include LowrailTest

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")

  def profile_env(dir) = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test")

  def profile(dir, *args, env: {}) = Open3.capture3(profile_env(dir).merge(env), RUBY, PROFILE, *args, chdir: dir)

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
end
