# frozen_string_literal: true

# UNSAFE measurement-only boot-fact bypass. Not part of the runtime gem.
# LOWRAIL_SPECULATE=unguarded lowrail bench|verify ...
# Data-dependent branches (STI, argument shape, scopes, etc.) are NOT facts
# and remain live. This is not permission to cache request inputs.
require_relative "experiments/speculation_context"

module Lowrail
  module Speculation
    MODE = ENV.fetch("LOWRAIL_SPECULATE")
    abort "[lowrail] unknown speculation mode #{MODE.inspect}" unless MODE == "unguarded"

    CONTEXT = SpeculationContext.context
    abort "[lowrail] REFUSING UNSAFE speculation: only lowrail bench/verify or script/rails-suite may enable it (never a production server)" unless CONTEXT
    abort "[lowrail] REFUSING UNSAFE speculation in production verification" if
      CONTEXT != "bench" && [ENV["RAILS_ENV"], ENV["RACK_ENV"]].include?("production")
    warn "[lowrail] *** UNSAFE UNGUARDED MEASUREMENT: BOOT FACTS ARE NOT CHECKED. NEVER DEPLOY. context=#{CONTEXT} ***"

    # Branch-elided snapshots are deliberately incompatible with the ordinary
    # runtime. Only this ancestry-checked experiment accepts their marker;
    # their format, exact Ruby version and loader contracts still must match.
    module UnsafeManifest
      def compatible?
        super || (@ruby_description.start_with?("[LOWRAIL UNSAFE] ") && @format == Lowrail::FORMAT &&
          Lowrail::Manifest.normalize(@ruby_description.delete_prefix("[LOWRAIL UNSAFE] ")) == Lowrail::Manifest.normalize(RUBY_DESCRIPTION))
      end
    end

    module GuardBypass
      def install(manifest, state = Lowrail::G)
        super
        selected = ENV["LOWRAIL_UNITS"]&.split(",")&.map { Integer(_1) }
        Speculation.instance_variable_set(:@ids, manifest.units.filter_map do |unit|
          id = unit.fetch("id")
          # L2's deliberately impossible facts are delivery probes, not
          # eligible specializations. Keep their negative control meaningful.
          id unless unit.fetch("pass", "").start_with?("rails_suite/") || (selected && !selected.include?(id))
        end)
        # DigestMemo.valid? also initializes algorithm bindings on its first
        # call. Bypass its facts through validate, not that initialization.
        Speculation.instance_variable_set(:@states, Speculation.ids - manifest.units.filter_map do |unit|
          unit.fetch("id") if unit["pass"] == "digest/file_memo"
        end)
        Speculation.states.each { |id| state[id] = true }
        unless defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
          Speculation.states.each { |id| Lowrail::G[id] = true }
        end
        # An unconditional method return retains dispatch overhead, but pays
        # no cache/fact check. Partial selection still honors verify bisection.
        if selected.nil? || selected.sort == manifest.units.map { _1.fetch("id") }.sort
          ReceiverBypass.module_eval do
            def ok?(id, klass) = true
            alias view_ok? ok?
          end
          if ENV["LOWRAIL_SPECULATE_KEEP"] != "ar_epoch"
            InstantiateBypass.module_eval do
              def valid? = true
              def current? = true
            end
          end
        end
      end

      def validate(id, klass: nil)
        Speculation.ids.include?(id) || super
      end

      def reset_method(name)
        # Preserve synthetic L2 false probes, but never revalidate eligible
        # specialization facts after a definition changes in this experiment.
        return unless @names.key?(name)
        super
        Speculation.states.each { |id| state[id] = true }
      end
    end

    def self.ids = @ids || []
    def self.states = @states || []

    module ReceiverBypass
      def ok?(id, klass)
        Speculation.ids.include?(id)
      end
      alias view_ok? ok?
    end

    module InstantiateBypass
      # Attribution control: keep just the existing AR schema/type epoch,
      # while still bypassing method facts. No new runtime policy is implied.
      if ENV["LOWRAIL_SPECULATE_KEEP"] == "ar_epoch"
        def valid? = Speculation.ids.include?(@id) ? (!@epoch || Lowrail::AR.epoch(@klass) == @epoch) : super
        alias current? valid?
      else
        def valid? = Speculation.ids.include?(@id) || super
        def current? = Speculation.ids.include?(@id) || super
      end
    end

    module SetupBypass
      def setup(...)
        result = super
        if defined?(Lowrail::ARInstantiate::Entry)
          Lowrail::ARInstantiate::Entry.prepend(InstantiateBypass) unless Lowrail::ARInstantiate::Entry < InstantiateBypass
        end
        result
      end
    end
  end
end

require_relative "../gem/lib/lowrail/manifest"
Lowrail::Manifest.prepend(Lowrail::Speculation::UnsafeManifest)
require_relative "../gem/lib/lowrail/guard"
Lowrail::Guard.singleton_class.prepend(Lowrail::Speculation::GuardBypass)
Lowrail.singleton_class.prepend(Lowrail::Speculation::ReceiverBypass)
Lowrail.singleton_class.prepend(Lowrail::Speculation::SetupBypass)
