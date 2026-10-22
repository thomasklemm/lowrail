# frozen_string_literal: true

# Bench-only sealed prototype, NOT a runtime installer/admission certificate.
# Same serialized bytes, fresh mutable graph, original AR marshal_load calls.
require "objspace"
require_relative "lobsters_sealed_screen"

module LowrailCachePlan
  class Refusal < StandardError; end
  class << self
    attr_accessor :enabled, :capturing, :events, :plans, :counters

    def eligible_model?(klass)
      klass < ActiveRecord::Base && klass._find_callbacks.empty? && klass._initialize_callbacks.empty? &&
        klass.method(:allocate).owner == Class && klass.instance_method(:marshal_load).super_method&.owner == ActiveRecord::Marshalling::Methods
    end

    def count(name)
      counters[name] += 1 if counters
    end
  end

  class Plan
    def initialize(result, events, allocated)
      @models = events.map { _1.first.class }.uniq
      raise Refusal, "model callbacks/allocator/marshal_load" unless @models.all? { LowrailCachePlan.eligible_model?(_1) }
      raise Refusal, "timezone hooks" if Time.respond_to?(:find_timezone, true) || "UTC".respond_to?(:utc_to_local, true)
      raise Refusal, "foreign native hooks" unless Time.method(:_load).source_location.nil? &&
        BigDecimal.method(:_load).source_location.nil? &&
        [String, Time].all? { |klass| %i[dup initialize_dup initialize_copy].all? { klass.instance_method(_1).source_location.nil? } }
      @time_load = Time.method(:_load)
      @refs = {}.compare_by_identity
      @objects = []
      @constants = []
      visit = lambda do |object|
        return unless allocated.key?(object) && !@refs.key?(object)
        @refs[object] = @objects.size
        @objects << object
        case object
        when Array
          raise Refusal, "Array subclass/ivars" unless object.instance_of?(Array) && object.instance_variables.empty?
          object.each { visit.call(_1) }
        when Hash
          raise Refusal, "Hash policy" unless object.instance_of?(Hash) && object.instance_variables.empty? &&
            object.default.nil? && !object.default_proc && !object.compare_by_identity?
          object.each { |key, value| visit.call(key); visit.call(value) }
        when String
          raise Refusal, "String subclass/ivars" unless object.instance_of?(String) && object.instance_variables.empty?
        when Time
          raise Refusal, "Time shape" unless object.instance_of?(Time) && object.instance_variables.empty? && object.utc?
        when BigDecimal
          raise Refusal, "BigDecimal shape" unless object.instance_of?(BigDecimal) && object.instance_variables.empty?
        when ActiveRecord::Base
          raise Refusal, "unrecorded model" unless events.any? { _1.first.equal?(object) }
        else
          raise Refusal, "unsupported #{object.class}"
        end
      end
      visit.call(result)
      events.each { |record, state| visit.call(record); visit.call(state) }
      lines = ["->(c) do", "v = []"]
      @objects.each_with_index do |object, index|
        constructor = case object
        when Array then "[]"
        when Hash then "{}"
        when String then "c[#{constant(object.dup.freeze)}].dup"
        when Time then "c[#{constant(object.dup.freeze)}].dup"
        when BigDecimal then "BigDecimal._load(c[#{constant(object._dump)}].dup)"
        when ActiveRecord::Base then "c[#{constant(object.class)}].allocate"
        end
        lines << "v[#{index}] = #{constructor}"
        # A frozen String key must be frozen before Hash insertion; otherwise
        # Hash makes a different key object and breaks aliases in the payload.
        lines << "v[#{index}].freeze" if object.frozen? && !object.is_a?(Array) && !object.is_a?(Hash)
      end
      @objects.each_with_index do |object, index|
        case object
        when Array
          object.each { lines << "v[#{index}] << #{reference(_1)}" }
        when Hash
          object.each { |key, value| lines << "v[#{index}][#{reference(key)}] = #{reference(value)}" }
        end
        lines << "v[#{index}].freeze" if object.frozen? && (object.is_a?(Array) || object.is_a?(Hash))
      end
      events.each { |record, state| lines << "#{reference(record)}.marshal_load(#{reference(state)})" }
      lines << reference(result) << "end"
      @copy = RubyVM::InstructionSequence.compile(lines.join("\n"), __FILE__, __FILE__, 1).eval
      @objects = @refs = nil
    end

    def call
      raise Refusal, "model changed" unless @models.all? { LowrailCachePlan.eligible_model?(_1) }
      raise Refusal, "timezone changed" unless Time.method(:_load) == @time_load &&
        !Time.respond_to?(:find_timezone, true) && !"UTC".respond_to?(:utc_to_local, true)
      @copy.call(@constants)
    end

    private
      def constant(value)
        @constants << value
        @constants.size - 1
      end

      def reference(object)
        if @refs.key?(object)
          "v[#{@refs.fetch(object)}]"
        else
          # Marshal's frozen keys/symbols and immediate scalar values only.
          raise Refusal, "external mutable value" unless object.nil? || object == true || object == false ||
            object.is_a?(Numeric) || object.is_a?(Symbol) || (object.instance_of?(String) && object.frozen?)
          "c[#{constant(object)}]"
        end
      end
  end

  module Record
    def marshal_load(state)
      LowrailCachePlan.events << [self, state] if LowrailCachePlan.capturing
      super
    end
  end

  module Load
    private

    def marshal_load(source)
      return super unless LowrailCachePlan.enabled && source.instance_of?(String)
      if plan = LowrailCachePlan.plans[source]
        begin
          result = plan.call
        rescue Refusal
          LowrailCachePlan.count("refused")
          return super
        end
        LowrailCachePlan.count("hits")
        return result
      end
      # Finite capture, at most the two observed payloads; all later unknown
      # payloads run stock. Never key by the cache name alone.
      return super if LowrailCachePlan.plans.size >= 2
      LowrailCachePlan.events = []
      LowrailCachePlan.capturing = true
      disabled = GC.disable
      ObjectSpace.trace_object_allocations_start
      result = super
      ObjectSpace.trace_object_allocations_stop
      LowrailCachePlan.capturing = false
      allocated = {}.compare_by_identity
      ObjectSpace.each_object do |object|
        allocated[object] = true if ObjectSpace.allocation_sourcefile(object) == "<internal:marshal>"
      end
      begin
        plan = Plan.new(result, LowrailCachePlan.events, allocated)
        LowrailCachePlan.plans[source.dup.freeze] = plan
        LowrailCachePlan.count("compiled")
      rescue Refusal => error
        LowrailCachePlan.count("capture_refused")
        warn "cache copy plan refused: #{error.message}"
      end
      result
    ensure
      if disabled != nil
        LowrailCachePlan.capturing = false
        LowrailCachePlan.events = nil
        ObjectSpace.trace_object_allocations_stop
        ObjectSpace.trace_object_allocations_clear
        GC.enable unless disabled
      end
    end
  end
end

module Exploration
  class << self
    alias_method :install_fixture, :install

    def install(config:, state:, arm:)
      install_fixture(config: config, state: state, arm: arm)
      raise "explicit sealed exploration required" unless config.fetch("exploration_only") && ENV["LOWRAIL_SEALED"] == "1"
      raise "pinned Ruby/Rails required" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4"
      LowrailCachePlan.plans = {}
      LowrailCachePlan.counters = Hash.new(0) if ENV.key?("LOWRAIL_STATS")
      LowrailCachePlan.enabled = arm == "on"
      ActiveRecord::Base.prepend(LowrailCachePlan::Record)
      ActiveSupport::Cache::SerializerWithFallback.prepend(LowrailCachePlan::Load)
    end

    def counts = LowrailCachePlan.counters
  end
end
