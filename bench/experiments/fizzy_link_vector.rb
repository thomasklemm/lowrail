# frozen_string_literal: true

# Fixed six-GET vector, shared by cold capture and the shared heap driver.
# Importing this file NEVER starts Callgrind or a measured cohort.
require_relative "fizzy_link_fixture"
require_relative "block_link_specimen"
require_relative "../../fixtures/corpus/blog_production"

module FizzyLinkVector
  module_function

  def pin!
    root = File.expand_path("../..", __dir__)
    sha = IO.popen(["git", "-C", root, "rev-parse", "HEAD"], &:read).strip
    dirty = IO.popen(["git", "-C", root, "status", "--porcelain"], &:read)
    branch = IO.popen(["git", "-C", root, "branch", "--show-current"], &:read).strip
    raise "clean detached harness required" unless dirty.empty? && branch.empty? && sha == ENV.fetch("BENCH_HARNESS_SHA")
    {"harness_sha" => sha, "harness_root" => root,
      "sources" => Dir[File.join(__dir__, "{block_link_*,fizzy_link_*}.rb")].sort.to_h { [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] }}
  end

  def effects(state)
    require "sqlite3"
    %w[primary cache queue cable].to_h do |name|
      db = SQLite3::Database.new(File.join(state, "#{name}.sqlite3"), readonly: true)
      begin
        schema = db.execute("SELECT type,name,sql FROM sqlite_master ORDER BY type,name")
        tables = schema.select { _1.first == "table" }.to_h do |_, table, _|
          identifier = '"' + table.gsub('"', '""') + '"'
          [table, BlogProduction.value(db.execute2("SELECT * FROM #{identifier} ORDER BY rowid"))]
        end
        [name, {"schema" => BlogProduction.value(schema), "tables" => tables}]
      ensure
        db.close
      end
    end
  end

  class Driver
    attr_reader :steps

    def initialize(state, record: true)
      require "rack/mock"
      require "cgi"
      @state, @cookies, @steps, @record = state, {}, [], record
      @session = Rack::MockRequest.new(Rails.application)
      @headers = {"HTTP_HOST" => "fizzy.example.invalid", "HTTPS" => "on", "HTTP_ORIGIN" => "https://fizzy.example.invalid",
        "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
      @vector = JSON.parse(File.read(File.join(state, "vector.json"))).freeze
      raise "fixed six-request vector required" unless @vector.size == 6
    end

    def request(method, path, params = nil)
      headers = @headers.merge("HTTP_COOKIE" => @cookies.map { |name, value| "#{name}=#{value}" }.join("; "))
      headers["params"] = params if params
      response = @session.request(method, path, headers)
      Array(response.headers["set-cookie"]).each do |cookie|
        name, value = cookie.split(";", 2).first.split("=", 2)
        @cookies[name] = value
      end
      @steps << {"method" => method, "path" => path, "status" => response.status,
        "headers" => BlogProduction.value(response.headers.to_h), "body" => BlogProduction.value(response.body)} if @record
      response
    end

    def login
      response = request("GET", "/session/new")
      raise "sign-in page failed" unless response.status == 200
      token = response.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "natural CSRF absent"
      response = request("POST", "/session", JSON.parse(File.read(File.join(@state, "login.json"))).merge("authenticity_token" => CGI.unescapeHTML(token)))
      raise "natural sign-in failed" unless response.status == 302 && @cookies.key?("session_token")
    end

    def vector
      @vector.each { |path| raise "GET failed #{path}" unless request("GET", path).status == 200 }
    end
  end

  def boot(app, state, artifact, manifest, arm, discover: false)
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    require File.join(app, "config/boot")
    BlockLinkSpecimen.install(app: app, artifact: artifact, contexts: manifest, arm: arm, discover: discover)
    FizzyLinkFixture.boot(app)
    BlockLinkSpecimen.dependencies!
    Driver.new(state, record: false)
  end

  def cold(app, state, artifact, manifest, arm, destination, discover: false)
    pin = pin!
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    require File.join(app, "config/boot")
    BlockLinkSpecimen.install(app: app, artifact: artifact, contexts: manifest, arm: arm, discover: discover)
    require_relative "../../gem/lib/lowrail/verify_loads"
    Lowrail::VerifyLoads.install
    require File.join(app, "config/application")
    app_events = BlogProduction::AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, app_events)
    sql, errors = [], []
    phase = "boot"
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      begin
        raise "adapter-produced binds unavailable" unless Array === payload[:type_casted_binds]
        sql << {"phase" => phase, "sql" => BlogProduction.value(payload[:sql]),
          "binds" => BlogProduction.value(payload[:type_casted_binds]), "database" => payload[:connection]&.pool&.db_config&.name,
          "name" => BlogProduction.value(payload[:name]), "cached" => !!payload[:cached], "row_count" => payload[:row_count],
          "affected_rows" => payload[:affected_rows], "thread" => Thread.current.name}
      rescue StandardError => error
        errors << error.message
      end
    end
    completion = BlogProduction::Completion.new
    Rails.error.subscribe(completion)
    Rails.application.config.yjit = false
    require File.join(app, "config/environment")
    raise "production interpreter required" unless Rails.env.production? && Lowrail.jit_mode == "interpreter"
    BlockLinkSpecimen.dependencies!
    Lowrail::VerifyLoads.capture("cold_boot")
    initial = effects(state)
    driver = Driver.new(state)
    app_events.thread = Thread.current
    phase = "login"
    driver.login
    ledgers = []
    %w[cold warm warm_repeat].each do |stage|
      phase = stage
      start = driver.steps.size
      driver.vector
      Lowrail::VerifyLoads.capture(stage)
      ledgers << {"phase" => stage, "steps" => driver.steps[start..], "specimen" => JSON.parse(JSON.generate(BlockLinkSpecimen.report)),
        "effects" => effects(state)}
    end
    phase = "post_scenario"
    app_events.thread = nil
    completed = completion.finish
    Lowrail::VerifyLoads.capture("async_completion")
    data = {"pins" => pin, "arm" => arm, "initial_effects" => initial, "steps" => driver.steps,
      "ledgers" => ledgers, "sql" => sql, "events" => app_events.events, "errors" => errors,
      "completion" => completed, "completed_effects" => completed["status"] == "completed" ? effects(state) : nil,
      "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "features" => $LOADED_FEATURES.dup,
      "ancestry" => %w[Object Kernel BasicObject ActionView::Base ActionView::Template ActionView::OutputBuffer
        ActionView::Helpers::UrlHelper ActionView::Helpers::TagHelper ActionView::Helpers::TagHelper::TagBuilder].to_h do |name|
          holder = Lowrail.loaded_constant(name)
          [name, holder&.ancestors&.map(&:name)]
        end,
      "specimen" => BlockLinkSpecimen.report, "jit" => Lowrail.jit_status,
      "coverage_refusals" => ["arbitrary render subscriber payloads/controller assigns are not fully captured",
        "source-only prototype has no production passive admission authority"]}
    File.write(destination, JSON.pretty_generate(data), perm: 0o600)
  end

  # Extension point consumed by RequestPairs.heap_instructions(worker: ...).
  # NO caller here launches a cohort; coordinator approval remains required.
  def heap_worker(app, state, artifact, manifest, arm)
    pin = pin!
    require_relative "../jit_stability"
    require_relative "../heap_windows"
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    raise "one interpreter cohort only" unless JitStability.mode == "interpreter"
    driver = boot(app, state, artifact, manifest, arm)
    JitStability.assert_mode!
    driver.login
    2.times { driver.vector }
    workload = ->(count, _unit = nil) { count.times { driver.vector } }
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    anchors = HeapWindows.run(windows, settle: -> { driver.vector }, &workload)
    puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION,
      windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
      ar_installed: 0, pins: pin, specimen: BlockLinkSpecimen.report, vector_size: 6, request_settle: true)}"
  end
end

if $PROGRAM_NAME == __FILE__
  mode, app, state, artifact, manifest_path, arm, destination = ARGV
  abort "usage: fizzy_link_vector.rb cold|discover|heap APP STATE ARTIFACT CONTEXTS_JSON ARM [DESTINATION]" unless
    %w[cold discover heap].include?(mode) && arm
  manifest = JSON.parse(File.read(manifest_path))
  app, state, artifact = [app, state, artifact].map { File.realpath(_1) }
  if mode == "heap"
    FizzyLinkVector.heap_worker(app, state, artifact, manifest, arm)
  else
    FizzyLinkVector.cold(app, state, artifact, manifest, arm, destination, discover: mode == "discover")
  end
end
