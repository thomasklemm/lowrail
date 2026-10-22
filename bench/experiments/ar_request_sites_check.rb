# frozen_string_literal: true

# External, production Rack fallback controls for the Fizzy bucket call site.
# All mutations happen after authentication, on entry to the real partial;
# no application/config file is edited. Each arm owns a fresh seed copy.
require "json"
require "fileutils"
require "digest"
require_relative "ar_request_sites_db"
require_relative "jit_guards_export"
load ENV.fetch("JIT_GUARDS_HARNESS")

module ARSiteChecks
  CASES = (ENV["AR_GUARD_TRANSITIVE"] == "1" ? %w[baseline transitive_scope restored] :
    %w[baseline warm_baseline changed_scope added_default_scope current_scope global_scope
    reflection_changed association_loaded unexpected_receiver model_method_private
    relation_method_changed owner_empty_singleton owner_private_singleton user_empty_singleton
    user_singleton_reader owner_reader_private owner_reader_undefined source_pin_mismatch restored]).freeze
  class << self
    attr_accessor :current, :entered, :undo

    def clear_templates
      ActionView::LookupContext::DetailsKey.clear
    end

    def change(bucket, locals)
      self.entered += 1
      case current
      when "unexpected_receiver"
        require "delegate"
        return locals.merge(bucket: SimpleDelegator.new(bucket))
      when "association_loaded"
        bucket.association(:bubbles).loaded!
      when "owner_empty_singleton"
        bucket.singleton_class
      when "owner_private_singleton"
        bucket.singleton_class.send(:private, :bubbles)
      when "user_empty_singleton"
        Current.user.singleton_class
      when "user_singleton_reader"
        user = Current.user
        value = user.id
        user.define_singleton_method(:id) { value }
      end
      return locals if undo
      case current
      when "changed_scope"
        original = Bubble.method(:active)
        Bubble.define_singleton_method(:active) { original.call.where(id: -404) }
        self.undo = -> { Bubble.singleton_class.send(:define_method, :active, original) }
      when "added_default_scope"
        original = Bubble.default_scopes
        Bubble.send(:default_scope, -> { where(id: -404) })
        self.undo = -> { Bubble.default_scopes = original }
      when "reflection_changed"
        original = Bucket._reflections
        replacement = original.fetch(:bubbles).dup
        replacement.instance_variable_set(:@scope, proc { where(id: -404) })
        Bucket._reflections = original.merge(bubbles: replacement)
        Bucket.clear_reflections_cache
        self.undo = -> { Bucket._reflections = original; Bucket.clear_reflections_cache }
      when "model_method_private"
        Bubble.singleton_class.send(:private, :active)
        self.undo = -> { Bubble.singleton_class.send(:public, :active) }
      when "relation_method_changed"
        holder = Bubble.send(:relation_delegate_class, ActiveRecord::AssociationRelation)
        holder.send(:define_method, :limit) { |value| super(value) }
        self.undo = -> { holder.send(:remove_method, :limit) }
      when "transitive_scope"
        original = ActiveRecord::Relation.instance_method(:_exec_scope)
        visibility = ActiveRecord::Relation.private_method_defined?(:_exec_scope) ? :private : :public
        ActiveRecord::Relation.send(:define_method, :_exec_scope) do |*args, &block|
          original.bind_call(self, *args, &block).where(id: -404)
        end
        ActiveRecord::Relation.send(visibility, :_exec_scope)
        self.undo = -> {
          ActiveRecord::Relation.send(:define_method, :_exec_scope, original)
          ActiveRecord::Relation.send(visibility, :_exec_scope)
        }
      when "owner_reader_private"
        inherited = Bucket.instance_method(:bubbles).owner != Bucket
        Bucket.send(:private, :bubbles)
        self.undo = -> { inherited ? Bucket.send(:remove_method, :bubbles) : Bucket.send(:public, :bubbles) }
      when "owner_reader_undefined"
        original = Bucket.instance_method(:bubbles)
        raise "expected generated association reader" if original.owner == Bucket
        Bucket.send(:undef_method, :bubbles)
        self.undo = -> { Bucket.send(:define_method, :bubbles, original); Bucket.send(:remove_method, :bubbles) }
      end
      locals
    end

    def run(config, state, arm)
      require File.join(config.fetch("app"), "config/environment")
      raise "actual YJIT required" unless RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
      require config.fetch("exploration_setup")
      NativeBench::Exploration.install(config: config, state: state, arm: arm)
      # A diagnostic shadow exception must not stand in for a runtime guard.
      ARCallsite.shadow = false if ENV["AR_GUARD_TRANSITIVE"] == "1"
      require File.expand_path("../bench/experiments/fizzy_link_vector", File.dirname(config.fetch("harness")))
      return cases(config, state, arm) unless ENV["AR_GUARD_FORK"] == "1"

      reader, writer = IO.pipe
      pid = fork do
        reader.close
        ActiveRecord::Base.connection_handler.clear_all_connections!
        Marshal.dump(cases(config, state, arm).merge("forked" => true, "pid" => Process.pid), writer)
        writer.close
        exit! 0
      end
      writer.close
      result = Marshal.load(reader)
      _, status = Process.wait2(pid)
      raise "forked guard worker failed" unless status.success? && result.fetch("pid") != Process.pid
      result
    ensure
      reader&.close unless reader&.closed?
      writer&.close unless writer&.closed?
      Process.wait(pid) if pid && !status
    end

    def cases(config, state, arm)
      raise "actual worker YJIT required" unless RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
      ActionView::Template.prepend(MidRequest)
      ActionView::Template::Handlers::ERB.prepend(SourceMismatch)
      app_pin = BlogProduction::Entropy.source_pin(config.fetch("app"))
      random_seed = ENV["AR_GUARD_RANDOM_SEED"]&.then { Integer(_1) }
      Kernel.srand(random_seed) if random_seed
      if ENV["AR_GUARD_NATIVE_WARM"] == "1"
        warm = -> do
          workload = NativeBench.routes(config, state, arm)
          50.times { workload.each_value { raise "warm GET failed" unless _1.call.status == 200 } }
        end
        if random_seed
          _, warm_evidence = BlogProduction::Entropy.with(random_seed, "db-warm", requests: 52, wall_clock: true, &warm)
          raise "controlled warmup entropy failed" unless warm_evidence.fetch("errors").empty?
        else
          warm.call
        end
      end
      rows = CASES.to_h do |name|
        self.current, self.entered, self.undo = name, 0, nil
        clear_templates if name == "source_pin_mismatch" || name == "restored"
        seeds = [0, 1].to_h do |seed|
          before = ARRequestSites.counts.dup
          trace = []
          subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |*args|
            payload = args.last
            trace << [payload[:sql], payload[:name], payload[:binds].map {
              _1.respond_to?(:value_for_database) ? Lowrail::ARShadow.bind(_1) : [_1.class.name, _1]
            }, !!payload[:cached]]
          end
          response, evidence = NativeBench::Exploration.validation_request(route: "GET /buckets", seed: seed, request: -> { raise "unused" })
          raise "mutation did not run #{name}" unless entered.positive?
          raise "entropy control #{name}: #{evidence.inspect}" unless evidence.fetch("passed")
          expected_status = %w[model_method_private owner_private_singleton owner_reader_private owner_reader_undefined].include?(name) ? 500 : 200
          raise "unexpected status #{name}: #{response.status}" unless response.status == expected_status
          delta = ARRequestSites.counts.to_h { |key, value| [key, value - before.fetch(key, 0)] }
          if arm == "on" && name != "transitive_scope"
            hits = delta.fetch("bucket:hit", 0)
            if %w[baseline warm_baseline restored].include?(name)
              raise "positive control has no hits #{name}" unless hits.positive?
              raise "positive control fell back #{name}" unless delta.fetch("bucket:fallback", 0).zero?
            else
              raise "mutation still used cached plan #{name}" unless hits.zero?
              unless name == "source_pin_mismatch"
                raise "no stock fallback #{name}" unless delta.fetch("bucket:fallback", 0).positive?
              end
            end
          end
          databases = FizzyLinkVector.effects(state)
          [seed, NativeBench.response_digest(response).merge("evidence" => evidence,
            "counts_delta" => delta, "sql_trace" => trace,
            "sql_capture" => NativeBench::Exploration.sql_value(trace),
            "db_audit" => DirectSiteDB.capture(databases),
            "db_components_sha256" => databases.transform_values { Digest::SHA256.hexdigest(JSON.generate(_1)) },
            "db_sha256" => Digest::SHA256.hexdigest(JSON.generate(databases)))]
        ensure
          ActiveSupport::Notifications.unsubscribe(subscription) if subscription
          undo&.call
          self.undo = nil
        end
        [name, seeds]
      end
      raise "application source changed" unless BlogProduction::Entropy.source_pin(config.fetch("app")) == app_pin
      {"arm" => arm, "source_sha256" => app_pin, "yjit" => RubyVM::YJIT.enabled?,
        "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?),
        "sql_shadow" => ARCallsite.shadow,
        "kernel_random_seed" => random_seed, "warm_entropy" => warm_evidence, "cases" => rows}
    end
  end

  module MidRequest
    def render(view, locals, *args, **kwargs, &block)
      return super unless identifier.end_with?("/app/views/buckets/_bucket.html.erb") && ARSiteChecks.current
      locals = ARSiteChecks.change(locals.fetch(:bucket), locals)
      case ARSiteChecks.current
      when "current_scope"
        Bubble.where(id: -404).scoping { super(view, locals, *args, **kwargs, &block) }
      when "global_scope"
        Bubble.where(id: -404).scoping(all_queries: true) { super(view, locals, *args, **kwargs, &block) }
      else
        super(view, locals, *args, **kwargs, &block)
      end
    end
  end

  module SourceMismatch
    def call(template, source)
      if ARSiteChecks.current == "source_pin_mismatch" && template.identifier.end_with?("/app/views/buckets/_bucket.html.erb")
        source += "<%# a source-pin mismatch that changes no rendered bytes %>"
      end
      super(template, source)
    end
  end
