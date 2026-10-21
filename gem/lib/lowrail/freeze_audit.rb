# frozen_string_literal: true

require "json"
require_relative "../lowrail"

module Lowrail
  # Disposable-process research tool, not an admission certificate. In particular,
  # a clean audit never enables a pass or changes an existing runtime guard.
  module FreezeAudit
    ANCESTORS = Module.instance_method(:ancestors)
    SINGLETON = Kernel.instance_method(:singleton_class)
    FREEZE = Kernel.instance_method(:freeze)
    NAME = Module.instance_method(:name)
    TO_S = Module.instance_method(:to_s)
    CLASS = Kernel.instance_method(:class)
    METHOD = Kernel.instance_method(:method)
    INSTANCE_METHOD = Module.instance_method(:instance_method)
    INSTANCE_METHODS = Module.instance_method(:instance_methods)
    PRIVATE_METHODS = Module.instance_method(:private_instance_methods)
    PROTECTED_METHODS = Module.instance_method(:protected_instance_methods)
    SINGLETON_METHODS = Kernel.instance_method(:singleton_methods)
    CORE = [Hash, Array, String, Enumerable].freeze

    class Session
      attr_reader :report

      def initialize(profile:, holders: [], roots: [], exclusions: [])
        raise ArgumentError, "profile must be holders, app, or core" unless %w[holders app core].include?(profile)
        @profile, @holders, @roots = profile, holders, roots.map { File.expand_path(_1) + "/" }
        @exclusions = exclusions
        @report = {"format" => 1, "ruby" => RUBY_DESCRIPTION, "profile" => profile,
          "lowrail" => ENV["LOWRAIL"], "enforced" => false, "holders" => [], "errors" => [], "stages" => []}
        @stage = "freeze"
      end

      # Caller must finish boot, eager loading and its declared warmup first.
      # No autoloads are resolved here. Ancestor closure includes singleton
      # chains: class methods can otherwise be shadowed on a superclass.
      def start!(audit: true)
        return self unless ENV["LOWRAIL_FREEZE"] == "1"
        raise ArgumentError, "holders profile requires explicit certified holders" if @profile == "holders" && @holders.empty?
        targets = @holders.dup
        if @profile != "holders"
          raise ArgumentError, "app/core profiles require source roots" if @roots.empty?
          ObjectSpace.each_object(Module) do |mod|
            next if mod.singleton_class? || CORE.include?(mod) || mod.equal?(FreezeAudit) || mod.equal?(Session)
            methods = INSTANCE_METHODS.bind_call(mod, false) + PRIVATE_METHODS.bind_call(mod, false) + PROTECTED_METHODS.bind_call(mod, false)
            locations = methods.map { INSTANCE_METHOD.bind_call(mod, _1).source_location }
            locations.concat(SINGLETON_METHODS.bind_call(mod, false).map { METHOD.bind_call(mod, _1).source_location })
            name = NAME.bind_call(mod)
            # MRI also exposes internal named classes with no Ruby constant
            # path (for example "buffer"). They still have method provenance.
            binding = (Lowrail.loaded_constant(name) rescue nil) if name
            if binding.equal?(mod)
              parts = name.split("::")
              parent = parts.size == 1 ? Object : Lowrail.loaded_constant(parts[0...-1].join("::"))
              locations << parent.const_source_location(parts.last, false) if parent
            end
            owned = locations.any? do |location|
              location && location.first && @roots.any? { location.first.start_with?(_1) }
            end
            targets << mod if owned
          end
          targets.concat(CORE) if @profile == "core"
        end
        closure = {}.compare_by_identity
        targets.each do |mod|
          raise ArgumentError, "holder is not a Module" unless Module === mod
          [mod, SINGLETON.bind_call(mod)].each do |holder|
            ANCESTORS.bind_call(holder).each { closure[_1] = true }
          end
        end
        excluded = {}.compare_by_identity
        @exclusions.each do |mod|
          raise ArgumentError, "exclusion is not a Module" unless Module === mod
          excluded[mod] = excluded[SINGLETON.bind_call(mod)] = true
        end
        @report["exclusions"] = excluded.keys.map { label(_1) }.sort
        missing = closure.keys.select { excluded.key?(_1) }
        @report["excluded_required_holders"] = missing.map { label(_1) }.sort
        @report["ancestor_closure_complete"] = missing.empty?
        missing.each { closure.delete(_1) }
        @report["holders"] = closure.keys.map { label(_1) }.sort
        # Prewarm serialization before freezing JSON's own class-level caches.
        JSON.generate(@report)
        @report["audited"] = audit
        if audit
          @trace = TracePoint.new(:raise) do |event|
            error = event.raised_exception
            next unless FrozenError === error
            receiver = begin
              error.receiver
            rescue ArgumentError # Explicit `raise FrozenError` has no receiver.
              nil
            end
            @report["errors"] << {"stage" => @stage, "target" => label(receiver),
              "pattern" => classify(error.backtrace), "backtrace" => error.backtrace}
          end
          @trace.enable
        end
        closure.each_key { FREEZE.bind_call(_1) }
        @report["enforced"] = true
        stage("workload")
        self
      end

      def stage(name)
        @stage = name
        @report["stages"] << name
      end

      def finish!
        @trace&.disable
        @report["frozen_error_count"] = @report["errors"].size
        @report["status"] = if !@report["enforced"]
          "disabled"
        elsif !@report["audited"]
          "enforced_without_observer"
        elsif @report["errors"].empty?
          @report["ancestor_closure_complete"] ? "no_violation_observed" : "no_violation_observed_with_exclusions"
        else
          "violations_observed"
        end
        @report
      end

      private

      def label(value)
        return NAME.bind_call(value) || TO_S.bind_call(value) if Module === value
        # Do not inspect arbitrary config/instance contents into an audit log.
        NAME.bind_call(CLASS.bind_call(value))
      end

      def classify(backtrace)
        text = backtrace.join("\n")
        case text
        when /define_attribute_methods|generated_attribute_methods/ then "lazy_attribute_methods"
        when /class_attribute|__class_attr_/ then "class_attribute_setter"
        when /define_method|class_eval|module_eval|alias_method|prepend|include/ then "method_or_ancestor_mutation"
        when /const_set|const_missing|zeitwerk|require/ then "lazy_constant_or_load"
        else "class_state_or_other_review_required"
        end
      end
    end
  end
end
