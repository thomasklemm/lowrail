# frozen_string_literal: true

require "json"
require "base64"
require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "yaml"
require_relative "blog_entropy"

# A bounded, untimed production Rack-boundary experiment, not a replacement
# for lowrail verify or a whole-suite/SEAL001–009 certificate. No test runtime.
# Raw workers are untouched; explicit entropy companions are separate workers.
module BlogProduction
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "script/blog-production-verify")
  SCENARIOS = [
    {"id" => "ArticlesControllerTest#test_should_get_index", "path" => "/articles"},
    {"id" => "ArticlesControllerTest#test_should_show_article", "path" => "/articles/1"}
  ].freeze
  DATABASES = %w[production production_cache production_queue production_cable].freeze

  # Untimed cold-activation witness, shared by all workers. Observe actual
  # executions, including callbacks registered after boot; do not replay hooks.
  module ColdHooks
    def with_execution_control(name, block, once)
      super do
        path, line = block.source_location
        unless path&.start_with?(File.join(ROOT, "gem/lib/lowrail"))
          BlogProduction.cold_hooks << [name.to_s, path, line]
        end
        yield
      end
    end
  end

  def self.cold_hooks = @cold_hooks ||= []

  def self.cold_features
    {"api_loaded" => !!Lowrail.loaded_constant("ActionController::API"),
      "objspace" => $LOADED_FEATURES.grep(%r{/(?:objspace\.rb|objspace\.(?:so|bundle))\z})}
  end

  # Event names/order and these scalar payload fields only, not full arbitrary
  # subscriber payload equivalence (request objects, durations, allocations).
  class AppEvents
    FIELDS = %i[controller action method path format status identifier layout count cache_hits].freeze
    attr_accessor :thread
    attr_reader :events

    def initialize
      @events = []
    end

    def start(name, _id, payload)
      record("start", name, payload)
    end

    def finish(name, _id, payload)
      record("finish", name, payload)
    end

    def record(phase, name, payload)
      return unless thread
      fields = payload.select { |key, _| FIELDS.include?(key) }.to_h do |key, entry|
        [key.to_s, entry.is_a?(Symbol) ? {"symbol" => entry.name} : BlogProduction.value(entry)]
      end
      events << {"phase" => phase, "name" => name, "payload" => fields,
        "thread" => Thread.current.equal?(thread) ? "request" : "other"}
    end
  end

  # Preserve bytes AND encoding; no timestamp, token, ID or bind normalization.
  # Unknown SQL value types are a capture failure, never inspect/to_s guesses.
  def self.value(item)
    case item
    when String
      {"type" => "String", "encoding" => item.encoding.name, "base64" => Base64.strict_encode64(item)}
    when Float
      {"type" => "Float", "bits" => [item].pack("G").unpack1("H*")}
    when Integer, TrueClass, FalseClass, NilClass
      {"type" => item.class.name, "value" => item}
    when Array
      item.map { value(_1) }
    when Hash
      item.to_h { |key, entry| [key, value(entry)] }
    else
      raise "uncapturable value: #{item.class}"
    end
  end

  def self.effects
    require "sqlite3"
    databases = DATABASES.to_h do |name|
      file = "storage/#{name}.sqlite3"
      raise "missing effects database #{file}" unless File.file?(file)
      db = SQLite3::Database.new(file, readonly: true)
      begin
        schema = db.execute("SELECT type, name, sql FROM sqlite_master ORDER BY type, name")
        tables = schema.select { _1.first == "table" }.to_h do |_, table, _|
          # The blog schemas have ordinary rowid tables, including sequences.
          identifier = '"' + table.gsub('"', '""') + '"'
          [table, value(db.execute2("SELECT * FROM #{identifier} ORDER BY rowid"))]
        end
        [name, {"schema" => value(schema), "tables" => tables}]
      ensure
        db.close
      end
    end
    files = Dir.glob("storage/**/*", File::FNM_DOTMATCH).select { File.file?(_1) && !_1.match?(/\.sqlite3(?:-wal|-shm)?\z/) }
    {"databases" => databases, "storage_files" => files.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }}
  end

  def self.worker(phase, destination, entropy_seed = nil)
    control = Entropy.validate(Dir.pwd) if phase == "entropy-pin" || entropy_seed
    if phase == "entropy-pin"
      File.write(destination, JSON.pretty_generate(control))
      return
    end
    raise control.fetch("reason") if control && !control.fetch("active")
    Entropy.install(control.fetch("policy")) if control
    require "lowrail/verify_loads"
    Lowrail::VerifyLoads.install
    require File.expand_path("config/application")
    events, boot_events, errors = [], [], []
    callbacks = []
    ActiveSupport::LazyLoadHooks.prepend(ColdHooks)
    ActiveSupport.on_load(:before_eager_load, yield: true) { |app| callbacks << ["early_eager", app.class.name] }
    ActiveSupport.on_load(:action_controller) { callbacks << ["early_controller", name] }
    app_events = AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, app_events)
    request_thread = nil
    # Register before initialize!/the seal, without referencing an AR target.
    # Rails has already computed this exact array for the adapter. Do not call
    # value_for_database again, or evaluate the lazy Proc used by cached SQL.
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      begin
        binds = payload[:type_casted_binds]
        raise "unavailable adapter bind values (#{binds.class})" unless Array === binds
        (request_thread ? events : boot_events) << {"sql" => value(payload.fetch(:sql)), "binds" => value(binds),
          "database" => payload[:connection]&.pool&.db_config&.name,
          "name" => value(payload[:name]), "cached" => !!payload[:cached],
          "row_count" => payload[:row_count], "affected_rows" => payload[:affected_rows],
          "thread" => Thread.current.equal?(request_thread) ? "request" : "other"}
      rescue StandardError => error
        errors << "SQL capture: #{error.message}"
      end
    end
    require File.expand_path("config/environment")
    raise "production/YJIT required" unless Rails.env.production? && Lowrail.jit_mode == "yjit"
    if phase == "prepare"
      ActiveRecord::Schema.verbose = false
      DATABASES.zip(%w[schema cache_schema queue_schema cable_schema], %w[primary cache queue cable]).each do |_, schema, connection|
        ActiveRecord::Base.establish_connection(connection.to_sym)
        load "db/#{schema}.rb"
      end
      ActiveRecord::Base.establish_connection(:primary)
      articles = YAML.safe_load_file("test/fixtures/articles.yml")
      comments = YAML.safe_load_file("test/fixtures/comments.yml")
      # Committed fixture inputs, not clock/random stubs; callbacks/jobs are
      # deliberately not part of state preparation or these two GET scenarios.
      stamp = Time.utc(2026, 1, 1)
      articles.each_with_index do |(key, attrs), index|
        Article.insert_all!([attrs.merge("id" => index + 1, "created_at" => stamp, "updated_at" => stamp)])
        Comment.insert_all!([comments.fetch(key).reject { _1 == "article" }.merge("id" => index + 1,
          "article_id" => index + 1, "created_at" => stamp, "updated_at" => stamp)])
      end
      ActiveRecord::Base.connection_handler.connection_pool_list.each(&:disconnect!)
      File.write(destination, JSON.pretty_generate(effects))
      return
    end
    require "rack/mock"
    ActiveSupport.on_load(:before_eager_load, yield: true) { |app| callbacks << ["late_eager", app.class.name] }
    ActiveSupport.on_load(:action_controller) { callbacks << ["late_controller", name] }
    cold_witness = {"hooks" => cold_hooks.dup, "callbacks" => callbacks.dup, "features" => cold_features}
    Lowrail::VerifyLoads.capture("cold_boot")
    initial = effects
    responses = SCENARIOS.map do |scenario|
      events.clear
      app_events.events.clear
      Lowrail::Stats.reset_counts! if defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
      request_thread = Thread.current
      app_events.thread = request_thread
      request = -> { Rack::MockRequest.new(Rails.application).get(scenario.fetch("path"),
        "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => scenario.fetch("id")) }
      response, entropy = entropy_seed ? Entropy.with(Integer(entropy_seed), scenario.fetch("id"), &request) : [request.call, nil]
      request_thread = nil
      app_events.thread = nil
      errors.concat(entropy.fetch("errors")) if entropy
      Lowrail::VerifyLoads.capture(scenario.fetch("id"))
      {"id" => scenario.fetch("id"), "response" => {"status" => response.status,
        "headers" => value(response.headers.to_h), "body" => value(response.body)},
        "sql" => events.dup, "events" => app_events.events.dup, "effects" => effects,
        "entropy_trace" => entropy&.fetch("trace"), "clock_observations" => entropy&.fetch("clock_reads"),
        "hits" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_hits : {},
        "fallbacks" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_fallbacks : {}}
    end
    refusals = %w[Lowrail::Sealed Lowrail::FormScaffold].to_h do |name|
      mod = Lowrail.loaded_constant(name)
      [name, mod&.refusal]
    end
    form = Lowrail.loaded_constant("Lowrail::FormScaffold")
    File.write(destination, JSON.pretty_generate({"initial_effects" => initial, "scenarios" => responses,
      "boot_sql" => boot_events, "cold_witness" => cold_witness.merge("after_requests" => cold_features),
      "unit_refusals" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.snapshot.fetch("unit_refusals") : {},
      "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "features" => $LOADED_FEATURES.reject { _1.start_with?(File.join(ROOT, "gem/lib/lowrail")) },
      "entropy_seed" => entropy_seed && Integer(entropy_seed), "entropy_control" => control,
      "jit" => Lowrail.jit_status, "refusals" => refusals.merge("artifact" => Lowrail.refusal_reason,
        "form_input" => form&.input_refusal), "errors" => errors}))
  end

  # Public report contract. A failing off/off control prevents attribution to
  # Lowrail even when off/on differs. Zero hits cannot be sealed coverage.
  def self.compare(runs)
    raise "three workers required" unless runs.size == 3
    raise "missing/reordered scenarios" unless runs.all? { |run| run.fetch("scenarios").map { _1.fetch("id") } == SCENARIOS.map { _1.fetch("id") } }
    differences = %w[off_control off_on].zip([runs[1], runs[2]]).to_h do |label, other|
      baseline = runs.fetch(0)
      mismatches = []
      %w[initial_effects loads features boot_sql cold_witness].each { mismatches << _1 unless baseline.fetch(_1) == other.fetch(_1) }
      baseline.fetch("scenarios").zip(other.fetch("scenarios")).each do |left, right|
        %w[response sql effects events entropy_trace].each do |field|
          mismatches << "#{left.fetch('id')}:#{field}" unless left.fetch(field) == right.fetch(field)
        end
      end
      [label, mismatches]
    end
    errors = runs.flat_map { _1.fetch("errors") + _1.fetch("loads").values.flat_map { |stage| stage.fetch("errors", []) } }
    hit_units = runs.fetch(2).fetch("scenarios").flat_map { _1.fetch("hits").select { |_, count| count.positive? }.keys }.uniq.sort
    status = if differences.fetch("off_control").any?
      "rejected_off_control"
    elsif errors.any? || differences.fetch("off_on").any?
      "rejected"
    elsif hit_units.empty?
      "unexercised"
    else
      "equivalent_for_executed_scenarios"
    end
    {"status" => status, "differences" => differences, "capture_errors" => errors, "hit_units" => hit_units}
  end

  def self.oracles(run, title)
    require "nokogiri"
    run.fetch("scenarios").map.with_index do |scenario, index|
      response = scenario.fetch("response")
      document = Nokogiri::HTML(Base64.strict_decode64(response.fetch("body").fetch("base64")))
      success = response.fetch("status") == 200 && if index.zero?
        document.at_css("h1")&.text == "Articles" && document.css("#articles h2").size >= 1
      else
        document.at_css("h1")&.text == title && document.css("h2").any? { _1.text == "Comments" } && document.css("#comments .p-4").size >= 1
      end
      {"id" => scenario.fetch("id"), "passed" => success}
    end
  end

  def self.run(source, output, entropy_companions: false, cli: File.join(ROOT, "target/release/lowrail"))
    source = File.realpath(source)
    output = File.expand_path(output)
    raise "output must be new and outside the source app" if File.exist?(output) || output.start_with?(source + "/")
    FileUtils.mkdir_p(output, mode: 0o700)
    app = File.join(output, "app")
    FileUtils.mkdir_p(app)
    (Dir.children(source) - %w[.git .lowrail tmp log node_modules storage]).each { FileUtils.cp_r(File.join(source, _1), app) }
    FileUtils.mkdir_p(File.join(app, "storage"))
    # Explicit, symmetric observer configuration; not a no-gem load control.
    env = ENV.keys.grep(/\A(?:LOWRAIL_|RUBY_|BUNDLE_|DATABASE_URL\z|RAILS_|RACK_ENV\z)/).to_h { [_1, nil] }.merge(
      "RAILS_ENV" => "production", "RACK_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil,
      "RAILS_LOG_LEVEL" => "fatal", "RUBY_YJIT_ENABLE" => "1", "LOWRAIL_SEALED" => "1", "LOWRAIL_ROOT" => app,
      "LOWRAIL_STATS" => "", "RUBYOPT" => "-I#{File.join(ROOT, 'gem/lib')} -rlowrail/setup")
    execute = ->(label, args, extra = {}) do
      File.open(File.join(output, "#{label}.log"), "w") do |log|
        raise "#{label} failed; see #{log.path}" unless system(env.merge(extra), *args, chdir: app, out: log, err: log)
      end
    end
    worker = ->(label, phase, enabled, companion_seed = nil) {
      extra = {"LOWRAIL" => enabled}
      extra.merge!("SECRET_KEY_BASE_DUMMY" => nil, "SECRET_KEY_BASE" => Entropy::SECRET) if companion_seed
      execute.call(label, [RbConfig.ruby, "--yjit", SCRIPT, "worker", phase, File.join(output, "#{label}.json"), *companion_seed&.to_s], extra)
    }
    worker.call("prepare", "prepare", "0")
    seed = File.join(output, "seed")
    FileUtils.cp_r(File.join(app, "storage"), seed)
    execute.call("build", [cli, "build", app, "--env", "production", "--sealed", "--jit", "yjit"], "LOWRAIL" => "0", "RUBYOPT" => nil)
    execute.call("explain", [cli, "explain", app, "--json"], "LOWRAIL" => "0", "RUBYOPT" => nil)
    sequence = ->(prefix, companion_seed = nil) do
      %w[off1 off2 on].map do |arm|
        label = "#{prefix}#{arm}"
        # No worker is live during restore, including the build's Ruby oracle.
        FileUtils.rm_rf(File.join(app, "storage"))
        FileUtils.cp_r(seed, File.join(app, "storage"))
        FileUtils.rm_rf(File.join(app, "tmp"))
        worker.call(label, "run", arm == "on" ? "1" : "0", companion_seed)
        JSON.parse(File.read(File.join(output, "#{label}.json")))
      end
    end
    runs = sequence.call("")
    title = YAML.safe_load_file(File.join(app, "test/fixtures/articles.yml")).fetch("one").fetch("title")
    assertions = runs.map { oracles(_1, title) }
    report = compare(runs)
    report["status"] = "rejected_oracles" unless assertions.flatten.all? { _1.fetch("passed") }
    companions = []
    if entropy_companions
      worker.call("entropy-pin", "entropy-pin", "0")
      control = JSON.parse(File.read(File.join(output, "entropy-pin.json")))
      if control.fetch("active")
        control.fetch("policy").fetch("seeds").each do |companion_seed|
          prefix = "companion-#{companion_seed}-"
          records = sequence.call(prefix, companion_seed)
          checks = records.map { oracles(_1, title) }
          companion = compare(records)
          companion["status"] = "rejected_oracles" unless checks.flatten.all? { _1.fetch("passed") }
          companions << companion.merge("seed" => companion_seed, "controls" => control,
            "workers" => %w[off1 off2 on].map { "#{prefix}#{_1}.json" }, "oracles" => checks,
            "refusals" => records.map { _1.fetch("refusals") }, "worker_modes" => records.map { _1.fetch("jit") },
            "unit_counts" => records.last.fetch("scenarios").map { _1.slice("id", "hits", "fallbacks") })
        end
      else
        companions << {"status" => "inactive_pin_mismatch", "controls" => control}
      end
    end
    explanation = JSON.parse(File.read(File.join(output, "explain.log")))
    units = explanation.fetch("units").map do |unit|
      id = unit.fetch("id").to_s
      {"id" => unit.fetch("id"), "pass" => unit.fetch("pass"), "target" => unit.fetch("target"),
        "scenarios" => runs.last.fetch("scenarios").map { {"id" => _1.fetch("id"),
          "hits" => _1.fetch("hits").fetch(id, 0), "fallbacks" => _1.fetch("fallbacks").fetch(id, 0)} }}
    end
    inventory = Dir[File.join(app, "test/{controllers,models,system}/*_test.rb")].sort.flat_map do |file|
      text = File.read(file)
      klass = text[/^class (\w+)/, 1]
      text.scan(/^\s*test "([^"]+)" do/).flatten.map do |name|
        id = "#{klass}#test_#{name.tr(' ', '_')}"
        {"id" => id, "source" => file.delete_prefix(app + "/"),
          "reason" => file.include?("/system/") ? "browser/JS lifecycle not ported" : "not ported in two-GET slice"}
      end
    end
    raise "scenario source test missing" unless SCENARIOS.all? { |scenario| inventory.any? { _1.fetch("id") == scenario.fetch("id") } }
    git_root, _, git_status = Open3.capture3("git", "-C", source, "rev-parse", "--show-toplevel")
    revision = Open3.capture3("git", "-C", source, "rev-parse", "HEAD").first.strip if git_status.success? && git_root.strip == source
    source_hashes = Dir[File.join(app, "{app,config,db,test}/**/*")].select { File.file?(_1) }.sort.to_h do |file|
      [file.delete_prefix(app + "/"), Digest::SHA256.file(file).hexdigest]
    end
    report.merge!("format" => 1, "mode" => "production/yjit", "transport" => "Rack::MockRequest, full Rails middleware; no HTTP server",
      "controls" => {"comparison" => "raw_unpinned", "secret_key_base" => "Rails DUMMY: independently generated per process, not pinned",
        "session_csrf" => "fresh session each GET; normal SecureRandom", "clock_x_runtime" => "real clock, header compared exactly",
        "request_id" => "caller-supplied scenario ID", "database" => "four restored SQLite files, no live worker during restore",
        "entropy_companion" => entropy_companions ? "separate declared workers below; raw rejection retained" : "not requested; raw gate unchanged"},
      "entropy_companions" => companions,
      "event_projection" => {"names" => "start/finish action_controller and action_view notifications in observed order",
        "scalar_payload_fields" => AppEvents::FIELDS, "not_claimed" => "arbitrary object payloads, durations, allocations or full subscriber equivalence"},
      "source_revision" => revision, "source_files_sha256" => source_hashes,
      "lock_sha256" => Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
      "manifest_sha256" => Digest::SHA256.file(File.join(app, ".lowrail/manifest.json")).hexdigest,
      "seed_sha256" => Digest::SHA256.file(File.join(output, "prepare.json")).hexdigest,
      "scenario_source_sha256" => Digest::SHA256.file(File.join(app, "test/controllers/articles_controller_test.rb")).hexdigest,
      "oracles" => assertions, "units" => units, "worker_modes" => runs.map { _1.fetch("jit") },
      "refusals" => runs.map { _1.fetch("refusals") }, "covered" => SCENARIOS,
      "uncovered" => inventory.reject { |test| SCENARIOS.any? { _1.fetch("id") == test.fetch("id") } },
      "limitations" => ["No writes/jobs/JS/HTTP server/streaming; no external service equivalence", "Shared observers/setup: no true no-gem observer-transparency control", "No extra warm/control repeats beyond one off/off/on sequence", "Source-declared test inventory only, no dynamic test discovery", "No SEAL001–009 or unsampled-input certification"])
    report["raw_status"] = report.fetch("status")
    if report.fetch("status") == "equivalent_for_executed_scenarios" && companions.any? { _1.fetch("status") != "equivalent_for_executed_scenarios" }
      report["status"] = "rejected_companion"
    end
    File.write(File.join(output, "report.json"), JSON.pretty_generate(report))
    puts JSON.pretty_generate(report)
    report.fetch("status") == "equivalent_for_executed_scenarios"
  end
end
