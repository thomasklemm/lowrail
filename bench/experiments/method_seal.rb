# frozen_string_literal: true

# Exploration only. Not required by setup, not a production certificate.
# Unlike Module#freeze this observes method/ancestry writes, not class ivars.
require "json"

module MethodSeal
  CLASS = Kernel.instance_method(:class)
  SINGLETON = Kernel.instance_method(:singleton_class)
  ANCESTORS = Module.instance_method(:ancestors)
  NAME = Module.instance_method(:name)
  TO_S = Module.instance_method(:to_s)
  CALLBACKS = %i[method_added method_removed method_undefined singleton_method_added
    singleton_method_removed singleton_method_undefined method_missing].freeze
  OPERATIONS = %i[define_method define_singleton_method alias_method remove_method undef_method
    include prepend extend append_features prepend_features extend_object
    public private protected public_class_method private_class_method module_function].freeze

  class Session
    attr_reader :active, :report

    def initialize(holders:)
      @active = [false]
      @targets = {}.compare_by_identity
      holders.each do |holder|
        raise ArgumentError, "expected Module" unless Module === holder
        [holder, SINGLETON.bind_call(holder)].each do |side|
          ANCESTORS.bind_call(side).each { @targets[_1] = true }
        end
      end
      @report = {"mechanism" => "method_tripwire", "holders" => @targets.keys.map { NAME.bind_call(_1) }.compact.sort,
        "violations" => [], "enforced" => false,
        "limitations" => ["missing methods and no-op mutator calls conservatively deopt",
          "in-flight skipped calls need a flag check after every app callback",
          "native extensions without Ruby events are not covered",
          "refinements and mutable data/config are not method-table facts"]}
    end

    def start!
      raise "one-shot session" if @trace
      @trace = TracePoint.new(:call, :c_call, :raise) do |event|
        if event.event == :raise
          error = event.raised_exception
          next unless NoMethodError === error && CALLBACKS.include?(error.name)
          name, receiver = error.name, error.receiver
        else
          name, receiver = event.callee_id, event.self
        end
        next unless CALLBACKS.include?(name) || OPERATIONS.include?(name)
        target = if Module === receiver
          @targets.key?(receiver)
        else
          @targets.key?(CLASS.bind_call(receiver))
        end
        next unless target
        # Withdraw BEFORE warning or app callback code. No retry of work that
        # has executed already, and never rearm this process automatically.
        @active[0] = false
        @trace.disable
        @report["violations"] << {"operation" => name.to_s,
          "holder" => Module === receiver ? TO_S.bind_call(receiver) : NAME.bind_call(CLASS.bind_call(receiver)),
          "path" => event.path, "line" => event.lineno, "backtrace" => caller}
        warn "LOWRAIL METHOD SEAL VIOLATION: #{name} at #{event.path}:#{event.lineno}; stock dispatch for this process"
      end
      @active[0] = true
      @trace.enable
      self
    end

    def finish!
      @trace&.disable
      @report.merge("active" => @active[0], "status" => @report["violations"].empty? ? "no_violation_observed" : "deoptimized",
        "enforced" => false)
    end
  end
end
