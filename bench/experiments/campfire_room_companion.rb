# frozen_string_literal: true

# Untimed cold gates only. Raw responses and all rejected companions survive.
require_relative "campfire_scenario"
require_relative "../../fixtures/corpus/blog_production"

module CampfireRoomCompanion
  POLICY = File.join(CampfireScenario::ROOT, "fixtures/corpus/campfire-entropy-controls.json")
  FIELDS = %w[initial_effects steps sql events completed_effects completion loads features ancestry entropy_trace].freeze
  module_function

  # Ruby 4's base58/choose calls random_number -> gen_random, not random_bytes.
  # Keep the blog's per-site stream and reject every undeclared source/size.
  module SessionRandom
    def gen_random(size)
      BlogProduction::Entropy.bytes("SecureRandom::gen_random", size, caller_locations(1, 12)) || super
    end
  end

  def effects(state)
    raise "dedicated disposable localhost Redis required" unless ENV["CAMPFIRE_DISPOSABLE_REDIS"] == "1"
    require "sqlite3"
    require "redis"
    db = SQLite3::Database.new(File.join(state, "primary.sqlite3"), readonly: true)
    begin
      schema = db.execute("SELECT type,name,sql FROM sqlite_master ORDER BY type,name")
      tables = schema.select { _1.first == "table" }.to_h do |_, name, _|
        identifier = '"' + name.gsub('"', '""') + '"'
        columns = db.execute2("SELECT * FROM #{identifier} LIMIT 0").first
        rows = db.execute("SELECT * FROM #{identifier}").sort_by { Marshal.dump(_1) }
        [name, {"columns" => columns, "rows" => BlogProduction.value(rows)}]
      end
    ensure
      db.close
    end
    redis = Redis.new(url: "redis://127.0.0.1:6379/0")
    keys = redis.keys("*").sort.to_h do |key|
      # DUMP preserves the complete value/type. Absolute expiries are NOT
      # rounded, normalized, omitted or silently granted a clock exemption.
      [key, {"dump" => BlogProduction.value(redis.dump(key)), "expires_at_ms" => redis.call("PEXPIRETIME", key)}]
    end
    {"schema" => BlogProduction.value(schema), "tables" => tables, "redis" => keys}
  end

  def completion
    reasons = []
    server = Lowrail.loaded_constant("ActionCable")&.instance_variable_get(:@server)
    reasons << "Cable pubsub already started; no listener drain certificate" if server&.instance_variable_get(:@pubsub)
    if server && %i[@worker_pool @event_loop @heartbeat_timer].any? { server.instance_variable_get(_1) }
      reasons << "Cable worker/event loop/heartbeat outside closed GET boundary"
    end
    require "resque"
    queues = Resque.queues.to_h { [_1, Resque.size(_1)] }
    reasons << "pending Resque jobs; no supervisor" if queues.values.any?(&:positive?)
    pool = Rails.application.config.x.web_push_pool
    pools = [pool.delivery_pool, pool.invalidation_pool].map do |executor|
      # No work is posted by these GETs. Do not use Pool#shutdown's kill path
      # or run a pending task artificially to manufacture completion.
      {"scheduled" => executor.scheduled_task_count, "completed" => executor.completed_task_count,
        "queue_length" => executor.queue_length, "threads" => executor.length}
    end
    reasons << "WebPush work exists; outside no-work completion boundary" unless pools.all? { _1.values.all?(&:zero?) }
    {"status" => reasons.empty? ? "completed" : "refused", "reasons" => reasons, "resque" => queues, "web_push" => pools}
  end

  def worker(app, state, destination, seed = nil)
    control = BlogProduction::Entropy.validate(app, policy: JSON.parse(File.read(POLICY)))
    raise control.fetch("reason") unless control.fetch("active")
    if seed
      BlogProduction::Entropy.install(control.fetch("policy"))
      SecureRandom.singleton_class.prepend(SessionRandom)
    end
    require_relative "../../gem/lib/lowrail/verify_loads"
    Lowrail::VerifyLoads.install
    require File.join(app, "config/application")
    observer = BlogProduction::AppEvents.new
    ActiveSupport::Notifications.subscribe(/\.(?:action_controller|action_view)\z/, observer)
    reported_errors = BlogProduction::Completion.new
    Rails.error.subscribe(reported_errors)
    phase, thread = "boot", Thread.current
    sql, errors = [], []
    ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      begin
        binds = payload[:type_casted_binds]
        captured = if Array === binds
          BlogProduction.value(binds)
        else
          # Retain the event as well as rejecting the capture gap. Never call
          # the adapter's lazy Proc or recast the bind to manufacture coverage.
          errors << "adapter bind values unavailable (#{binds.class}); no recast or lazy Proc evaluation"
          {"status" => "binds_unavailable", "class" => binds.class.name}
        end
        sql << {"phase" => phase, "sql" => BlogProduction.value(payload[:sql]), "binds" => captured,
          "name" => BlogProduction.value(payload[:name]), "cached" => !!payload[:cached],
          "row_count" => payload[:row_count], "affected_rows" => payload[:affected_rows],
          "thread" => Thread.current.equal?(thread) ? "request" : "other"}
      rescue StandardError => error
        errors << error.message
      end
    end
    CampfireScenario.boot(app)
    Lowrail::VerifyLoads.capture("cold_boot")
    initial = effects(state)
    driver = CampfireScenario::Driver.new(state)
    observer.thread = thread
    scenario = lambda do
      phase = "login"
      driver.login
      phase = "room"
      driver.run("room")
    end
    _, entropy = seed ? BlogProduction::Entropy.with(Integer(seed), "campfire-room", requests: 3, wall_clock: true, &scenario) : [scenario.call, nil]
    phase = "post_scenario"
    observer.thread = nil
    finished = completion
    finished["reported_errors"] = reported_errors.reported_errors
    unless finished.fetch("reported_errors").empty?
      finished["status"] = "refused"
      finished.fetch("reasons") << "Rails.error reported an application/background failure"
    end
    Lowrail::VerifyLoads.capture("after_room")
    data = {"pins" => CampfireScenario.pins(app), "initial_effects" => initial, "steps" => driver.steps,
      "sql" => sql, "events" => observer.events, "completion" => finished,
      "completed_effects" => finished.fetch("status") == "completed" ? effects(state) : nil,
      "loads" => Lowrail::VerifyLoads.snapshot.fetch("stages"), "features" => $LOADED_FEATURES.dup,
      "ancestry" => BlogProduction.holder_ancestry, "errors" => errors,
      "entropy_seed" => seed, "entropy_control" => control, "entropy" => entropy,
      "entropy_trace" => entropy&.fetch("trace"), "stats" => Lowrail::Stats.snapshot}
    File.write(destination, JSON.pretty_generate(data), perm: 0o600)
  end

  def compare(rows)
    differences = [1, 2].zip(%w[off_off off_on]).to_h do |index, label|
      [label, (FIELDS + ["exit_effects"]).reject { |field| rows.first.fetch(field) == rows.fetch(index).fetch(field) }]
    end
    errors = rows.flat_map { _1.fetch("errors") + (_1["entropy"]&.fetch("errors") || []) +
      _1.fetch("loads").values.flat_map { |stage| stage.fetch("errors", []) } }
    passed = differences.values.all?(&:empty?) && errors.empty? && rows.all? { _1.dig("completion", "status") == "completed" }
    {"pass" => passed, "differences" => differences, "errors" => errors,
      "completed" => rows.map { _1.fetch("completion") }, "hits" => rows.map { _1.fetch("stats").fetch("unit_hits").values.sum }}
  end

  def run(app, seed, out)
    raise "dedicated disposable localhost Redis required" unless ENV["CAMPFIRE_DISPOSABLE_REDIS"] == "1"
    raise "new output required" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    manifest = File.join(app, ".lowrail/manifest.json")
    artifact = Digest::SHA256.file(manifest).hexdigest
    report = {"artifact_sha256" => artifact, "policy_sha256" => Digest::SHA256.file(POLICY).hexdigest,
      "harness_sha256" => Digest::SHA256.file(__FILE__).hexdigest, "groups" => {}, "cohort_started" => false}
    [nil, *JSON.parse(File.read(POLICY)).fetch("seeds")].each do |entropy_seed|
      group = entropy_seed ? "companion-#{entropy_seed}" : "raw"
      rows = %w[off_a off_b on].map do |arm|
        label = "#{group}-#{arm}"
        state = File.join(out, "#{label}-state")
        FileUtils.cp_r(seed, state)
        env = CampfireScenario.environment(app, state).merge("LOWRAIL" => arm == "on" ? "1" : "0",
          "LOWRAIL_SEALED" => "1", "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => File.join(app, ".lowrail"),
          "LOWRAIL_STATS" => "", "RUBYOPT" => "-rbundler/setup -I#{CampfireScenario::ROOT}/gem/lib -rlowrail/setup")
        require "redis"
        Redis.new(url: env.fetch("REDIS_URL")).flushdb
        destination = File.join(out, "#{label}.json")
        File.open(File.join(out, "#{label}.log"), "w") do |log|
          raise "worker failed: #{label}; keep #{log.path}" unless system(env, RbConfig.ruby, File.realpath(__FILE__), "worker", app, state,
            destination, *entropy_seed&.to_s, chdir: app, out: log, err: log)
        end
        raise "artifact changed" unless Digest::SHA256.file(manifest).hexdigest == artifact
        row = JSON.parse(File.read(destination))
        row["exit_effects"] = effects(state)
        File.write(destination, JSON.pretty_generate(row), perm: 0o600)
        row
      end
      report.fetch("groups")[group] = compare(rows)
      File.write(File.join(out, "summary.json"), JSON.pretty_generate(report), perm: 0o600)
      puts JSON.generate(group: group, **report.fetch("groups").fetch(group))
    end
    report["pass"] = JSON.parse(File.read(POLICY)).fetch("seeds").all? { report.fetch("groups").fetch("companion-#{_1}").fetch("pass") }
    File.write(File.join(out, "summary.json"), JSON.pretty_generate(report), perm: 0o600)
    report
  end
end

if $PROGRAM_NAME == __FILE__
  mode, app, seed, out, entropy_seed = ARGV
  abort "usage: campfire_room_companion.rb run|worker APP STATE NEW_OUTPUT [ENTROPY_SEED]" unless %w[run worker].include?(mode) && out
  app, seed, out = [app, seed, out].map { File.expand_path(_1) }
  if mode == "worker"
    CampfireRoomCompanion.worker(app, seed, out, entropy_seed)
  else
    exit 2 unless CampfireRoomCompanion.run(app, seed, out).fetch("pass")
  end
end
