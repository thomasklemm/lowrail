# frozen_string_literal: true

module Lowrail
  # Verification authority is separate from Seal: it neither installs the
  # effectful seal nor resets its process-wide epoch or diagnostic ledger.
  module TestCertificate
    TIER = "sealed-test-v1"
    PASSES = %w[active_record/instantiate sealed/link_to sealed/form_scaffold].freeze
    UNOBSERVED = {
      "sealed/link_to" => "verification_literal_table_observer_unavailable",
      "sealed/form_scaffold" => "verification_form_config_schema_translation_observer_unavailable"
    }.freeze
    IVAR = Kernel.instance_method(:instance_variable_get)
    NAME = Module.instance_method(:name)
    CLASS = Kernel.instance_method(:class)
    CONFIG_FIELDS = %i[eager_load cache_classes enable_reloading cache_store yjit consider_all_requests_local].freeze
    BOOTSNAP_FIELDS = %i[development_mode load_path_cache compile_cache_iseq compile_cache_yaml
      compile_cache_json readonly revalidation ignore_directories].freeze
    MUTATIONS = %i[method_added method_removed method_undefined singleton_method_added
      singleton_method_removed singleton_method_undefined include prepend extend append_features
      prepend_features extend_object alias_method define_method define_singleton_method remove_method
      undef_method public protected private public_class_method private_class_method const_set remove_const
      autoload class_eval module_eval instance_eval instance_variable_set remove_instance_variable
      reset_column_information reload_schema_from_cache initialize_load_schema_monitor
      default_scope attribute enum serialize store_accessor []= store clear replace delete delete_if keep_if
      merge! update shift pop push unshift << concat insert collect! map! reject! select! slice! compact!
      flatten! reverse! rotate! sort! sort_by! uniq! fill setbyte force_encoding encode! gsub! sub!
      subscribe unsubscribe subscribed].freeze

    class << self
      attr_reader :status

      def requested? = ENV["LOWRAIL_VERIFY_TEST"] == "1"

      # Observe the real setup call, before Bootsnap is loaded. Cache directory
      # contents/temperature are never an authority. Unknown effective policy
      # is a refusal, not an excuse to disable Bootsnap or warm the app.
      def observe_boot
        return if @boot_observer
        @status = "pending"
        @pid = Process.pid
        @deopts, @refusals, @snapshots = {}, {}, {}
        @boot_observer = TracePoint.new(:call) do |event|
          next unless event.method_id == :setup && event.self.equal?(Lowrail.loaded_constant("Bootsnap"))
          @bootsnap = BOOTSNAP_FIELDS.to_h do |field|
            [field.to_s, scalar(event.binding.local_variable_get(field))]
          end
        rescue StandardError
          @bootsnap = nil
        end
        @boot_observer.enable
      end

      # Only explicitly selected, non-secret policy inputs, through core
      # reflection. No app getter, inspect, to_s or arbitrary serialization.
      def scalar(value)
        case NAME.bind_call(CLASS.bind_call(value))
        when "NilClass", "TrueClass", "FalseClass", "Integer", "String" then value
        when "Symbol" then {"symbol" => Symbol.instance_method(:name).bind_call(value)}
        when "Array" then Array.instance_method(:map).bind_call(value) { scalar(_1) }
        else raise ArgumentError, "unobservable policy value"
        end
      end

      def policy
        raise ArgumentError, "verification_test_environment" unless ENV["RAILS_ENV"] == "test"
        raise ArgumentError, "verification_workers_unknown_or_parallel" unless ENV["PARALLEL_WORKERS"] == "1"
        app = IVAR.bind_call(Lowrail.loaded_constant("Rails"), :@application)
        config = app && IVAR.bind_call(app, :@config)
        raise ArgumentError, "verification_test_initialization_pending" unless config
        executor = IVAR.bind_call(Lowrail.loaded_constant("Minitest"), :@parallel_executor)
        raise ArgumentError, "verification_parallel_policy_unknown" unless executor &&
          NAME.bind_call(CLASS.bind_call(executor)) == "ActiveSupport::Testing::ParallelizeExecutor" &&
          IVAR.bind_call(executor, :@size) == 1 && IVAR.bind_call(executor, :@parallelize_with) == :processes &&
          IVAR.bind_call(executor, :@parallelized) == false
        raise ArgumentError, "verification_bootsnap_policy_unknown" unless @bootsnap
        compiler = Lowrail.loaded_constant("Bootsnap::CompileCache::ISeq")
        default = Lowrail.loaded_constant("Bootsnap::CompileCache::ISeq::DEFAULT")
        raise ArgumentError, "verification_bootsnap_compiler_unknown" unless compiler && default &&
          IVAR.bind_call(compiler, :@default_compiler).equal?(default) &&
          IVAR.bind_call(compiler, :@compiler_selector).nil? && IVAR.bind_call(default, :@options).nil? &&
          IVAR.bind_call(default, :@compile_options).nil?
        raise ArgumentError, "verification_bootsnap_custom_config_unknown" if ENV["BOOTSNAP_CONFIG"] || File.file?("config/bootsnap.rb")
        values = CONFIG_FIELDS.to_h { [_1.to_s, scalar(IVAR.bind_call(config, :"@#{_1}"))] }
        raise ArgumentError, "verification_eager_load_unknown" unless [true, false].include?(values["eager_load"])
        raise ArgumentError, "verification_cache_store_unsupported" unless [:null_store, :memory_store].include?(IVAR.bind_call(config, :@cache_store))
        {"environment" => "test", "config" => values, "workers" => 1, "forks" => false,
          "ci" => ENV["CI"], "bootsnap" => @bootsnap,
          "bootsnap_version" => Gem.loaded_specs.fetch("bootsnap").version.to_s,
          "compile_option" => Manifest.compile_option_fingerprint, "jit" => Lowrail.jit_mode}
      end

      def sources(root)
        paths = Dir.glob("{app,config,lib,test,db}/**/*.{rb,rake,erb,yml,yaml,sql}", base: root).sort
        paths |= %w[Gemfile Gemfile.lock Rakefile bin/rails config/boot.rb test/test_helper.rb test/application_system_test_case.rb].select { File.file?(File.join(root, _1)) }
        paths.to_h { [_1, Manifest.sha256_file(File.join(root, _1))] }
      end

      def certificate(root)
        runtime = Dir[File.join(__dir__, "*.rb"), File.join(Gem.loaded_specs.fetch("bootsnap").full_gem_path, "lib/**/*.rb")].sort
        {"version" => 1, "mode" => "verification-only", "policy" => policy, "source_set" => sources(root),
          "runtime_sources" => runtime.to_h { [_1, Manifest.sha256_file(_1)] }}
      end

      def configure(manifest, root)
        observe_boot
        @manifest, @root = manifest, root
        @certificate = manifest.verification_test
        require_relative "stats"
        Stats.enable!
        require_relative "seal_snapshot"
        Process.singleton_class.prepend(ForkHook) unless Process.singleton_class < ForkHook
        @observer = TracePoint.new(:call, :c_call) do |event|
          forked! if @pid != Process.pid
          next unless @status == "active"
          if Module === event.self && NAME.bind_call(event.self)&.match?(/\ABootsnap(?:::|\z)/) &&
              (MUTATIONS.include?(event.method_id) || /\A\w+[=!]\z/.match?(event.method_id) || %i[setup update_options].include?(event.method_id))
            refuse_all("verification_bootsnap_policy_mutation")
            next
          end
          next unless MUTATIONS.include?(event.method_id) || /\A[a-zA-Z_]\w*=\z/.match?(event.method_id)
          if event.self.equal?(@test_config)
            refuse_all("verification_policy_mutation:#{event.method_id}")
            next
          end
          @snapshots.each do |id, snapshot|
            retire(id, "dependent_state_mutation:#{event.method_id}") if snapshot[:holders].any? { _1.equal?(event.self) } ||
              snapshot[:objects].any? { _1.equal?(event.self) }
          end
        end
        @observer.enable
      end

      # Called by the real reporter only after normal helper loading and the
      # executor's startup, not Rails' earlier after_initialize callback.
      def test_initialized!
        return unless @manifest && @status == "pending"
        current = certificate(@root)
        return refuse_all("verification_config_or_source_set_mismatch") unless current == @certificate
        app = IVAR.bind_call(Lowrail.loaded_constant("Rails"), :@application)
        @test_config = IVAR.bind_call(app, :@config)
        @status = "active"
        G.clear; K.fill(Lowrail.const_get(:NO_RECEIVER, false)); V.clear; Stats::STATE.clear
        @activations&.each(&:call)
      rescue StandardError, ScriptError => error
        refuse_all(error.message)
      end

      def defer(&activate) = (@activations ||= []) << activate

      def active?
        return false unless @manifest
        forked! unless @pid == Process.pid
        @status == "active" && ENV["RAILS_ENV"] == "test"
      end

      def allowed?(id)
        return false unless active? && !@refusals.key?(id)
        return refuse_all("verification_policy_or_source_drift") unless certificate(@root) == @certificate
        unit = @manifest.units.find { _1.fetch("id") == id }
        reason = unit && UNOBSERVED[unit.fetch("pass")]
        return retire(id, reason) if reason
        snapshot = @snapshots[id]
        return true unless snapshot
        snapshot[:states].each do |holder, before|
          after = method_state(holder)
          return retire(id, "dependent_method_or_ancestor_drift") unless SealSnapshot.diff(before, after).empty?
        end
        true
      rescue StandardError, ScriptError
        retire(id, "verification_observation_unknown")
      end

      def watch(id, holders)
        return if @snapshots.key?(id)
        holders = holders.compact.uniq
        chains = holders.flat_map { SealSnapshot::ANCESTORS.bind_call(_1) }.uniq
        app = IVAR.bind_call(Lowrail.loaded_constant("Rails"), :@application)
        objects = [IVAR.bind_call(app, :@config)]
        notifier = Lowrail.loaded_constant("ActiveSupport::Notifications")
        objects << notifier if notifier
        objects << IVAR.bind_call(notifier, :@notifier) if notifier
        @snapshots[id] = {holders: holders + chains,
          objects: objects.compact,
          states: chains.to_h { [_1, method_state(_1)] }}
      end

      # Do not enumerate/read unrelated constants (deprecated bindings can
      # themselves emit warnings). Named dependencies are resolved without
      # autoloading by each existing pass's admission check.
      def method_state(holder)
        methods = {}
        {"public" => SealSnapshot::PUBLIC, "protected" => SealSnapshot::PROTECTED,
          "private" => SealSnapshot::PRIVATE}.each do |visibility, getter|
          getter.bind_call(holder, false).each { methods[_1] = [visibility, SealSnapshot::METHOD.bind_call(holder, _1)] }
        end
        {ancestors: SealSnapshot::ANCESTORS.bind_call(holder), methods: methods, constants: {}}
      end

      def retire(id, reason)
        unless @refusals.key?(id)
          @deopts[id] = @deopts.fetch(id, 0) + 1 if @snapshots.key?(id)
          @refusals[id] = [reason]
        end
        G[id] = false; K[id] = Lowrail.const_get(:NO_RECEIVER, false); V[id] = nil
        Stats::STATE[id] = false if defined?(Stats)
        false
      end

      def refuse_all(reason)
        @status = "refused"
        @manifest&.units&.each { retire(_1.fetch("id"), reason) }
        revoke_runtime
        false
      end

      def revoke_runtime
        G.clear; K.fill(Lowrail.const_get(:NO_RECEIVER, false)); V.clear
        Stats::STATE.clear if defined?(Stats)
        if defined?(Sealed)
          Sealed::ACTIVE[0] = false
          Sealed::BUILDERS.clear
          Thread.current[Sealed::REQUEST] = nil
        end
        if defined?(FormScaffold)
          FormScaffold.instance_variable_set(:@active, false)
          FormScaffold.instance_variable_set(:@pending, false)
          FormScaffold.instance_variable_set(:@attempted, true)
          %i[holder view_class article_class model_class form_class builder_class buffer_class table].each do |name|
            FormScaffold.instance_variable_set(:"@#{name}", nil)
          end
          FormScaffold.instance_variable_set(:@admission, {state: "refused", reason: "verification authority retired"}.freeze)
        end
        @manifest&.units&.each do |unit|
          name = unit.dig("ar_instantiate", "model")
          type = name && Lowrail.loaded_constant(name)
          type.instance_variable_set(:@_lowrail_instantiate, nil) if type
        end
      end

      def forked!
        return if @pid == Process.pid
        @pid = Process.pid
        Stats.reset_counts! if defined?(Stats)
        @deopts, @refusals = {}, {}
        refuse_all("verification_unexpected_pid_original_only")
        @snapshots.clear
      end

      def delivery_allowed?
        forked! if @pid && @pid != Process.pid
        @status != "refused"
      end

      def evidence
        active? if @pid
        {"state" => @status, "pid" => Process.pid, "unit_deopts" => @deopts.transform_keys(&:to_s),
          "unit_refusals" => @refusals.transform_keys(&:to_s)}
      end
    end

    module ForkHook
      def _fork
        pid = super
        TestCertificate.forked! if pid.zero?
        pid
      end
    end
  end
end
