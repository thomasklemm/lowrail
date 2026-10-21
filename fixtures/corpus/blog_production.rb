# frozen_string_literal: true

require "json"
require "base64"
require "digest"
require "fileutils"
require "open3"
require "rbconfig"
require "yaml"
require_relative "blog_entropy"
require_relative "blog_scenarios"
require_relative "blog_completion"

# A bounded, untimed production Rack-boundary experiment, not a replacement
# for lowrail verify or a whole-suite/SEAL001–009 certificate. No test runtime.
# Raw entropy is untouched; terminal completion applies in every worker.
# Explicit entropy companions are separate workers, never output normalization.
module BlogProduction
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.join(ROOT, "script/blog-production-verify")
  SCENARIOS = [
    {"id" => "ArticlesControllerTest#test_should_get_index", "path" => "/articles"},
    {"id" => "ArticlesControllerTest#test_should_show_article", "path" => "/articles/1"}
  ].freeze
  DATABASES = %w[production production_cache production_queue production_cable].freeze

  def self.driver_sources
    %w[script/blog-production-verify fixtures/corpus/blog_production.rb fixtures/corpus/blog_scenarios.rb
       fixtures/corpus/blog_completion.rb fixtures/corpus/blog_entropy.rb fixtures/corpus/blog-entropy-controls.json].to_h do |path|
      [path, Digest::SHA256.file(File.join(ROOT, path)).hexdigest]
    end
  end

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

  # Read certificate names without activating the artifact or resolving any
  # autoload. Include complete inherited chains, even Lowrail's own modules:
  # an on-only prepend is observable, not something to normalize away.
  def self.holder_ancestry
    manifest = File.join(ENV.fetch("LOWRAIL_DIR", ".lowrail"), "manifest.json")
    artifact = File.file?(manifest) ? JSON.parse(File.read(manifest)) : {}
    names = %w[Object Kernel BasicObject]
    names << "ActionView::Template" unless artifact.fetch("templates", {}).empty?
    collect = ->(value) do
      case value
      when Hash then value.each { |key, entry| collect.call(key); collect.call(entry) }
      when Array then value.each { collect.call(_1) }
      when String
        names << value if value.match?(/\A[A-Z]\w*(?:::[A-Z]\w*)*\z/)
      end
    end
    collect.call(artifact.fetch("units", []))
    holders = names.uniq.sort.to_h do |name|
      holder = Lowrail.loaded_constant(name)
      [name, Module === holder ? holder.ancestors.map(&:name) : nil]
    end
    controller = Lowrail.loaded_constant("ArticlesController")
    view = controller&.instance_variable_get(:@view_context_class)
    holders["@cached_view"] = view&.ancestors&.map(&:name)
    holders
  end

  # Untimed targeted observer, identical in both workers. Observe every
  # form entry, not only pending admission: active calls bypass #observe.
  # Never construct a view or wrap its app-visible method for the witness.
  def self.capture_form_seam(view)
    natural_form_seams << {"bound_owner" => view.method(:form_with).owner.name,
      "instance_source_location" => view.class.instance_method(:form_with).source_location,
      "ancestors" => view.class.ancestors.map(&:name)}
  end

  def self.natural_form_seams = @natural_form_seams ||= []

  def self.cold_features
    helper = Lowrail.loaded_constant("ActionView::Helpers::FormHelper")
    method = helper&.instance_method(:form_with)
    {"api_loaded" => !!Lowrail.loaded_constant("ActionController::API"),
      "form_seam" => method && {"owner" => method.owner.name, "source_location" => method.source_location,
        "ancestors" => helper.ancestors.map(&:name)},
      "seam_features" => $LOADED_FEATURES.grep(%r{/lowrail/(?:form_scaffold(?:_inventory|_admission)?|load_hooks)\.rb\z}).sort,
      "objspace" => $LOADED_FEATURES.grep(%r{/(?:objspace\.rb|objspace\.(?:so|bundle))\z}),
      "holder_ancestry" => holder_ancestry}
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
      if phase == "finish" && name == "process_action.action_controller"
        flash = payload[:request]&.get_header("action_dispatch.request.flash_hash")
        fields["flash"] = BlogProduction.value(flash.to_hash) if flash
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
    when Time
      {"type" => item.class.name, "seconds" => item.to_i, "nanoseconds" => item.nsec,
        "utc_offset" => item.utc_offset, "zone" => value(item.zone)}
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

  def self.effects(root = Dir.pwd)
    require "sqlite3"
    databases = DATABASES.to_h do |name|
      file = File.join(root, "storage/#{name}.sqlite3")
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
    files = Dir.glob(File.join(root, "storage/**/*"), File::FNM_DOTMATCH).select { File.file?(_1) && !_1.match?(/\.sqlite3(?:-wal|-shm)?\z/) }
    {"databases" => databases, "storage_files" => files.sort.to_h { [_1.delete_prefix(root + "/"), Digest::SHA256.file(_1).hexdigest] }}
  end

  def self.worker(phase, destination, entropy_seed = nil, expected_jit: "yjit")
    raise "unknown requested cold-worker JIT mode" unless %w[yjit interpreter].include?(expected_jit)
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
    Rails.application.config.yjit = false if expected_jit == "interpreter"
    completion = Completion.new
    Rails.error.subscribe(completion)
    seam_trace = TracePoint.new(:call) { capture_form_seam(_1.self) }
    seam_trace.enable(target: Lowrail::FormScaffold::Variant.instance_method(:form_with))
    events, boot_events, late_events, sql_stream, errors = [], [], [], [], []
    callbacks = []
    ActiveSupport::LazyLoadHooks.prepend(ColdHooks)
    ActiveSupport.on_load(:before_eager_load, yield: true) { |app| callbacks << ["early_eager", app.class.name] }
    ActiveSupport.on_load(:action_controller) { callbacks << ["early_controller", name] }
    app_events = AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, app_events)
    request_thread = nil
    boot_complete = false
    # Register before initialize!/the seal, without referencing an AR target.
    # Rails has already computed this exact array for the adapter. Do not call
    # value_for_database again, or evaluate the lazy Proc used by cached SQL.
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
      payload = args.last
      begin
        binds = payload[:type_casted_binds]
        raise "unavailable adapter bind values (#{binds.class})" unless Array === binds
        context = request_thread
        booted = boot_complete
        sql_phase = context ? "scenario" : booted ? "post_scenario" : "boot"
        event = {"sql" => value(payload.fetch(:sql)), "binds" => value(binds),
          "database" => payload[:connection]&.pool&.db_config&.name,
          "name" => value(payload[:name]), "cached" => !!payload[:cached],
          "row_count" => payload[:row_count], "affected_rows" => payload[:affected_rows],
          "thread" => Thread.current.equal?(context) ? "request" : "other"}
        (context ? events : booted ? late_events : boot_events) << event
        sql_stream << {"phase" => sql_phase, **event}
      rescue StandardError => error
        errors << "SQL capture: #{error.message}"
      end
    end
    require File.expand_path("config/environment")
    required_mode = expected_jit == "yjit" ? "YJIT" : expected_jit
    raise "production/#{required_mode} required" unless Rails.env.production? && Lowrail.jit_mode == expected_jit
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
    boot_complete = true
    scenarios = phase.start_with?("case:") ? [Breadth::CASES.find { _1.fetch("key") == phase.delete_prefix("case:") } || raise("unknown scenario #{phase}")] : SCENARIOS
    responses = scenarios.map do |scenario|
      events.clear
      app_events.events.clear
      Lowrail::Stats.reset_counts! if defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
      request_thread = Thread.current
      app_events.thread = request_thread
      driver = Breadth::Driver.new(scenario.fetch("id"), app_events) if scenario["key"]
      request = if driver
        -> do
          driver.run(scenario.fetch("key"))
        rescue StandardError, ScriptError => error
          errors << "#{scenario.fetch('id')}: #{error.class}: #{error.message}"
          {"completed" => false, "steps" => driver.steps, "checks" => driver.checks}
        end
      else
        -> { Rack::MockRequest.new(Rails.application).get(scenario.fetch("path"),
          "HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => scenario.fetch("id")) }
      end
      response, entropy = entropy_seed ? Entropy.with(Integer(entropy_seed), scenario.fetch("id"), requests: driver ? 0 : 1, wall_clock: !!driver, &request) : [request.call, nil]
      request_thread = nil
      app_events.thread = nil
      errors.concat(entropy.fetch("errors")) if entropy
      Lowrail::VerifyLoads.capture(scenario.fetch("id"))
      {"id" => scenario.fetch("id"), "response" => driver ? response : {"status" => response.status,
        "headers" => value(response.headers.to_h), "body" => value(response.body)},
        "sql" => events.dup, "events" => app_events.events.dup, "effects" => effects,
        "entropy_trace" => entropy&.fetch("trace"), "clock_observations" => entropy&.fetch("clock_reads"),
        "wall_clock_observations" => entropy&.fetch("wall_clock_reads"),
        "hits" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_hits : {},
        "fallbacks" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_fallbacks : {}}
    end
    # All scenario actions/commits have returned. This is terminal: never run
    # another request after closing Cable's input queue. Keep every provisional
    # capture above, but only claim a completed snapshot after a successful join.
    completed = completion.finish
    completed_effects = effects if completed.fetch("status") == "completed"
    Lowrail::VerifyLoads.capture("async_completion")
    refusals = %w[Lowrail::Sealed Lowrail::FormScaffold].to_h do |name|
      mod = Lowrail.loaded_constant(name)
      [name, mod&.refusal]
    end
    form = Lowrail.loaded_constant("Lowrail::FormScaffold")
    File.write(destination, JSON.pretty_generate({"driver_sources" => driver_sources, "initial_effects" => initial, "scenarios" => responses,
      "completion" => completed, "completed_effects" => completed_effects,
      "boot_sql" => boot_events, "late_sql" => late_events, "sql_stream" => sql_stream,
      "cold_witness" => cold_witness.merge("after_requests" => cold_features,
        "natural_form_seams" => natural_form_seams),
      "unit_refusals" => defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.snapshot.fetch("unit_refusals") : {},
      "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "features" => $LOADED_FEATURES.reject { _1.start_with?(File.join(ROOT, "gem/lib/lowrail")) },
      "entropy_seed" => entropy_seed && Integer(entropy_seed), "entropy_control" => control,
      "jit" => Lowrail.jit_status, "refusals" => refusals.merge("artifact" => Lowrail.refusal_reason,
        "form_input" => form&.input_refusal), "errors" => errors}))
  end

  # Public report contract. A failing off/off control prevents attribution to
  # Lowrail even when off/on differs. Zero hits cannot be sealed coverage.
  def self.compare(runs, scenarios: SCENARIOS)
    raise "three workers required" unless runs.size == 3
    raise "missing/reordered scenarios" unless runs.all? { |run| run.fetch("scenarios").map { _1.fetch("id") } == scenarios.map { _1.fetch("id") } }
    boundaries = runs.flat_map { |run| [run, *run.fetch("cold_cases", [])] }
    boundaries.each do |run|
      if run.fetch("completion").fetch("status") == "completed" && run.fetch("completed_effects").nil?
        raise "completion requires an effect snapshot"
      end
    end
    differences = %w[off_control off_on].zip([runs[1], runs[2]]).to_h do |label, other|
      baseline = runs.fetch(0)
      mismatches = []
      %w[initial_effects loads features boot_sql cold_witness].each { mismatches << _1 unless baseline.fetch(_1) == other.fetch(_1) }
      %w[late_sql sql_stream exit_effects completion completed_effects].each { mismatches << _1 unless baseline[_1] == other[_1] }
      mismatches << "cold_cases" unless baseline["cold_cases"] == other["cold_cases"]
      mismatches << "driver_sources" unless baseline["driver_sources"] == other["driver_sources"]
      baseline.fetch("scenarios").zip(other.fetch("scenarios")).each do |left, right|
        %w[response sql effects events entropy_trace].each do |field|
          mismatches << "#{left.fetch('id')}:#{field}" unless left.fetch(field) == right.fetch(field)
        end
      end
      [label, mismatches]
    end
    errors = runs.flat_map { _1.fetch("errors") + _1.fetch("loads").values.flat_map { |stage| stage.fetch("errors", []) } }
    incomplete = boundaries.map { _1.fetch("completion") }.reject { _1.fetch("status") == "completed" }
    hit_units = runs.fetch(2).fetch("scenarios").flat_map { _1.fetch("hits").select { |_, count| count.positive? }.keys }.uniq.sort
    status = if differences.fetch("off_control").any?
      "rejected_off_control"
    elsif incomplete.any?
      "rejected_async_completion"
    elsif errors.any? || differences.fetch("off_on").any?
      "rejected"
    elsif hit_units.empty?
      "unexercised"
    else
      "equivalent_for_executed_scenarios"
    end
    {"status" => status, "differences" => differences, "capture_errors" => errors,
      "async_refusals" => incomplete, "hit_units" => hit_units}
  end

  def self.oracles(run, title)
    require "nokogiri"
    run.fetch("scenarios").map.with_index do |scenario, index|
      response = scenario.fetch("response")
      if response.key?("checks")
        next {"id" => scenario.fetch("id"), "passed" => response.fetch("completed") && response.fetch("checks").any? && response.fetch("checks").all? { _1.fetch("passed") },
          "checks" => response.fetch("checks")}
      end
      document = Nokogiri::HTML(Base64.strict_decode64(response.fetch("body").fetch("base64")))
      success = response.fetch("status") == 200 && if index.zero?
        document.at_css("h1")&.text == "Articles" && document.css("#articles h2").size >= 1
      else
        document.at_css("h1")&.text == title && document.css("h2").any? { _1.text == "Comments" } && document.css("#comments .p-4").size >= 1
      end
      {"id" => scenario.fetch("id"), "passed" => success}
    end
  end

  def self.run(source, output, entropy_companions: false, breadth: false, cli: File.join(ROOT, "target/release/lowrail"))
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
      if phase == "run" || phase.start_with?("case:")
        # The worker has exited: preserve persisted effects as well as the
        # provisional in-process step snapshots. This is not an async drain.
        path = File.join(output, "#{label}.json")
        record = JSON.parse(File.read(path))
        record["exit_effects"] = effects(app)
        File.write(path, JSON.pretty_generate(record))
      end
    }
    worker.call("prepare", "prepare", "0")
    seed = File.join(output, "seed")
    FileUtils.cp_r(File.join(app, "storage"), seed)
    execute.call("build", [cli, "build", app, "--env", "production", "--sealed", "--jit", "yjit"], "LOWRAIL" => "0", "RUBYOPT" => nil)
    execute.call("explain", [cli, "explain", app, "--json"], "LOWRAIL" => "0", "RUBYOPT" => nil)
    scenarios = SCENARIOS + (breadth ? Breadth::CASES : [])
    restore = -> do
      FileUtils.rm_rf(File.join(app, "storage"))
      FileUtils.cp_r(seed, File.join(app, "storage"))
      FileUtils.rm_rf(File.join(app, "tmp"))
    end
    sequence = ->(prefix, companion_seed = nil) do
      %w[off1 off2 on].map do |arm|
        label = "#{prefix}#{arm}"
        # No worker is live during restore, including the build's Ruby oracle.
        restore.call
        worker.call(label, "run", arm == "on" ? "1" : "0", companion_seed)
        record = JSON.parse(File.read(File.join(output, "#{label}.json")))
        if breadth
          record["case_diagnostics"] = []
          record["cold_cases"] = Breadth::CASES.map do |scenario|
            restore.call
            case_label = "#{label}-#{scenario.fetch('key')}"
            worker.call(case_label, "case:#{scenario.fetch('key')}", arm == "on" ? "1" : "0", companion_seed)
            other = JSON.parse(File.read(File.join(output, "#{case_label}.json")))
            record.fetch("scenarios").concat(other.fetch("scenarios"))
            record.fetch("errors").concat(other.fetch("errors") + other.fetch("loads").values.flat_map { _1.fetch("errors", []) })
            record.fetch("case_diagnostics") << {"id" => scenario.fetch("id"), "worker" => "#{case_label}.json",
              **other.slice("refusals", "unit_refusals", "jit")}
            {"id" => scenario.fetch("id"), **other.slice("driver_sources", "initial_effects", "loads", "features", "boot_sql", "late_sql", "sql_stream", "exit_effects", "cold_witness", "completion", "completed_effects")}
          end
          File.write(File.join(output, "#{label}.json"), JSON.pretty_generate(record))
        end
        record
      end
    end
    runs = sequence.call("")
    title = YAML.safe_load_file(File.join(app, "test/fixtures/articles.yml")).fetch("one").fetch("title")
    assertions = runs.map { oracles(_1, title) }
    report = compare(runs, scenarios: scenarios)
    report["raw_status"] = report.fetch("status")
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
          companion = compare(records, scenarios: scenarios)
          companion["status"] = "rejected_oracles" unless checks.flatten.all? { _1.fetch("passed") }
          companions << companion.merge("seed" => companion_seed, "controls" => control,
            "workers" => %w[off1 off2 on].map { "#{prefix}#{_1}.json" }, "oracles" => checks,
            "case_diagnostics" => records.map { _1["case_diagnostics"] },
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
          "reason" => if file.include?("/system/")
            breadth ? "server workflow replayed only; browser/JS, Turbo and confirmation dialogs not exercised" : "browser/JS lifecycle not ported"
          else
            breadth ? "scenario did not complete all source assertions in every observed arm" : "not ported in two-GET slice"
          end}
      end
    end
    raise "scenario source test missing" unless SCENARIOS.all? { |scenario| inventory.any? { _1.fetch("id") == scenario.fetch("id") } }
    git_root, _, git_status = Open3.capture3("git", "-C", source, "rev-parse", "--show-toplevel")
    revision = Open3.capture3("git", "-C", source, "rev-parse", "HEAD").first.strip if git_status.success? && git_root.strip == source
    source_hashes = Dir[File.join(app, "{app,config,db,test}/**/*")].select { File.file?(_1) }.sort.to_h do |file|
      [file.delete_prefix(app + "/"), Digest::SHA256.file(file).hexdigest]
    end
    checks_by_id = (assertions.flatten + companions.flat_map { _1.fetch("oracles", []).flatten }).group_by { _1.fetch("id") }
    complete = scenarios.reject { |scenario| scenario["boundary"] == "server_workflow_only" ||
      !checks_by_id.fetch(scenario.fetch("id")).all? { _1.fetch("passed") } }
    report.merge!("format" => 1, "mode" => "production/yjit", "transport" => "Rack::MockRequest, full Rails middleware; no HTTP server",
      "controls" => {"comparison" => "raw_unpinned", "secret_key_base" => "Rails DUMMY: independently generated per process, not pinned",
        "session_csrf" => "legacy GETs fresh; breadth workflows retain actual encrypted session cookie and submit natural form tokens; normal raw SecureRandom", "clock_x_runtime" => "real clock, header compared exactly",
        "request_id" => "caller-supplied scenario ID", "database" => "four restored SQLite files, no live worker during restore",
        "async_completion" => "All arms: terminal Cable writer/accepted-trim shutdown, two-second deadline; no supervisor or artificial execution for pending Solid Queue work; refusal is not completion",
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
      "refusals" => runs.map { _1.fetch("refusals") }, "case_diagnostics" => runs.map { _1["case_diagnostics"] },
      "driver_sources" => driver_sources, "covered" => complete.select { |scenario| inventory.any? { _1.fetch("id") == scenario.fetch("id") } },
      "supplemental" => scenarios.select { _1.fetch("id").start_with?("BlogProductionControl#") },
      "partial" => scenarios.select { _1["boundary"] == "server_workflow_only" },
      "uncovered" => inventory.reject { |test| complete.any? { _1.fetch("id") == test.fetch("id") } },
      "effects_boundary" => "Raw provisional step/scenario and exit snapshots retained. Separate completed_effects only after a symmetric terminal two-second Cable writer/accepted-trim join and empty Solid Queue state; unfinished/unsupported work refuses, never discarded or executed artificially",
      "sql_boundary" => "Ordered whole-worker capture through report serialization, including other threads; boot, scenario and post-scenario phases retained separately",
      "limitations" => [breadth ? "No Solid Queue supervisor/job execution; unfinished jobs explicitly refuse completion. Cable subscriber/connection workers and non-SolidQueue ActiveJob adapters unsupported; no browser/JS, HTTP server, streaming or external service equivalence" : "No writes/jobs/JS/HTTP server/streaming; no external service equivalence", "Shared observers/setup: no true no-gem observer-transparency control", "No extra warm/control repeats beyond one off/off/on sequence", "Source-declared test inventory only, no dynamic test discovery", "No SEAL001–009 or unsampled-input certification"])
    if report.fetch("status") == "equivalent_for_executed_scenarios" && companions.any? { _1.fetch("status") != "equivalent_for_executed_scenarios" }
      report["status"] = "rejected_companion"
    end
    File.write(File.join(output, "report.json"), JSON.pretty_generate(report))
    puts JSON.pretty_generate(report)
    report.fetch("status") == "equivalent_for_executed_scenarios"
  end
end
