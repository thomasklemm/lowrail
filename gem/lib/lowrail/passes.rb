# frozen_string_literal: true

module Lowrail
  # Runtime installers, in the historical setup order. Source passes only
  # need delivery, except memo's per-site state. Keep the existing module
  # names as aliases: emitted code and source certificates refer to them.
  module Passes
    REGISTRY = {
      PreloadPlans: ["preload_plans", %w[active_record/preload_plans]],
      Memo: ["memo", %w[memo/uri_join memo/sha256]],
      DigestMemo: ["digest_memo", %w[digest/file_memo]],
      ARInstantiate: ["ar_instantiate", %w[active_record/instantiate]],
      ARPlans: ["ar_plans", %w[active_record/ar_plans]],
      InertiaConfig: ["inertia_config", %w[inertia/config_bind]],
      InertiaProps: ["inertia_props", %w[inertia/props]],
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
      REGISTRY.each do |name, (file, passes)|
        selected = units.select { passes.include?(_1["pass"]) }
        next if selected.empty?
        require_relative file
        runtime = const_get(name, false)
        runtime.install(selected)
        after_initialize(runtime) if runtime.respond_to?(:activate)
      end
    end

    # on_load also runs immediately when the application already initialized.
    # Under RUBYOPT neither Rails nor Active Support exists yet: one temporary
    # TracePoint waits for Rails::Application, then hands off to the same hook.
    def self.after_initialize(runtime)
      if defined?(::ActiveSupport) && ::ActiveSupport.respond_to?(:on_load)
        ::ActiveSupport.on_load(:after_initialize) { runtime.activate }
      else
        (@pending ||= []) << runtime
        return if @boot&.enabled?
        @boot = TracePoint.new(:end) do |event|
          if event.self.is_a?(Class) && event.self.name == "Rails::Application"
            @boot.disable
            pending, @pending = @pending, []
            pending.each { after_initialize(_1) }
          end
        end
        @boot.enable
      end
    end
  end
end
