# frozen_string_literal: true

# Bet S's finite native protocol. No pass installation or timing-based retry.
# ruby bench/experiments/sealed_yjit_gate.rb CONFIG NEW_OUTPUT
require "json"
require "fileutils"
require "digest"
require "open3"
require "rbconfig"

module SealedYjitGate
  ROOT = File.expand_path("../..", __dir__)
  module_function

  def interval(values)
    raise "four independent blocks required" unless values.size == 4
    mean = values.sum.fdiv(4)
    se = Math.sqrt(values.sum { (_1 - mean)**2 }.fdiv(3)).fdiv(2)
    {mean: mean, t95: [mean - 3.182446305 * se, mean + 3.182446305 * se], blocks: values}
  end

  def pins(config)
    files = Dir[File.join(ROOT, "gem/lib/**/*.{rb,so}"), File.join(config.fetch("artifact"), "**/*"),
      File.join(config.fetch("app"), "{app,config,db,lib}/**/*")]
    files += [__FILE__, RbConfig.ruby, File.join(config.fetch("app"), "Gemfile.lock")]
    files.select { File.file?(_1) }.uniq.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
  end

  # Untimed, original public artifact only. Reuse the existing fixture's
  # SQL/value, entropy, load and terminal-completion contracts, not its
  # historical block-link specimen installer.
  def cold_worker(config, destination, seed)
    require File.join(config.fetch("app"), "config/boot")
    require_relative "fizzy_link_vector"
    require_relative "campfire_room_companion"
    require File.join(ROOT, "gem/lib/lowrail/verify_loads")
    policy = JSON.parse(File.read(config.fetch("entropy_policy")))
    control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
    raise control.fetch("reason") unless control.fetch("active")
    unless seed == "raw"
      BlogProduction::Entropy.install(policy)
      SecureRandom.singleton_class.prepend(CampfireRoomCompanion::SessionRandom)
    end
    Lowrail::VerifyLoads.install
    require File.join(config.fetch("app"), "config/application")
    sql, errors = [], []
    request_thread = Thread.current
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      binds = payload[:type_casted_binds]
      if Array === binds
        sql << {sql: BlogProduction.value(payload[:sql]), binds: BlogProduction.value(binds),
          name: BlogProduction.value(payload[:name]), cached: !!payload[:cached],
          row_count: payload[:row_count], affected_rows: payload[:affected_rows],
          database: payload[:connection]&.pool&.db_config&.name,
          thread: Thread.current.equal?(request_thread) ? "request" : "other"}
      else
        errors << "adapter bind values unavailable (#{binds.class}); not evaluated"
      end
    end
    events = BlogProduction::AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, events)
    completion = FizzyLinkCompletion305.new(config.fetch("state"))
    Rails.error.subscribe(completion)
    require File.join(config.fetch("app"), "config/environment")
    raise "production/YJIT required" unless Rails.env.production? && Lowrail.jit_mode == "yjit"
    witness = -> {
      names = %w[Object Kernel BasicObject ActionView::Base ActionView::Template ActionView::CollectionRenderer
        ActiveRecord::Associations::Preloader ActionView::Helpers::FormHelper ActionView::Helpers::TagHelper]
      {features: $LOADED_FEATURES.dup, ancestry: names.to_h do |name|
        holder = Lowrail.loaded_constant(name)
        [name, holder&.ancestors&.map(&:name)]
      end}
    }
    before = witness.call
    Lowrail::VerifyLoads.capture("cold_boot")
    initial = FizzyLinkVector.effects(config.fetch("state"))
    driver = FizzyLinkVector::Driver.new(config.fetch("state"))
    events.thread = Thread.current
    requests = -> {
      driver.login
      3.times do |index|
        raise "GET failed" unless driver.request("GET", config.fetch("path")).status == 200
        Lowrail::VerifyLoads.capture("request_#{index}")
      end
    }
    _, entropy = seed == "raw" ? [requests.call, nil] : BlogProduction::Entropy.with(Integer(seed),
      "sealed-yjit-fizzy-cold", requests: 5, wall_clock: true, &requests)
    events.thread = nil
    terminal = completion.finish
    Lowrail::VerifyLoads.capture("completion")
    runtimes = %w[TokenTag CollectionRender].to_h do |name|
      runtime = Lowrail.loaded_constant("Lowrail::#{name}")
      [name, {admission: runtime.admission, refusal: runtime.refusal}]
    end
    result = {initial_effects: initial, steps: driver.steps, sql: sql, events: events.events,
      cold: before, after: witness.call, loads: Lowrail::VerifyLoads.snapshot.fetch("stages"),
      completion: terminal, completed_effects: terminal.fetch("status") == "completed" ? FizzyLinkVector.effects(config.fetch("state")) : nil,
      errors: errors, entropy_trace: entropy&.fetch("trace"), entropy_errors: entropy&.fetch("errors"),
      hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks, runtimes: runtimes,
      refusal: Lowrail.refusal_reason}
    File.write(destination, JSON.pretty_generate(result), perm: 0o600)
  end

  def worker(config, destination)
    require File.join(config.fetch("app"), "config/environment")
    require "rack/mock"
    raise "production/startup YJIT required" unless Rails.env.production? && RubyVM::YJIT.enabled? && Lowrail.jit_mode == "yjit"
    raise "timed statistics must be disabled" if defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    if config.fetch("kind") == "fizzy"
      require_relative "fizzy_link_vector"
      driver = FizzyLinkVector::Driver.new(config.fetch("state"), record: false)
      driver.login
      request = -> { driver.request("GET", config.fetch("path")) }
    else
      rack = Rack::MockRequest.new(Rails.application)
      headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "sealed-yjit-gate"}.merge(config.fetch("headers", {}))
      request = -> { rack.get(config.fetch("path"), headers) }
    end
    samples = []
    execute = ->(record) {
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
      response = request.call
      raise "request failed: #{response.status}" unless response.status == 200 && !response.body.empty?
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - start
      samples << elapsed if record
    }
    10.times { execute.call(false) }
    jit_before, gc_before = RubyVM::YJIT.runtime_stats, GC.stat
    10.times { execute.call(true) }
    gc_after, jit_after = GC.stat, RubyVM::YJIT.runtime_stats
    # Coverage is explicitly AFTER timing; no statistics run in its windows.
    require File.join(ROOT, "gem/lib/lowrail/stats")
    Lowrail::Stats.enable!
    Lowrail::Stats.reset_counts!
    10.times { execute.call(false) }
    admissions = %w[FormScaffold TokenTag CollectionRender].to_h do |name|
      runtime = Lowrail.loaded_constant("Lowrail::#{name}")
      [name, runtime && {admission: runtime.admission, refusal: runtime.refusal}]
    end
    record = {ruby: RUBY_DESCRIPTION, rails: Rails.version, yjit: RubyVM::YJIT.enabled?,
      affinity: File.read("/proc/self/status")[/^Cpus_allowed_list:\s*(.*)$/, 1],
      arm: ENV.fetch("LOWRAIL"), requests_ns: samples, wall_ns_per_request: samples.sum.fdiv(10),
      jit_before: jit_before, jit_after: jit_after, gc_before: gc_before, gc_after: gc_after,
      hits: Lowrail::Stats.unit_hits, fallbacks: Lowrail::Stats.unit_fallbacks,
      ar_installed: (Lowrail.manifest&.units || []).filter_map do |unit|
        next unless unit["pass"] == "active_record/instantiate"
        klass = Lowrail.loaded_constant(unit.fetch("ar_instantiate").fetch("model"))
        unit.fetch("id") if klass&.instance_variable_defined?(:@_lowrail_instantiate)
      end,
      admissions: admissions, refusal: Lowrail.refusal_reason,
      manifest_sha256: Digest::SHA256.file(File.join(config.fetch("artifact"), "manifest.json")).hexdigest}
    File.write(destination, JSON.pretty_generate(record), perm: 0o600)
  end

  def run(config, output)
    raise "new output required; no retries" if File.exist?(output)
    app = config.fetch("app")
    raise "disposable corpus copy required" unless File.realpath(app).start_with?(File.join(ROOT, ".corpus/"))
    manifest = JSON.parse(File.read(File.join(config.fetch("artifact"), "manifest.json")))
    raise "fresh production/YJIT sealed artifact required" unless manifest.fetch("certification_jit") == "yjit" &&
      manifest.fetch("rails_env") == "production" && !manifest.fetch("units").empty?
    FileUtils.mkdir_p(output, mode: 0o700)
    protocol = {revision: IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip,
      config: config, pins: pins(config), retries: 0, excluded: [], warmup: 10, requests: 10,
      order: [%w[off on off], %w[on off on], %w[off on off], %w[on off on]]}
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(protocol), perm: 0o600)
    config_path = File.join(output, "config.json")
    File.write(config_path, JSON.pretty_generate(config), perm: 0o600)
    clean = ENV.keys.grep(/\A(?:LOWRAIL|RUBYOPT|RUBY_|BUNDLE_|RAILS_|RACK_ENV|DATABASE_URL|.*_DATABASE_URL)/).to_h { [_1, nil] }
    env = clean.merge(config.fetch("env", {})).merge("RAILS_ENV" => "production", "RACK_ENV" => "production",
      "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true", "LOWRAIL_SEALED" => "1",
      "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => config.fetch("artifact"), "LOWRAIL_STATS" => nil,
      "RUBYOPT" => "-rbundler/setup -I#{ROOT}/gem/lib -rlowrail/setup", "RAILS_LOG_LEVEL" => "fatal")
    blocks = protocol.fetch(:order).map.with_index do |arms, block|
      arms.map.with_index do |arm, position|
        if config["storage_seed"]
          FileUtils.rm_rf(File.join(app, "storage"))
          FileUtils.cp_r(config.fetch("storage_seed"), File.join(app, "storage"))
        end
        if config["state_seed"]
          FileUtils.rm_rf(config.fetch("state"))
          FileUtils.cp_r(config.fetch("state_seed"), config.fetch("state"))
        end
        FileUtils.rm_rf(File.join(app, "tmp"))
        label = "#{block}-#{position}-#{arm}"
        destination = File.join(output, "#{label}.json")
        ok = system(env.merge("LOWRAIL" => arm == "on" ? "1" : "0"), "taskset", "-c", config.fetch("cpu").to_s,
          RbConfig.ruby, "--yjit", "--disable-zjit", File.expand_path(__FILE__), "worker", config_path, destination,
          chdir: app, out: File.join(output, "#{label}.log"), err: [:child, :out])
        raise "#{label} failed; retain partial cohort without retry" unless ok
        row = JSON.parse(File.read(destination)).merge("label" => label, "treatment" => arm)
        warn "#{label}: #{row.fetch('wall_ns_per_request')} ns/request"
        row
      end
    end
    deltas = blocks.map do |rows|
      means = rows.group_by { _1.fetch("treatment") }.transform_values { |group| group.sum { _1.fetch("wall_ns_per_request") }.fdiv(group.size) }
      100 * (means.fetch("on").fdiv(means.fetch("off")) - 1)
    end
    drift = blocks.map { 100 * (_1.last.fetch("wall_ns_per_request").fdiv(_1.first.fetch("wall_ns_per_request")) - 1) }
    unchanged = protocol.fetch(:pins) == pins(config)
    coverage = blocks.flatten.all? do |row|
      row.fetch("refusal").nil? && (row.fetch("treatment") == "off" || row.fetch("hits").values.sum.positive?)
    end
    estimate = interval(deltas)
    result = {wall_delta_pct: estimate, flank_drift_pct: interval(drift), source_unchanged: unchanged,
      coverage: coverage, native_positive: unchanged && coverage && estimate.fetch(:t95).last.negative?,
      scope: "ten-warmup native YJIT, compilation/GC included; not a YJIT-flat instruction price",
      blocks: blocks, retries: 0, excluded: []}
    File.write(File.join(output, "result.json"), JSON.pretty_generate(result), perm: 0o600)
    puts JSON.generate(result.reject { |key, _| key == :blocks })
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "worker"
    SealedYjitGate.worker(JSON.parse(File.read(ARGV.fetch(1))), ARGV.fetch(2))
  elsif ARGV.first == "cold-worker"
    SealedYjitGate.cold_worker(JSON.parse(File.read(ARGV.fetch(1))), ARGV.fetch(2), ARGV.fetch(3))
  else
    abort "usage: sealed_yjit_gate.rb CONFIG NEW_OUTPUT" unless ARGV.size == 2
    SealedYjitGate.run(JSON.parse(File.read(ARGV.fetch(0))), File.expand_path(ARGV.fetch(1)))
  end
end
