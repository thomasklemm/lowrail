# frozen_string_literal: true

# Census harness, run by script/census inside a disposable census app copy:
#   bundle exec ruby [--yjit|--zjit] SCRIPT prepare|profile|list APP [NEW_JSON]
# Reuses census 4's request client, measurement windows and workload set
# (../rails_main_census_4.rb, ../census_4_workloads.rb) unchanged. Only the
# round-specific parts are generalized here: which Rails checkout is expected
# (CENSUS_RAILS_SHA), the execution mode (CENSUS_MODE interpreter|yjit|zjit),
# fixture preparation for every corpus app, and a per-workload SQL control.
require_relative "../rails_main_census_4"

module RailsCensus
  # Workloads build c::Op and c::Client; measure and the job/mail helpers come
  # from census 4 and run with self = RailsCensus, so site_key below applies.
  include RailsMainCensus4
  extend RailsMainCensus4

  ROOT = File.expand_path("../../..", __dir__)
  MODES = %w[interpreter yjit zjit].freeze

  class << self
    public(*RailsMainCensus4.private_instance_methods(false))
    attr_reader :rails_dir

    def rails_sha = ENV.fetch("CENSUS_RAILS_SHA")
    def mode = ENV.fetch("CENSUS_MODE", "interpreter")

    # APP-nops runs APP's copy and workloads with prepared statements off
    # (CENSUS_PREPARED_STATEMENTS=false), as behind PgBouncer.
    def copy_of(name) = name.delete_suffix("-nops")

    def boot(name)
      raise "disposable census copy required" unless Dir.pwd.match?(%r{\A#{Regexp.escape(ROOT)}/\.corpus/census[\w.-]*-#{Regexp.escape(copy_of(name))}\z})
      raise "no Lowrail preload" if defined?(Lowrail)
      raise "unknown mode #{mode}" unless MODES.include?(mode)
      ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
        "SECRET_KEY_BASE_DUMMY" => "1", "SKIP_TELEMETRY" => "1", "RAILS_LOG_LEVEL" => "fatal",
        "APP_VERSION" => "census", "GIT_REVISION" => "census")
      ENV["DATABASE_ADAPTER"] ||= "sqlite"
      require File.expand_path("config/application")
      Rails.application.config.yjit = mode == "yjit"
      # Writebook and Sure enable YJIT themselves; hide only that entry point in other modes.
      manual_enable = RubyVM::YJIT.method(:enable) if %w[writebook sure].include?(name) && mode != "yjit"
      RubyVM::YJIT.singleton_class.undef_method(:enable) if manual_enable
      begin
        require File.expand_path("config/environment")
      ensure
        RubyVM::YJIT.define_singleton_method(:enable, manual_enable) if manual_enable
      end
      @rails_dir = File.dirname(Gem.loaded_specs.fetch("railties").full_gem_path)
      raise "wrong Rails revision: #{@rails_dir}" unless File.basename(@rails_dir).end_with?("-#{rails_sha[0, 12]}")
      raise "wrong YJIT mode" unless RubyVM::YJIT.enabled? == (mode == "yjit")
      raise "wrong ZJIT mode" unless !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?) == (mode == "zjit")
      Rails.logger.level = :fatal
      ActiveRecord::Base.logger = nil
      # External measurement controls, the same for every app (as in census 4).
      ActiveJob::Base.queue_adapter = :test
      if defined?(ActionMailer)
        ActionMailer::Base.delivery_method = :test
        ActionMailer::Base.perform_deliveries = true
        ActionMailer::Base.default_url_options = { host: "localhost", protocol: "https" }.merge(ActionMailer::Base.default_url_options)
      end
      Rails.application.routes.default_url_options = { host: "localhost", protocol: "https" }.merge(Rails.application.routes.default_url_options)
      Rails.application.config.hosts.clear if Rails.application.config.respond_to?(:hosts)
      # CENSUS_DEBUG=1 (list only): print every exception raised in app code,
      # since apps often rescue them into a bare 500 body.
      if ENV["CENSUS_DEBUG"] == "1"
        TracePoint.new(:raise) do |tp|
          trace = tp.raised_exception.backtrace || []
          frame = trace.find { _1.start_with?(Rails.root.to_s) } || trace.first
          warn "DEBUG #{tp.raised_exception.class}: #{tp.raised_exception.message[0, 300]} at #{frame}"
        end.enable
      end
      # Apps that push native Sidekiq jobs (not Active Job) get the same control:
      # pushes are captured in memory and performed as their own workloads.
      if ENV["CENSUS_SIDEKIQ_FAKE"] == "1"
        require "sidekiq/testing"
        Sidekiq::Testing.fake!
      end
      if (expected = ENV["CENSUS_PREPARED_STATEMENTS"])
        actual = ActiveRecord::Base.with_connection(&:prepared_statements)
        raise "prepared_statements is #{actual}, expected #{expected}" unless actual.to_s == expected
      end
    end

    def reset_side_effects
      super
      Sidekiq::Job.clear_all if ENV["CENSUS_SIDEKIQ_FAKE"] == "1"
    end

    # CENSUS_SET=background: the background census's workloads
    # (background_workloads.rb) instead of the request workloads.
    def background? = ENV["CENSUS_SET"] == "background"

    # Native Sidekiq jobs a block pushes, as [class, args] payloads.
    def sidekiq_jobs_from
      reset_side_effects
      yield
      Sidekiq::Job.jobs.map { _1.slice("class", "args") }
    ensure
      reset_side_effects
    end

    def sidekiq_job_op(name, payload)
      Op.new(name, :job, -> { payload["class"].constantize.new.perform(*payload["args"].deep_dup) })
    end

    # CENSUS_SET=ce2: the heavier pages in ../ce2 (README.md), in copies set up
    # with ../ce2/overlays.
    def ce2? = ENV["CENSUS_SET"] == "ce2"

    def workloads(name)
      if background?
        load File.join(__dir__, "background_workloads.rb")
        return BackgroundWorkloads.public_send(copy_of(name).tr("-", "_"), self)
      end
      if ce2?
        load File.join(__dir__, "../ce2/workloads.rb")
        return Ce2Workloads.public_send(copy_of(name).tr("-", "_"), self)
      end
      load File.join(__dir__, "../census_4_workloads.rb")
      load File.join(__dir__, "pg_workloads.rb")
      load File.join(__dir__, "inertia_chatwoot_workloads.rb")
      Census4Workloads.public_send(copy_of(name).tr("-", "_"), self)
    end

    def prepare(name)
      marker = "tmp/census-fixtures.json"
      raise "fixtures already prepared" if File.exist?(marker)
      require "active_record/fixtures"
      case name
      when "blog", "redprints-cfp", "react-starter-kit"
        load "db/seeds.rb"
      when "pingcrm"
        require "faker" # require: false in PingCRM's Gemfile
        Faker::Config.random = Random.new(42)
        load "db/seeds.rb"
      when "lobsters"
        load "db/seeds.rb"
        Rails.application.load_tasks # defines FakeDataGenerator
        BCrypt::Engine.cost = BCrypt::Engine::MIN_COST
        srand(42)
        Faker::Config.random = Random.new(42) # as census 5: Faker draws from its own generator
        # Census 5 generated under the app's own queue adapter (solid_queue), not
        # boot's :test one; the generated stories differ between the two.
        measured_adapter = ActiveJob::Base.queue_adapter
        ActiveJob::Base.queue_adapter = Rails.application.config.active_job.queue_adapter
        begin
          ActiveRecord::Base.transaction(requires_new: false) { FakeDataGenerator.new.generate }
        ensure
          ActiveJob::Base.queue_adapter = measured_adapter
        end
      when "fizzy", "fizzy-mysql"
        helper = File.read("test/test_helper.rb").split("module FixturesTestHelper\n", 2).fetch(1)
        eval("module FixturesTestHelper\n" + helper, TOPLEVEL_BINDING, "test/test_helper.rb")
        load_fixtures
      when "campfire", "writebook", "codetriage"
        load_fixtures
      when "casa"
        # CASA's own seeds (DbPopulator); the preset is chosen by APP_ENVIRONMENT.
        ENV["APP_ENVIRONMENT"] = "development"
        ENV["DB_SEEDS_RANDOM_SEED"] = "42"
        load "db/seeds.rb"
      when "lago"
        srand(42)
        load "db/seeds.rb"
      when "sure"
        Rails.application.load_tasks
        ENV["SEED"] = "42"
        Rake::Task["demo_data:default"].invoke
      when "docuseal", "mastodon", "discourse", "loomio"
        # The app's own seeds where it has them, then a seed script that
        # writes through the app's own services (fixtures/corpus/pg-census/seeds).
        load "db/seeds.rb" if name == "mastodon"
        load File.join(ROOT, "fixtures/corpus/pg-census/seeds/#{name}.rb")
      when "chatwoot", "flow", "hackatime", "thinkroom"
        # Chatwoot: its db/seeds.rb (installation config), then its own account
        # seeder. Flow and Hackatime: their development seeds plus board tasks
        # or 30 days of heartbeats. Thinkroom: its seeds plus documents. All
        # through census scripts in
        # fixtures/corpus/inertia-chatwoot-census/seeds.
        load "db/seeds.rb" if name == "chatwoot"
        load File.join(ROOT, "fixtures/corpus/inertia-chatwoot-census/seeds/#{name}.rb")
      else
        raise "no preparation known for #{name}"
      end
      if ce2?
        load File.join(__dir__, "../ce2/seed.rb")
        Ce2Seed.public_send(name.tr("-", "_"))
      end
      FileUtils.mkdir_p("tmp")
      File.write(marker, JSON.generate(name: name, rails: rails_sha, lock: Digest::SHA256.file(ENV.fetch("BUNDLE_GEMFILE") + ".lock").hexdigest))
    end

    # Jobs the request itself enqueues. Debounced Turbo refreshes
    # (broadcasts_refreshes) enqueue from a timer thread 0.5 s later, so census
    # 4's capture saw them only when that timer happened to fire inside the
    # window; they are left out, as in census 5's receipts.
    def jobs_from(&block)
      thread = Thread.current
      other_threads = []
      subscriber = ActiveSupport::Notifications.subscribe("enqueue.active_job") do |*, payload|
        other_threads << payload[:job].job_id unless Thread.current.equal?(thread)
      end
      jobs = super(&block)
      jobs.reject { other_threads.include?(_1["job_id"]) }
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end

    def site_key(file)
      if file.nil?
        "<no Ruby source>"
      elsif file.start_with?(Rails.root.to_s + "/")
        file.sub(Rails.root.to_s + "/", "APP/")
      elsif file.start_with?(rails_dir + "/")
        "RAILS/" + file.delete_prefix(rails_dir + "/")
      elsif file.include?("/gems/")
        "GEM/" + file.split("/gems/", 2).last
      elsif file.start_with?(RbConfig::CONFIG.fetch("rubylibdir") + "/")
        file.sub(RbConfig::CONFIG.fetch("rubylibdir") + "/", "RUBY/")
      else
        file.sub(ROOT + "/", "LOWRAIL/")
      end
    end

    # Behavior control, after every measurement: the SQL each workload runs
    # (literals and numbers masked, with a sign unless it follows an operand:
    # SolidCache's signed key_hash), two operations each. A patch that keeps
    # behavior keeps the digest; the A/A pair shows which workloads drift anyway.
    def sql_shape(op)
      statements = []
      thread = Thread.current
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        next if payload[:name] == "SCHEMA" || !Thread.current.equal?(thread)
        sql = payload[:sql].to_s.gsub(/'(?:[^']|'')*'/, "?").gsub(/(?<![\w)])-?\b\d+(?:\.\d+)?\b/, "?")
        statements << (payload[:cached] ? "CACHE #{sql}" : sql)
      end
      begin
        2.times { op.call.call; reset_side_effects }
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
      { queries_per_op: statements.size / 2.0, digest: Digest::SHA256.hexdigest(statements.join("\n"))[0, 16] }
    end

    # JIT counters for steady-state workloads (script/census run --stats): warm
    # every workload, reset, then run each 20 times. Per operation in the output.
    def stats(name, output)
      raise "fresh output required" if File.exist?(output)
      jit = RubyVM::YJIT.enabled? ? RubyVM::YJIT : RubyVM::ZJIT
      # CENSUS_DEFAULT_COUNTERS=1: ZJIT without --zjit-stats, whose default counters
      # (memory, compiled ISEQs) are not inflated by stats code. Not reset; the
      # window's counters are the difference of two snapshots, and the totals
      # after the window are kept too (memory and code size are levels, not rates).
      default_counters = ENV["CENSUS_DEFAULT_COUNTERS"] == "1"
      raise "run with --yjit-stats or --zjit-stats" unless jit.stats_enabled? || default_counters
      ops = workloads(name)
      warmup = Integer(ENV.fetch("CENSUS_WARMUP", "50"))
      ops.each { |op| warmup.times { op.call.call; reset_side_effects } }
      read = -> { (jit == RubyVM::YJIT ? jit.runtime_stats : jit.stats).select { |_, v| v.is_a?(Numeric) } }
      jit.reset_stats! unless default_counters
      # CENSUS_STATS_BY_WORKLOAD=1 also snapshots around each workload's 20
      # operations (the reads then fall inside the app's window).
      by_workload = ENV["CENSUS_STATS_BY_WORKLOAD"] == "1"
      before = read.call
      workloads = ops.map do |op|
        start = read.call if by_workload
        20.times { op.call.call; reset_side_effects }
        next unless by_workload
        finish = read.call
        { workload: op.name, kind: op.kind, ops: 20, counts: finish.filter_map { |k, v| d = v - start.fetch(k, 0); [k, d] if d != 0 }.to_h }
      end
      after = read.call
      File.write(output, JSON.pretty_generate(app: name, ruby: RUBY_DESCRIPTION, jit: jit.name, rails: rails_sha, pid: Process.pid,
        warmup: warmup, ops: ops.size * 20, default_counters: default_counters, **(by_workload ? { workloads: workloads } : {}),
        per_op: after.filter_map { |k, v| d = v - before.fetch(k, 0); [k, d.fdiv(ops.size * 20)] if d != 0 }.to_h,
        totals: after.reject { |_, v| v == 0 }) + "\n")
    end

    def profile(name, output)
      raise "fresh output required" if File.exist?(output)
      ops = workloads(name)
      only = ENV["CENSUS_ONLY"]&.split(",")
      ops = ops.select { only.include?(_1.name) } if only
      raise "no workloads selected" if ops.empty?
      results = ops.map { |op| measure(op) }
      ops.zip(results) { |op, result| result[:sql] = sql_shape(op) }
      result = { app: name, ruby: RUBY_DESCRIPTION, mode: mode, yjit: RubyVM::YJIT.enabled?, rails: rails_sha,
        rails_dir: File.basename(rails_dir), adapter: ActiveRecord::Base.connection_db_config.adapter,
        lock_sha256: Digest::SHA256.file(ENV.fetch("BUNDLE_GEMFILE") + ".lock").hexdigest, workloads: results }
      File.write(output, JSON.pretty_generate(result) + "\n")
      puts JSON.generate(result.except(:workloads).merge(workloads: results.map { _1.except(:sites) }))
    end
  end
end

if $PROGRAM_NAME == __FILE__
  command, name, output = ARGV
  RailsCensus.boot(name)
  case command
  when "prepare" then RailsCensus.prepare(name)
  when "profile" then RailsCensus.profile(name, output)
  when "list" then RailsCensus.list(name)
  when "stats" then RailsCensus.stats(name, output)
  else abort "usage: harness.rb prepare|profile|stats|list APP [NEW_JSON]"
  end
end
