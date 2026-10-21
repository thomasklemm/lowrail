# frozen_string_literal: true

# Untimed activation/coverage worker, never loaded into instruction workers.
# Also wraps the existing method micros to attest their actual JIT state.
module PassProbe
  def self.counts
    defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.unit_hits : {}
  end

  def self.sample(iterations, before)
    { iterations: iterations, unit_hits: counts.to_h { |id, n| [id, n - before.fetch(id, 0)] } }
  end

  def self.active!(ids)
    raise "build inactive: manifest declined" unless defined?(Lowrail) && Lowrail.manifest&.compatible?
    units = Lowrail.manifest.units.select { ids.include?(_1.fetch("id")) }
    raise "build inactive: selected units absent" unless units.size == ids.size
    units.each do |unit|
      active = case unit.fetch("pass")
      when "active_record/instantiate"
        model = Object.const_get(unit.fetch("ar_instantiate").fetch("model"))
        entry = model.instance_variable_get(:@_lowrail_instantiate)
        entry && entry.id == unit.fetch("id") && entry.valid?
      when "active_record/preload_plans"
        defined?(Lowrail::PreloadPlans::Hook) && ActiveRecord::Associations::Preloader < Lowrail::PreloadPlans::Hook &&
          Lowrail::PreloadPlans.guard_ok?
      when "active_record/ar_plans"
        defined?(Lowrail::ARPlans::AssociationHook) && ActiveRecord::Associations::Association < Lowrail::ARPlans::AssociationHook &&
          Lowrail::ARPlans.guard_ok? && Lowrail::ARPlans.instance_variable_get(:@plans)&.any?
      when "digest/file_memo"
        defined?(Lowrail::DigestMemo) && Lowrail::DigestMemo.instance_variable_get(:@units)&.key?(unit.fetch("id")) &&
          Lowrail::DigestMemo.valid?(unit.fetch("id"))
      when "inertia/config_bind"
        defined?(Lowrail::Passes::InertiaConfig::Variant) &&
          InertiaRails::Configuration < Lowrail::Passes::InertiaConfig::Variant && Lowrail::Guard.validate(unit.fetch("id"))
      when "inertia/props"
        defined?(Lowrail::Passes::InertiaProps) && Lowrail::Passes::InertiaProps.active?(unit.fetch("id")) &&
          Lowrail::Guard.validate(unit.fetch("id")) && Lowrail::Stats.loaded_files.include?(unit.fetch("file"))
      when "endpoint/action"
        controller = Object.const_get(unit.fetch("endpoint").fetch("controller"))
        entry = Lowrail::Endpoint.entries&.fetch([controller, unit.fetch("endpoint").fetch("action")], nil)
        entry && entry.id == unit.fetch("id")
      when "sealed/link_to"
        defined?(Lowrail::Sealed) && Lowrail::Sealed::ACTIVE[0] && Lowrail::Sealed.refusal.nil?
      when "sealed/form_scaffold"
        defined?(Lowrail::FormScaffold) && Lowrail::FormScaffold.instance_variable_get(:@active) &&
          Lowrail::FormScaffold.refusal.nil?
      else
        raise "no activation adapter for runtime pass #{unit.fetch('pass')}" if %w[runtime method model].include?(unit["kind"])
        # Source/call-site passes are delivered lazily. Zero route coverage is
        # valid (e.g. a response cache); don't confuse it with a declined build.
        defined?(Lowrail::Loader) && Lowrail::Loader.installed? &&
          (unit["kind"] != "template" || (defined?(Lowrail::Templates::CompiledSource) &&
            ActionView::Template < Lowrail::Templates::CompiledSource))
      end
      raise "build inactive: unit #{unit.fetch('id')} (#{unit.fetch('pass')})" unless active
    end
    units
  end
end

if $PROGRAM_NAME == __FILE__
  require_relative "jit_stability"
  if JitStability.mode != "yjit"
    require File.expand_path("config/application", Dir.pwd)
    Rails.application.config.yjit = false
  end
  require File.expand_path("config/environment", Dir.pwd)
  require "json" # Activate the app's locked version, never a default gem before Bundler.
  Rails.application.eager_load!
  Rails.logger.level = :error
  ActiveRecord::Base.logger = nil if defined?(ActiveRecord::Base)
  JitStability.assert_mode!
  ids = ENV.fetch("BENCH_UNITS").split(",").map { Integer(_1) }
  units = PassProbe.active!(ids) if ENV["LOWRAIL"] == "1"
  if ENV["BENCH_MICRO_SCRIPT"]
    load ENV.fetch("BENCH_MICRO_SCRIPT")
    result = { **JitStability.state, ruby: RUBY_DESCRIPTION }
  else
    require "rack/mock"
    session = Rack::MockRequest.new(Rails.application)
    verb, path = ARGV.fetch(0).split(":", 2)
    headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
    request = -> {
      response = session.request(verb, path, headers)
      raise "request failed: HTTP #{response.status}" unless (200..299).cover?(response.status)
    }
    # Route guard hits precede a live predicate/type check; count completed
    # specializations at the shared finish seam, not as successful guards.
    route_counts = Module.new do
      define_method(:finish) do |*args|
        value = super(*args)
        @bench_completions = (@bench_completions || 0) + 1
        value
      end
    end
    Lowrail::Routes.singleton_class.prepend(route_counts) if defined?(Lowrail::Routes)
    Integer(ENV.fetch("BENCH_WARMUP", "50")).times { request.call }
    Lowrail::Stats.reset_counts!
    Lowrail::Routes.instance_variable_set(:@bench_completions, 0) if defined?(Lowrail::Routes)
    n = 10
    n.times { request.call }
    PassProbe.active!(ids)
    # A loaded file whose fingerprint/loader contract declined is not active,
    # even if other units happened to deliver successfully.
    delivered = Lowrail::Stats.loaded_files
    Lowrail.manifest.files.each_key do |file|
      if $LOADED_FEATURES.include?(file) && !delivered.include?(file)
        raise "build inactive: original ISeq served for #{file}"
      end
    end
    result = { **JitStability.state, ruby: RUBY_DESCRIPTION, requests: n,
      units: units.map { |unit| { id: unit.fetch("id"), pass: unit.fetch("pass"),
        hits_per_request: Lowrail::Stats.unit_hits.fetch(unit.fetch("id").to_s, 0).fdiv(n),
        fallbacks_per_request: Lowrail::Stats.unit_fallbacks.fetch(unit.fetch("id").to_s, 0).fdiv(n) } },
      route_completions_per_request: defined?(Lowrail::Routes) ? Lowrail::Routes.instance_variable_get(:@bench_completions).fdiv(n) : 0 }
  end
  JitStability.assert_mode!
  if ENV["LOWRAIL_JIT_DIAGNOSTICS"] == "1"
    require_relative "../gem/lib/lowrail/jit_diagnostics"
    result[:jit_diagnostics] = Lowrail::JitDiagnostics.snapshot
  end
  puts "LOWRAIL_BENCH #{JSON.generate(result)}"
end
