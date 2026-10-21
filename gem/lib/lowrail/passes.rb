# frozen_string_literal: true

require_relative "load_hooks"

module Lowrail
  # Runtime installers, in the historical setup order. Source passes only
  # need delivery, except memo's per-site state. Keep the existing module
  # names as aliases: emitted code and source certificates refer to them.
  module Passes
    REGISTRY = {
      PreloadPlans: {file: "preload_plans", passes: %w[active_record/preload_plans], sealed_only: true},
      Memo: {file: "memo", passes: %w[memo/uri_join memo/sha256], source: true, sealed_only: true},
      DigestMemo: {file: "digest_memo", passes: %w[digest/file_memo], source: true, sealed_only: true},
      # This installer already subscribes to each model's Zeitwerk on_load.
      ARInstantiate: {file: "ar_instantiate", passes: %w[active_record/instantiate], lazy: true, sealed_only: true},
      ARPlans: {file: "ar_plans", passes: %w[active_record/ar_plans], sealed_only: true},
      InertiaConfig: {file: "inertia_config", passes: %w[inertia/config_bind], sealed_only: true},
      InertiaProps: {file: "inertia_props", passes: %w[inertia/props], source: true},
      Endpoint: {file: "endpoint", passes: %w[endpoint/action]},
      Sealed: {file: "sealed", passes: %w[sealed/link_to], sealed_only: true},
      FormScaffold: {file: "form_scaffold", passes: %w[sealed/form_scaffold], sealed_only: true},
      TokenTag: {file: "render_units", passes: %w[sealed/token_tag], sealed_only: true},
      CollectionRender: {file: "render_units", passes: %w[sealed/collection_render], sealed_only: true}
    }.freeze

    def self.sealed_only?(pass)
      REGISTRY.values.any? { _1[:sealed_only] && _1.fetch(:passes).include?(pass) }
    end

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
      # Source-only artifacts need the same late-mode observation as runtime
      # variants. Reuse the targeted initialization boundary, never a global hook.
      after_initialize
      selected_ids = ENV["LOWRAIL_UNITS"]&.split(",")&.map { Integer(_1) }
      REGISTRY.each do |name, entry|
        selected = units.select { entry.fetch(:passes).include?(_1["pass"]) }
        next if selected.empty?
        enabled = selected_ids ? selected.select { selected_ids.include?(_1["id"]) } : selected
        # Delivered source still calls its runtime to take the original arm.
        # Only runtime-only installers can be omitted during pass isolation.
        next if enabled.empty? && !entry[:source]
        require_relative entry.fetch(:file)
        runtime = const_get(name, false)
        runtime.install(entry[:source] ? selected : enabled)
        if runtime.respond_to?(:activate) && !enabled.empty?
          receivers = entry[:lazy] ? [] : enabled.flat_map { _1.fetch("facts").map { |fact| fact.fetch("receiver") } }
          receivers = receivers.uniq.reject { _1.start_with?("@") }
          after_initialize(runtime, receivers)
        end
      end
    end

    # Native framework autoloads are not all managed by Zeitwerk. Wait for
    # successful load completion, never for a partially defined class body.
    def self.when_loaded(names, &activate)
      LoadHooks.when_loaded(names, &activate)
    end

    # on_load also runs immediately when the application already initialized.
    # A global :return TracePoint leaves trace_leave instructions VM-wide even
    # after disable. Target only initialize!: removal restores that local ISeq.
    def self.after_initialize(runtime = nil, receivers = [])
      activate = -> {
        Lowrail.initialized_jit!
        when_loaded(receivers) { runtime.activate } if runtime
      }
      LoadHooks.active_support do
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
            @activation.enable(target: app.method(:initialize!))
          end
        end
      end
    end
  end
end
