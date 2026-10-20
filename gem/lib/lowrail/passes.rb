# frozen_string_literal: true

module Lowrail
  # Runtime installers, in the historical setup order. Source passes only
  # need delivery, except memo's per-site state. Keep the existing module
  # names as aliases: emitted code and source certificates refer to them.
  module Passes
    REGISTRY = {
      PreloadPlans: ["preload_plans", %w[active_record/preload_plans]],
      Memo: ["memo", %w[memo/uri_join memo/sha256], :source],
      DigestMemo: ["digest_memo", %w[digest/file_memo], :source],
      # This installer already subscribes to each model's Zeitwerk on_load.
      ARInstantiate: ["ar_instantiate", %w[active_record/instantiate], :lazy],
      ARPlans: ["ar_plans", %w[active_record/ar_plans]],
      InertiaConfig: ["inertia_config", %w[inertia/config_bind]],
      InertiaProps: ["inertia_props", %w[inertia/props], :source],
      Endpoint: ["endpoint", %w[endpoint/action]]
    }.freeze

    def self.install(manifest)
      return if manifest.refusal_reason
      # Source delivery cannot wait for after_initialize: initializers may
      # already require lowered files or compile templates. These seams keep
      # their existing APIs and are shared by all source passes.
      require_relative "routes"
      unless manifest.templates.empty?
        require_relative "templates"
        Templates.install(manifest.templates)
      end
      units = manifest.units
      selected_ids = ENV["LOWRAIL_UNITS"]&.split(",")&.map { Integer(_1) }
      REGISTRY.each do |name, (file, passes, loading)|
        selected = units.select { passes.include?(_1["pass"]) }
        next if selected.empty?
        enabled = selected_ids ? selected.select { selected_ids.include?(_1["id"]) } : selected
        # Delivered source still calls its runtime to take the original arm.
        # Only runtime-only installers can be omitted during pass isolation.
        next if enabled.empty? && loading != :source
        require_relative file
        runtime = const_get(name, false)
        runtime.install(loading == :source ? selected : enabled)
        if runtime.respond_to?(:activate) && !enabled.empty?
          receivers = loading == :lazy ? [] : enabled.flat_map { _1.fetch("facts").map { |fact| fact.fetch("receiver") } }
          receivers = receivers.uniq.reject { _1.start_with?("@") }
          after_initialize(runtime, receivers)
        end
      end
    end

    # Active Support/Zeitwerk do not manage every framework autoload (the
    # preloader, for example). Wait for natural class/module loading without
    # resolving a single constant ourselves. The hook disables when ready.
    def self.when_loaded(names, &activate)
      ready = -> { names.all? { Lowrail.loaded_constant(_1) } }
      return activate.call if ready.call
      trace = TracePoint.new(:end) do
        next unless ready.call
        trace.disable
        activate.call
      end
      trace.enable
    end

    # on_load also runs immediately when the application already initialized.
    # Under RUBYOPT neither Rails nor Active Support exists yet: one temporary
    # TracePoint waits for Rails::Application, then hands off to the same hook.
    def self.after_initialize(runtime, receivers = [])
      activate = -> { when_loaded(receivers) { runtime.activate } }
      if defined?(::ActiveSupport) && ::ActiveSupport.respond_to?(:on_load)
        ::ActiveSupport.on_load(:after_initialize, yield: true) do |app|
          if !app.respond_to?(:initialized?) || app.initialized?
            activate.call
          else
            # Our hook can precede Rails' own after_initialize callbacks,
            # including I18n initialization. Activating model/controller plans
            # here would autoload app code against unfinished framework config.
            (@activations ||= []) << activate
            next if @activation&.enabled?
            @activation = TracePoint.new(:return) do |event|
              next unless event.method_id == :initialize! && event.self.equal?(app) && app.initialized?
              @activation.disable
              pending, @activations = @activations, []
              pending.each(&:call)
            end
            @activation.enable
          end
        end
      else
        (@pending ||= []) << [runtime, receivers]
        return if @boot&.enabled?
        @boot = TracePoint.new(:end) do |event|
          if event.self.is_a?(Class) && event.self.name == "Rails::Application"
            @boot.disable
            pending, @pending = @pending, []
            pending.each { |entry| after_initialize(*entry) }
          end
        end
        @boot.enable
      end
    end
  end
end