end

if ARGV.first == "--worker"
  _, config, state, arm, destination = ARGV
  File.write(destination, JSON.pretty_generate(ARSiteChecks.run(JSON.parse(File.read(config)), state, arm)))
elsif $PROGRAM_NAME == __FILE__
  config_path, output = ARGV
  abort "usage: ruby ar_request_sites_check.rb CONFIG NEW_OUTPUT" unless config_path && output
  raise "new output required" if File.exist?(output)
  FileUtils.mkdir_p(output)
  config = JSON.parse(File.read(config_path))
  results = NativeBench::ARMS.to_h do |arm|
    state = File.expand_path("#{output}/#{arm}-state")
    FileUtils.cp_r(config.fetch("seed"), state)
    FileUtils.rm_rf(File.join(config.fetch("app"), "tmp"))
    env = NativeBench.environment(config, state).merge("LOWRAIL" => arm == "on" ? "1" : "0", "LOWRAIL_STATS" => "")
    env.merge!("BUNDLER_VERSION" => "4.0.20", "RUBYOPT" => "-rbundler/setup -I#{File.expand_path('../../gem/lib', __dir__)} -rlowrail/setup")
    destination = File.expand_path("#{output}/#{arm}.json")
    ok = system(env, RbConfig.ruby, "--yjit", File.expand_path(__FILE__), "--worker", File.expand_path(config_path),
      state, arm, destination, chdir: config.fetch("app"), out: "#{output}/#{arm}.log", err: [:child, :out])
    raise "worker failed #{arm}; see #{output}/#{arm}.log" unless ok
    [arm, JSON.parse(File.read(destination))]
  end
  checks = ARSiteChecks::CASES.to_h do |name|
    [name, %w[0 1].to_h do |seed|
      values = results.transform_values { _1.fetch("cases").fetch(name).fetch(seed) }
      fields = %w[status body_sha256 headers_sha256 db_sha256]
      equality = fields.to_h { |field| [field, values.values.map { _1.fetch(field) }.uniq.size == 1] }
      sql = values.values.map { _1.fetch("evidence").fetch("sql_sha256") }.uniq.size == 1
      components = %w[primary cache queue cable].to_h { |db| [db, values.values.map { _1.fetch("db_components_sha256").fetch(db) }.uniq.size == 1] }
      refused = name != "transitive_scope" || (values.fetch("on").fetch("counts_delta").fetch("bucket:hit", 0).zero? &&
        values.fetch("on").fetch("counts_delta").fetch("bucket:fallback", 0).positive?)
      [seed, {"equal" => equality, "sql_equal" => sql, "database_equal" => components,
        "response_equal" => equality.except("db_sha256").values.all?,
        "stale_plan_refused" => refused, "passed" => equality.values.all? && sql && refused}]
    end]
  end
  passed = checks.values.all? { _1.values.all? { |row| row.fetch("passed") } }
  certificate = checks.values.all? { _1.values.all? { |row|
    row.fetch("response_equal") && row.fetch("sql_equal") && row.fetch("stale_plan_refused")
  } }
  db_audit = DirectSiteDB.compare(results)
  sources = %w[ar_request_sites.rb ar_request_sites_check.rb ar_request_sites_db.rb ar_callsite.rb jit_guards_export.rb]
  File.write("#{output}/result.json", JSON.pretty_generate("passed" => passed,
    "response_sql_certificate_passed" => certificate, "checks" => checks, "db_audit" => db_audit, "workers" => results,
    "sources" => sources.to_h { [_1, Digest::SHA256.file(File.join(__dir__, _1)).hexdigest] }))
  JitGuardsExport.publish_control("#{output}/result.json", "#{output}/public.json")
  puts "response/SQL and stale-plan certificate: #{certificate ? 'PASS' : 'FAIL'}"
  puts "raw whole-DB equality: #{checks.values.all? { _1.values.all? { |row| row.fetch('equal').fetch('db_sha256') } } ? 'PASS' : 'FAIL'}"
  puts "complete DB audit with declared off/off exclusions: #{db_audit.fetch('passed_with_declared_exclusions') ? 'PASS' : 'FAIL'}"
  checks.each { |name, seeds| puts "#{name}: #{seeds.values.all? { _1.fetch('passed') } ? 'PASS' : 'FAIL'}" }
  # Transitive refusal has its own exit, distinct from retained raw-DB rejection.
  exit 3 if ENV["AR_GUARD_TRANSITIVE"] == "1" && !certificate
  exit(passed ? 0 : 2)
end
