# frozen_string_literal: true

# Test/verify observer, never loaded by the guarded tier. TracePoints observe
# operations rather than wrapping Module#private/class_eval (which would change
# lexical semantics). This is evidence about exercised code, NOT enforcement.
require_relative "seal_rules"
require_relative "seal_snapshot"

module Lowrail
  module Seal
    EPOCH = [0]
    NAME = Module.instance_method(:name)
    CLASS = Kernel.instance_method(:class)
    SINGLETON = Kernel.instance_method(:singleton_class)
    ANCESTORS = Module.instance_method(:ancestors)
    METHODS = Module.instance_method(:instance_methods)
    PRIVATE_METHODS = Module.instance_method(:private_instance_methods)
    METHOD = Module.instance_method(:instance_method)
    HASH_PAIRS = Hash.instance_method(:to_a)
    HASH_DEFAULT = Hash.instance_method(:default)
    HASH_DEFAULT_PROC = Hash.instance_method(:default_proc)
    MUTATIONS = %i[define_method define_singleton_method alias_method remove_method undef_method
                   include prepend extend append_features prepend_features extend_object
                   class_eval module_eval class_exec module_exec eval const_set remove_const autoload
                   public private protected public_class_method private_class_method
                   method_added method_removed method_undefined singleton_method_added
                   singleton_method_removed singleton_method_undefined const_added].freeze
    CONTAINERS = %i[[]= store clear replace merge! update delete delete_if keep_if reject! select!
                    shift pop push << concat unshift insert collect! map! compact! flatten!
                    reverse! rotate! sort! sort_by! uniq! fill slice! default= default_proc=].freeze
    ROUTES = %i[draw clear! add_route finalize! reload! execute_if_updated].freeze
    SUBSCRIPTIONS = %i[subscribe unsubscribe subscribed monotonic_subscribe notifier=].freeze

    class << self
      attr_reader :ledger, :targets, :tests, :errors

      def install(dir:, root: Dir.pwd, targets: nil)
        return if @installed
        @installed = true
        @dir, @root, @selection = dir, File.expand_path(root), targets
        @ledger, @tests, @errors = [], {}, []
        @targets = {}.compare_by_identity
        @containers = {}.compare_by_identity
        @tables = {}.compare_by_identity
        @structural = {}.compare_by_identity
        @candidates = Hash.new { |h, k| h[k] = [] }
        @comparisons = []
        @route_objects = {}.compare_by_identity
        @active_tests = {}
        at_exit { write }
        @boot = TracePoint.new(:end, :return) do |event|
          attach_tests
          if event.event == :return && event.method_id == :initialize! &&
              defined?(::Rails::Application) && ::Rails::Application === event.self
            activate
          end
        end
        @boot.enable
        activate if defined?(::Rails.application) && ::Rails.application&.initialized?
      end

      def activate
        return if @sealed || @activating
        @activating = true
        require_relative "materialize"
        Materialize.run(app_root: @root, measure: false, record: ->(where, error) {
          @errors << {"where" => where, "error" => "#{error.class}: #{error.message.lines.first&.strip}"}
        })
        # These framework dependencies are deliberately lazy even after Rails'
        # eager loaders. Resolve them before inventorying the sealed surface,
        # not during the first request/fixture quote. Guarded boot is unchanged.
        require "useragent" if defined?(::ActionController::AllowBrowser)
        ::ActiveSupport::Multibyte::Chars if defined?(::ActiveSupport::Multibyte)
        ::ActionDispatch::Routing::RoutesProxy if defined?(::ActionDispatch::Routing)
        if defined?(::ActiveRecord::Base)
          ::ActiveRecord::InternalMetadata
          ::ActiveRecord::SchemaMigration
        end
        ::Thor::Group if defined?(::Thor)
        ::Rails.application.env_config if defined?(::Rails.application) && ::Rails.application
        modules = ObjectSpace.each_object(Module).to_a
        modules.each do |mod|
          name = NAME.bind_call(mod)
          next unless name && !name.start_with?("Lowrail")
          selected = if @selection
            @selection.include?(name)
          else
            name.match?(/\A(?:Rails|ActiveSupport|ActiveModel|ActiveRecord|Action\w+)(?:::|\z)/) ||
              %w[Object Kernel Module Class String Hash Array].include?(name) || app_module?(mod)
          end
          certify(mod, name) if selected
        end
        if defined?(::Rails.application) && ::Rails.application
          config = ::Rails.application.config
          config.instance_variables.each { watch(config.instance_variable_get(_1), "Rails.application.config#{_1}") }
          watch(::Rails.application.routes.default_url_options, "routes.default_url_options")
          routes = ::Rails.application.routes
          @route_objects[routes] = "Rails.application.routes"
          @route_objects[routes.named_routes] = "Rails.application.routes.named_routes"
        end
        if defined?(::ActionView::Helpers::TagHelper)
          %i[TAG_TYPES PRE_CONTENT_STRINGS].each do |name|
            table = ::ActionView::Helpers::TagHelper.const_get(name, false)
            @tables[table] = {label: "ActionView::Helpers::TagHelper::#{name}", snapshot: table_snapshot(table)}
          end
        end
        attach_tests
        @boot&.disable
        @targets.each_key { |holder| @structural[holder] = SealSnapshot.capture(holder) }
        @sealed = true
        @trace = TracePoint.new(:call, :c_call, :return, :c_return) { observe(_1) }
        @trace.enable
      rescue StandardError, ScriptError => error
        @errors << {"where" => "seal", "error" => "#{error.class}: #{error.message}"}
        EPOCH[0] += 1
      ensure
        @activating = false
      end

      def app_module?(mod)
        (METHODS.bind_call(mod, false) + PRIVATE_METHODS.bind_call(mod, false)).any? do |name|
          path = METHOD.bind_call(mod, name).source_location&.first
          path && path.start_with?(File.join(@root, "app/"))
        end
      end

      def certify(mod, name)
        [mod, SINGLETON.bind_call(mod)].each do |holder|
          ANCESTORS.bind_call(holder).each do |ancestor|
            @targets[ancestor] ||= NAME.bind_call(ancestor) || "#{name}::<anonymous ancestor>"
          end
          @targets[holder] = holder.equal?(mod) ? name : "#{name}.singleton_class"
        end
      end

      def watch(value, label)
        return unless Hash === value || Array === value || String === value
        return if @containers.key?(value) || value.frozen?
        @containers[value] = label
        case value
        when Hash then value.each { |key, child| watch(child, "#{label}[#{key.inspect}]") if Symbol === key || String === key }
        when Array then value.each_with_index { |child, i| watch(child, "#{label}[#{i}]") }
        end
      end

      def observe(event)
        method = event.method_id
        receiver = event.self
        if event.event == :return || event.event == :c_return
          # Values inserted into an already-watched config remain watched.
          if CONTAINERS.include?(method) && (label = @containers[receiver])
            case receiver
            when Hash then receiver.each { |key, child| watch(child, "#{label}[#{key.inspect}]") if Symbol === key || String === key }
            when Array then receiver.each_with_index { |child, i| watch(child, "#{label}[#{i}]") }
            end
          end
          return
        end
        return if event.path == __FILE__
        target = @targets[receiver]
        if !target && !(Module === receiver) && %i[define_singleton_method singleton_method_added singleton_method_removed singleton_method_undefined extend].include?(method)
          target = @targets[CLASS.bind_call(receiver)]
        end
        if MUTATIONS.include?(method) && target
          if %i[define_singleton_method singleton_method_added singleton_method_removed singleton_method_undefined extend public_class_method private_class_method].include?(method)
            holder = SINGLETON.bind_call(receiver)
            @targets[holder] ||= "#{target}::<observed instance singleton>"
            # Before an explicit API, capture a newly encountered instance's
            # holder. A callback first seen after mutation cannot establish its
            # previous state; it remains only a hint.
            if %i[define_singleton_method extend public_class_method private_class_method].include?(method)
              @structural[holder] ||= SealSnapshot.capture(holder)
            end
            target = @targets.fetch(holder)
          end
          record("method_or_constant_mutation", target, method, event)
        elsif SUBSCRIPTIONS.include?(method) && defined?(::ActiveSupport::Notifications) &&
            (receiver.equal?(::ActiveSupport::Notifications) || (defined?(::ActiveSupport::Notifications::Fanout) && ::ActiveSupport::Notifications::Fanout === receiver))
          record("notifications_changed", "ActiveSupport::Notifications", method, event)
        elsif ROUTES.include?(method) && (route = @route_objects[receiver])
          record("routes_changed", route, method, event)
        elsif CONTAINERS.include?(method) && (table = @tables[receiver])
          record("framework_table_changed", table.fetch(:label), method, event)
        elsif CONTAINERS.include?(method) && (config = @containers[receiver])
          record("config_changed", config, method, event)
        end
      end

      def record(pattern, target, operation, event)
        EPOCH[0] += 1
        locations = caller_locations(2, 40)
        context = locations.reject { _1.path == __FILE__ }.first(24).map { {"file" => _1.path, "line" => _1.lineno, "label" => _1.base_label} }
        location = locations.find { |loc| loc.path.start_with?("#{@root}/test/", "#{@root}/spec/") } ||
          locations.find { |loc| loc.path != __FILE__ && !loc.path.start_with?("<internal:") }
        file, line = location ? [location.path, location.lineno] : [event.path, event.lineno]
        stub = locations.any? { |loc| loc.path.match?(%r{/(?:mocha(?:-[^/]+)?/|minitest/mock\.rb|rspec-mocks)}) }
        test = @active_tests[Thread.current]
        @tests[test] = "this test runs unoptimized" if test
        # An API/callback is a candidate, not proof that its receiver changed.
        # In particular append_features/extend_object run on the source module.
        finding = SealRules.finding(SealRules::PATTERNS.fetch(pattern), confidence: "hint",
          file: event.path, line: event.lineno, root: @root, target: target,
          pattern: pattern, operation: operation.to_s, test: test, test_double: stub,
          observed_at: "#{event.path}:#{event.lineno}", caller_file: file, caller_line: line,
          context: context, detail: "API/callback observed; state change is not yet confirmed.")
        finding["remedy"] = "Keep the test double; this test runs unoptimized (process-wide deopt persists after restoration)." if stub
        @ledger << finding
        @candidates[target] << finding
      end

      def start_test(key)
        @active_tests[Thread.current] = key
        checkpoint if @sealed
        @tests[key] = EPOCH[0].zero? ? "optimized eligible (not coverage)" : "this test runs unoptimized"
      end

      def finish_test
        checkpoint if @sealed
        @active_tests.delete(Thread.current)
      end

      def checkpoint
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        @trace&.disable
        @structural.each do |holder, previous|
          current = SealSnapshot.capture(holder)
          changes = SealSnapshot.diff(previous, current)
          unless changes.empty?
            EPOCH[0] += 1
            target = @targets.fetch(holder)
            candidates = @candidates[target]
            test = @active_tests[Thread.current]
            @tests[test] = "this test runs unoptimized" if test
            # Keep the candidate's location separate from the proof boundary.
            source = candidates.last
            location = caller_locations.find { _1.path != __FILE__ }
            @ledger << SealRules.finding("SEAL001", confidence: "proven", root: @root,
              file: source ? source.fetch("file") : (location&.path || "<seal-check snapshot>"),
              line: source ? source.fetch("line") : (location&.lineno || 0),
              target: target, test: test, pattern: "method_or_constant_mutation", operation: "state_difference",
              changes: changes, candidates: candidates.map { _1.slice("file", "line", "operation", "origin", "context") },
              location_kind: source ? "candidate; confirmed at checkpoint" : "checkpoint; mutation source unknown",
              detail: "Certified destination state differs from the previous checkpoint.")
          end
          @structural[holder] = current
        end
        @candidates.clear
        check_tables
      rescue StandardError, ScriptError => error
        EPOCH[0] += 1
        @errors << {"where" => "seal checkpoint", "error" => "#{error.class}: #{error.message}"}
      ensure
        @comparisons << {"test" => @active_tests[Thread.current], "seconds" => Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
          "holders" => @structural.size}
        @trace&.enable if @sealed && !@writing
      end

      def table_snapshot(table)
        copy = ->(value) { String === value ? [value.b.dup.freeze, value.encoding.name] : value }
        [HASH_PAIRS.bind_call(table).map { |key, value| [copy.call(key), copy.call(value)] },
          copy.call(HASH_DEFAULT.bind_call(table)), HASH_DEFAULT_PROC.bind_call(table)]
      end

      def check_tables
        @tables.each do |table, state|
          current = table_snapshot(table)
          next if current == state.fetch(:snapshot)
          EPOCH[0] += 1
          test = @active_tests[Thread.current]
          @tests[test] = "this test runs unoptimized" if test
          location = caller_locations.find { _1.path != __FILE__ }
          @ledger << SealRules.finding("SEAL008", confidence: "proven", root: @root,
            file: location&.path || "<seal-check snapshot>", line: location&.lineno || 0,
            target: state.fetch(:label), test: test, pattern: "framework_table_changed",
            operation: "snapshot_difference", detail: "Contents/default/default_proc differ from the previous checkpoint; mutation source is unknown. This is the observation location.")
          state[:snapshot] = current
        end
      end

      def attach_tests
        if !@minitest && defined?(::Minitest::Test)
          @minitest = true
          ::Minitest::Test.prepend(TestRun)
        end
        if !@rspec && defined?(::RSpec) && ::RSpec.respond_to?(:configure)
          @rspec = true
          ::RSpec.configure do |config|
            config.around do |example|
              Lowrail::Seal.start_test(example.id)
              begin
                example.run
              ensure
                Lowrail::Seal.finish_test
              end
            end
          end
        end
      end

      def write
        @writing = true
        @trace&.disable
        @boot&.disable
        checkpoint if @sealed
        require "json"
        require "fileutils"
        FileUtils.mkdir_p(@dir)
        environment = defined?(::Rails.env) ? ::Rails.env.to_s : ENV["RAILS_ENV"]
        @ledger.each do |row|
          row["classification"] = SealRules.classify(row, root: @root, environment: environment)
          case row.dig("classification", "kind")
          when "test_only"
            row["remedy"] = "Test-only machinery in RAILS_ENV=test: retain it and run this process unoptimized. Not a production-contract violation."
          when "lazy_materialization"
            row["remedy"] = "Finish this lazy generation/loading before the seal, or exclude the target. This census has not proved the later seal point."
          end
        end
        data = {"format" => 1, "pid" => Process.pid, "sealed" => !!@sealed,
          "epoch" => EPOCH[0], "targets" => @targets.values.uniq.sort,
          "tests" => @tests, "ledger" => @ledger, "errors" => @errors, "comparisons" => @comparisons,
          "limits" => "Destination snapshots prove surviving method/visibility/ancestor/constant deltas, including suppressed callbacks. Restored-between-checkpoint edits, inherited undef tombstones, unknown instance singletons and opaque/native writes may escape. API callbacks alone are hints. Not production enforcement."}
        File.write(File.join(@dir, "seal-#{Process.pid}.json"), JSON.pretty_generate(data))
      end
    end

    module TestRun
      def run(...)
        Lowrail::Seal.start_test("#{self.class.name}##{name}")
        super
      ensure
        Lowrail::Seal.finish_test
      end
    end
  end
end

if ENV["LOWRAIL_SEAL_CHECK"]
  Lowrail::Seal.install(dir: ENV.fetch("LOWRAIL_SEAL_CHECK"), root: ENV.fetch("LOWRAIL_SEAL_ROOT", Dir.pwd),
    targets: ENV["LOWRAIL_SEAL_TARGETS"]&.split(","))
end
