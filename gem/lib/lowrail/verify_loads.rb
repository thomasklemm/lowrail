# frozen_string_literal: true

require_relative "load_hooks"

module Lowrail
  # Opt-in verification observer, symmetric even with LOWRAIL=0. Never
  # constantize: inspecting an autoload must not itself execute that autoload.
  module VerifyLoads
    NAME = Module.instance_method(:name)
    CONSTANTS = Module.instance_method(:constants)
    AUTOLOAD = Module.instance_method(:autoload?)
    INTERNAL = File.expand_path(__dir__) + "/"

    class << self
      def install
        @hooks, @loaders, @snapshots = {}, [], {}
        @events = []
        @pid = Process.pid
        @seconds = 0.0
        ::Lowrail::LoadHooks.active_support do
          Lowrail.loaded_constant("ActiveSupport::LazyLoadHooks").prepend(LoadHooks)
        end
        Object.singleton_class.prepend(ConstHook)
        watch_zeitwerk
      end

      def watch_zeitwerk
        zeitwerk = Lowrail.loaded_constant("Zeitwerk") or return
        zeitwerk.singleton_class.prepend(LoaderDefinition) unless zeitwerk.singleton_class < LoaderDefinition
        loader = Lowrail.loaded_constant("Zeitwerk::Loader") or return
        loader.prepend(LoaderHooks) unless loader < LoaderHooks
      end

      def watch(loader)
        return if @loaders.include?(loader)
        @loaders << loader
        loader.on_load { |name, _value, path| @events << "load\t#{name}\t#{path}" }
      end

      def hook(name, block)
        path, line = block.source_location
        return if !path || path.start_with?(INTERNAL, "lowrail:")
        entry = "#{name}\t#{path}:#{line}"
        @hooks[entry] = true
        @events << "hook\t#{entry}"
      end

      def capture(stage)
        if @pid != Process.pid
          @snapshots, @seconds, @pid = {}, 0.0, Process.pid
        end
        return if @snapshots.key?(stage)
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        constants = []
        ObjectSpace.each_object(Module) do |mod|
          name = NAME.bind_call(mod)
          next if !name || name == "Lowrail" || name.start_with?("Lowrail::")
          # Anonymous parents can give named descendants inspect-style names
          # (#<#<Class:0x...>:0x...>::Coercible). Only their address tokens
          # vary by process. Keep every constant suffix and all event order.
          name = name.gsub(/(?<=:)0x\h+(?=>)/, "0x?") if name.start_with?("#<")
          CONSTANTS.bind_call(mod, false).each do |key|
            next if AUTOLOAD.bind_call(mod, key)
            constants << (name == "Object" ? key.to_s : "#{name}::#{key}")
          end
        end
        directories = @loaders.flat_map(&:dirs).map { _1 + "/" }
        @snapshots[stage] = {
          "constants" => constants.uniq.sort,
          "zeitwerk_paths" => $LOADED_FEATURES.select { |path| directories.any? { path.start_with?(_1) } }.sort,
          "on_load_hooks" => @hooks.keys.sort,
          "load_events" => @events.each_with_index.map { |event, index| "#{index}\t#{event}" }
        }
        @seconds += Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      rescue StandardError, ScriptError => error
        @snapshots[stage] = { "errors" => ["#{error.class}: #{error.message}"] }
      end

      def snapshot
        capture("after_suite")
        { "stages" => @snapshots, "snapshot_seconds" => @seconds }
      end
    end

    module ConstHook
      private

      def const_added(name)
        super
        VerifyLoads.watch_zeitwerk if equal?(Object) && name == :Zeitwerk
      end
    end

    module LoaderDefinition
      private

      def const_added(name)
        super
        VerifyLoads.watch_zeitwerk if name == :Loader
      end
    end

    module LoaderHooks
      def setup
        Lowrail::VerifyLoads.watch(self)
        super
      end
    end

    module LoadHooks
      private

      def with_execution_control(name, block, once)
        super do
          Lowrail::VerifyLoads.hook(name, block)
          yield
        end
      end
    end
  end
end
