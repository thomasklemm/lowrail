# frozen_string_literal: true

require_relative "../lowrail"

module Lowrail
  # Readiness, not loading. Global TracePoints permanently patch VM bytecodes,
  # even after disable. Observe AS's own initialization and successful native
  # autoload/require completion instead; never resolve an autoload to check it.
  module LoadHooks
    class << self
      def active_support(&block)
        support = Lowrail.loaded_constant("ActiveSupport")
        return block.call if support&.respond_to?(:on_load)
        (@support_waiters ||= []) << block
        Object.singleton_class.prepend(WatchSupport) unless Object.singleton_class < WatchSupport
        watch_support if support
      end

      def watch_support
        support = Lowrail.loaded_constant("ActiveSupport") or return
        support.singleton_class.prepend(WatchLazyHooks) unless support.singleton_class < WatchLazyHooks
        hooks = Lowrail.loaded_constant("ActiveSupport::LazyLoadHooks") or return
        hooks.singleton_class.prepend(AfterExtension) unless hooks.singleton_class < AfterExtension
      end

      def support_ready
        support = Lowrail.loaded_constant("ActiveSupport")
        return unless support&.respond_to?(:on_load)
        pending, @support_waiters = @support_waiters || [], []
        pending.each(&:call)
      end

      # nil means no identifiable completion boundary, not permission to load.
      def dependency(name)
        owner = Object
        name.delete_prefix("::").split("::").each do |part|
          return unless Module === owner
          return owner.autoload?(part, false) if owner.autoload?(part, false)
          return unless owner.const_defined?(part, false)
          owner = owner.const_get(part, false)
        end
        :loaded
      end

      def when_loaded(names, &activate)
        dependencies = names.to_h { [_1, dependency(_1)] }.reject { |_, feature| feature == :loaded }
        return activate.call if dependencies.empty?
        (@waiters ||= []) << [dependencies, activate]
        # Installed only after initialized boot: Zeitwerk must first finish
        # aliasing Kernel#require. Native MRI autoload dispatches through it.
        Kernel.prepend(RequireCompletion) unless Kernel < RequireCompletion
        return if @zeitwerk_hooked
        rails = Lowrail.loaded_constant("Rails")
        return unless rails&.respond_to?(:autoloaders)
        @zeitwerk_hooked = true
        rails.autoloaders.each { |loader| loader.on_load { |name, _| completed(name: name) } }
      end

      def waiting? = @waiters && !@waiters.empty?

      def completed(feature: nil, name: nil)
        return unless waiting?
        ready = []
        @waiters.delete_if do |dependencies, activate|
          dependencies.keys.each do |constant|
            next unless (feature && dependencies[constant] == feature) || name == constant
            state = dependency(constant)
            state == :loaded ? dependencies.delete(constant) : dependencies[constant] = state
          end
          ready << activate if dependencies.empty?
          dependencies.empty?
        end
        ready.each(&:call)
      rescue StandardError, ScriptError => error
        Lowrail.debug("load activation declined: #{error.class}: #{error.message}")
      end
    end

    module WatchSupport
      private

      def const_added(name)
        super
        LoadHooks.watch_support if equal?(Object) && name == :ActiveSupport
      end
    end

    module WatchLazyHooks
      private

      def const_added(name)
        super
        LoadHooks.watch_support if name == :LazyLoadHooks
      end
    end

    module AfterExtension
      def extended(base)
        super
        LoadHooks.support_ready if base.equal?(Lowrail.loaded_constant("ActiveSupport"))
      end
    end

    module RequireCompletion
      private

      def require(path)
        return super unless LoadHooks.waiting?
        # Do not activate halfway through an enclosing require, nor after an
        # exception that left partially defined constants. Never intercept
        # require_relative: a Ruby wrapper changes its lexical base directory.
        stack = (Thread.current[:__lowrail_requires] ||= [])
        stack << []
        success = false
        result = super
        stack.last << path if String === path
        success = true
        result
      ensure
        if stack
          features = stack.pop
          if success
            if stack.empty?
              features.each { |feature| LoadHooks.completed(feature: feature) }
            else
              stack.last.concat(features)
            end
          end
        end
      end
    end
  end
end
