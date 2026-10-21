# frozen_string_literal: true

# Fixed six-GET vector, shared by cold capture and the shared heap driver.
# Importing this file NEVER starts Callgrind or a measured cohort.
require_relative "fizzy_link_fixture"
require_relative "block_link_specimen"
require_relative "fizzy_link_completion"

module FizzyLinkVector
  module_function

  def pin!(app:, artifact:, contexts:)
    root = File.expand_path("../..", __dir__)
    sha = IO.popen(["git", "-C", root, "rev-parse", "HEAD"], &:read).strip
    dirty = IO.popen(["git", "-C", root, "status", "--porcelain"], &:read)
    branch = IO.popen(["git", "-C", root, "branch", "--show-current"], &:read).strip
    raise "clean detached harness required" unless dirty.empty? && branch.empty? && sha == ENV.fetch("BENCH_HARNESS_SHA")
    {"harness_sha" => sha, "harness_root" => root,
      "app_source_sha256" => BlogProduction::Entropy.source_pin(app),
      "lock_sha256" => Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
      "contexts_sha256" => Digest::SHA256.hexdigest(JSON.generate(contexts)),
      "artifact" => Dir[File.join(artifact, "**/*")].select { File.file?(_1) }.sort.to_h { [_1.delete_prefix(artifact + "/"), Digest::SHA256.file(_1).hexdigest] },
      "native" => Dir[File.join(root, "gem/lib/lowrail/native/**/*.so")].sort.to_h { [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] },
      "sources" => (Dir[File.join(__dir__, "{block_link_*,fizzy_link_*}.rb")] +
        %w[request_pairs heap_windows jit_stability worker_placement].map { File.expand_path("../#{_1}.rb", __dir__) }).sort.to_h { [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] }}
  end

  def effects(state)
    require "sqlite3"
    %w[primary cache queue cable].to_h do |name|
      db = SQLite3::Database.new(File.join(state, "#{name}.sqlite3"), readonly: true)
      begin
        schema = db.execute("SELECT type,name,sql FROM sqlite_master ORDER BY type,name")
        table_list = db.execute("PRAGMA table_list")
        tables = schema.select { _1.first == "table" }.to_h do |_, table, _|
          identifier = '"' + table.gsub('"', '""') + '"'
          without_rowid = table_list.find { _1[0] == "main" && _1[1] == table }.fetch(4) == 1
          order = if without_rowid
            db.execute("PRAGMA table_info(#{identifier})").select { _1[5].positive? }.sort_by { _1[5] }.map { '"' + _1[1].gsub('"', '""') + '"' }.join(",")
          else
            "rowid"
          end
          raise "snapshot order unavailable #{table}" if order.empty?
          [table, BlogProduction.value(db.execute2("SELECT #{without_rowid ? '*' : 'rowid,*'} FROM #{identifier} ORDER BY #{order}"))]
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
      @state, @cookies, @steps, @record, @requests = state, {}, [], record, 0
      @session = Rack::MockRequest.new(Rails.application)
      @headers = {"HTTP_HOST" => "fizzy.example.invalid", "HTTPS" => "on", "HTTP_ORIGIN" => "https://fizzy.example.invalid",
        "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
      @vector = JSON.parse(File.read(File.join(state, "vector.json"))).freeze
      raise "fixed six-request vector required" unless @vector.size == 6
    end

    def request(method, path, params = nil)
      headers = @headers.merge("HTTP_COOKIE" => @cookies.map { |name, value| "#{name}=#{value}" }.join("; "),
        "HTTP_X_REQUEST_ID" => "lowrail-fizzy-link-#{@requests += 1}")
      headers[:params] = params if params
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
    pin = pin!(app: app, artifact: artifact, contexts: manifest)
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    require File.join(app, "config/boot")
    entropy_seed = ENV["BENCH_ENTROPY_SEED"]
    if entropy_seed
      policy_path = ENV.fetch("BENCH_ENTROPY_POLICY")
      control = BlogProduction::Entropy.validate(app, policy: JSON.parse(File.read(policy_path)))
      raise control.fetch("reason") unless control.fetch("active")
      pin["entropy_policy_sha256"] = Digest::SHA256.file(policy_path).hexdigest
      BlogProduction::Entropy.install(control.fetch("policy"))
    end
    BlockLinkSpecimen.install(app: app, artifact: artifact, contexts: manifest, arm: arm, discover: discover)
    require_relative "../../gem/lib/lowrail/verify_loads"
    Lowrail::VerifyLoads.install
    require File.join(app, "config/application")
    app_events = BlogProduction::AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, app_events)
    sql, errors = [], []
    phase = "boot"
    request_thread = Thread.current
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      begin
        binds = payload[:type_casted_binds]
        captured_binds = if Array === binds
          BlogProduction.value(binds)
        elsif payload[:cached] && Proc === binds
          # Never call the lazy Proc or recast query attributes. Compare the
          # real SQL/cache event, explicitly leaving these binds uncovered.
          {"status" => "binds_unavailable", "reason" => "cached_lazy_proc_not_invoked"}
        else
          raise "adapter-produced binds unavailable outside known cached lazy Proc"
        end
        sql << {"phase" => phase, "sql" => BlogProduction.value(payload[:sql]),
          "binds" => captured_binds, "database" => payload[:connection]&.pool&.db_config&.name,
          "name" => BlogProduction.value(payload[:name]), "cached" => !!payload[:cached], "row_count" => payload[:row_count],
          "affected_rows" => payload[:affected_rows], "thread" => Thread.current.equal?(request_thread) ? "request" : "other"}
      rescue StandardError => error
        errors << error.message
      end
    end
    completion = FizzyLinkCompletion305.new(state)
    Rails.error.subscribe(completion)
    Rails.application.config.yjit = false
    require File.join(app, "config/environment")
    raise "production interpreter required" unless Rails.env.production? && Lowrail.jit_mode == "interpreter"
    BlockLinkSpecimen.dependencies!
    Lowrail::VerifyLoads.capture("cold_boot")
    initial = effects(state)
    driver = Driver.new(state)
    app_events.thread = Thread.current
    ledgers = []
    scenario = lambda do
      phase = "login"
      driver.login
      %w[cold warm warm_repeat].each do |stage|
        phase = stage
        start = driver.steps.size
        driver.vector
        Lowrail::VerifyLoads.capture(stage)
        ledgers << {"phase" => stage, "steps" => driver.steps[start..], "specimen" => JSON.parse(JSON.generate(BlockLinkSpecimen.report)),
          "effects" => effects(state)}
      end
    end
    _, entropy = entropy_seed ? BlogProduction::Entropy.with(Integer(entropy_seed), "fizzy-link-six-request-vector",
      requests: 20, wall_clock: true, &scenario) : [scenario.call, nil]
    phase = "post_scenario"
    app_events.thread = nil
    completed = completion.finish
    Lowrail::VerifyLoads.capture("async_completion")
    data = {"pins" => pin, "arm" => arm, "initial_effects" => initial, "steps" => driver.steps,
      "ledgers" => ledgers, "sql" => sql, "events" => app_events.events, "errors" => errors,
      "entropy_seed" => entropy_seed, "entropy" => entropy,
      "completion" => completed, "completed_effects" => completed["status"] == "completed" ? effects(state) : nil,
      "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "features" => $LOADED_FEATURES.dup,
      "ancestry" => %w[Object Kernel BasicObject ActionView::Base ActionView::Template ActionView::OutputBuffer
        ActionView::Helpers::UrlHelper ActionView::Helpers::TagHelper ActionView::Helpers::TagHelper::TagBuilder].to_h do |name|
          holder = Lowrail.loaded_constant(name)
          [name, holder&.ancestors&.map(&:name)]
        end,
      "specimen" => BlockLinkSpecimen.report, "jit" => Lowrail.jit_status,
      "compared_payload_fields" => BlogProduction::AppEvents::FIELDS,
      "coverage_refusals" => ["arbitrary render subscriber payloads/controller assigns are not fully captured",
        "cached lazy SQL-bind Proc values are explicitly unavailable; only SQL text/cache hit compared",
        "source-only prototype has no production passive admission authority"]}
    File.write(destination, JSON.pretty_generate(data), perm: 0o600)
  end

  # Extension point consumed by RequestPairs.heap_instructions(worker: ...).
  # NO caller here launches a cohort; coordinator approval remains required.
  def heap_worker(app, state, artifact, manifest, arm)
    raise "cohort requires separate coordinator approval for this exact pin" unless ENV["BENCH_BLOCK_LINK_COHORT_APPROVED"] == ENV.fetch("BENCH_HARNESS_SHA")
    pin = pin!(app: app, artifact: artifact, contexts: manifest)
    require_relative "../jit_stability"
    require_relative "../heap_windows"
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    raise "one interpreter cohort only" unless JitStability.mode == "interpreter"
    driver = boot(app, state, artifact, manifest, arm)
    JitStability.assert_mode!
    driver.login
    2.times { driver.vector }
    expected_path = ENV.fetch("BENCH_FIZZY_WARM_HITS")
    expected = JSON.parse(File.read(expected_path))
    pin["expected_warm_hits_sha256"] = Digest::SHA256.file(expected_path).hexdigest
    ledgers = []
    workload = lambda do |count, _unit = nil|
      # Fixed per-window bookkeeping is present in N=0 and N=N alike. The
      # actual guards/witness and completed-hit counters remain in the price.
      before = BlockLinkSpecimen.counts.transform_values { _1.fetch("hits", 0) }
      count.times { driver.vector }
      delta = BlockLinkSpecimen.counts.to_h { |site, row| [site, row.fetch("hits", 0) - before.fetch(site, 0)] }
      raise "completed warm site mix changed" unless delta == expected.transform_values { arm == "on" ? _1 * count : 0 }
      ledgers << {vectors: count, completed_hits: delta}
    end
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    anchors = HeapWindows.run(windows, settle: -> { driver.vector }, &workload)
    puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION,
      windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
      ar_installed: 0, pins: pin, specimen: BlockLinkSpecimen.report, vector_size: 6,
      vector_ledgers: ledgers, request_settle: true)}"
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ["VECTOR:fizzy-links"]
    # RequestPairs passes exactly one route argument. A worker receives a
    # pristine, isolated state copy; no cache/database is shared by workers.
    raise "cohort is not approved" unless ENV["BENCH_BLOCK_LINK_COHORT_APPROVED"] == ENV.fetch("BENCH_HARNESS_SHA")
    app = File.realpath(ENV.fetch("BENCH_FIZZY_APP"))
    state = File.join(File.realpath(ENV.fetch("BENCH_STATE_ROOT")), "worker-#{Process.pid}")
    raise "new worker state required" if File.exist?(state)
    FileUtils.cp_r(File.realpath(ENV.fetch("BENCH_STATE_SEED")), state)
    FizzyLinkVector.heap_worker(app, state, File.realpath(ENV.fetch("BENCH_FIZZY_ARTIFACT")),
      JSON.parse(File.read(ENV.fetch("BENCH_FIZZY_CONTEXTS"))), ENV.fetch("BENCH_FIZZY_ARM"))
    exit
  end
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
