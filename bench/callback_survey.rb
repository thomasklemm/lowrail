# frozen_string_literal: true

require File.expand_path("config/environment", Dir.pwd) if $PROGRAM_NAME == __FILE__
require "json"

# An untimed census, not a profiler or a pass. Target the real method ISeq so
# neither callback control flow nor the application's visible stack changes.
module CallbackSurvey
  def self.start
    @calls = Hash.new(0)
    @trace = TracePoint.new(:call) do |event|
      binding = event.binding
      kind = binding.local_variable_get(:kind)
      type = binding.local_variable_get(:type)
      # Do not call an arbitrary kind object's to_sym twice. Rails owns that
      # conversion; the census can observe symbols and ordinary string keys.
      chains = event.self.__callbacks
      key = Symbol === kind ? kind : (chains.keys.find { _1.to_s == kind } if kind.instance_of?(String))
      chain = chains[key]
      callbacks = chain ? chain.select { type.nil? || _1.kind == type } : []
      conditions = callbacks.flat_map { [_1.instance_variable_get(:@if), _1.instance_variable_get(:@unless)].flatten }
      category = if !chain
        "unobserved_kind"
      elsif callbacks.empty?
        "empty"
      elsif conditions.empty?
        "condition_free"
      elsif conditions.all?(Symbol)
        "symbol_conditions"
      else
        "dynamic_conditions"
      end
      config = chain.respond_to?(:config) ? chain.config : {}
      key = { class: event.self.class.name || "<anonymous>", kind: describe(kind), type: describe(type),
        category: category, chain_empty: chain&.empty?, around: callbacks.any? { _1.kind == :around },
        callbacks: callbacks.map { |callback| { kind: callback.kind, filter: describe(callback.filter),
          if: callback.instance_variable_get(:@if).map { describe(_1) },
          unless: callback.instance_variable_get(:@unless).map { describe(_1) } } },
        terminator: describe(config[:terminator]),
        skip_after_if_terminated: config[:skip_after_callbacks_if_terminated] }
      @calls[key] += 1
    end
    @trace.enable(target: ActiveSupport::Callbacks.instance_method(:run_callbacks))
  end

  def self.describe(value)
    case value
    when String, Symbol, nil, true, false then value
    when Proc then { proc: value.source_location, arity: value.arity }
    else { object: value.class.name }
    end
  end

  def self.finish
    @trace.disable
    rows = @calls.map { |key, count| key.merge(calls: count) }
    { ruby: RUBY_DESCRIPTION, rails: Rails.version, calls: rows.sum { _1[:calls] },
      categories: rows.group_by { _1[:category] }.transform_values { _1.sum { |row| row[:calls] } },
      chains: rows.sort_by { [-_1[:calls], _1[:class], _1[:kind].to_s] } }
  end
end

if $PROGRAM_NAME == __FILE__
  require "rack/mock"
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil
  abort "survey requires Lowrail absent" if defined?(Lowrail)
  abort "survey requires YJIT" unless RubyVM::YJIT.enabled?
  headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
  session = Rack::MockRequest.new(Rails.application)
  out = ENV.fetch("CALLBACK_SURVEY_OUT")
  abort "output already exists" if File.exist?(out)
  reports = ARGV.to_h do |path|
    request = -> {
      response = session.get(path, headers)
      raise "#{path}: HTTP #{response.status}" unless response.status == 200
      response.body
    }
    400.times { request.call }
    CallbackSurvey.start
    20.times { request.call }
    [path, CallbackSurvey.finish.merge(requests: 20)]
  end
  File.write(out, JSON.pretty_generate(reports))
end
