# frozen_string_literal: true

module Lowrail
  # Hooks RubyVM::InstructionSequence.load_iseq, the seam Bootsnap uses.
  #
  # Ordering with Bootsnap: Bootsnap's load_iseq does not call super, so
  # whichever hook is prepended last wins. Lowrail must sit in front:
  #   * Bootsnap first, Lowrail after (config/boot.rb order): plain prepend.
  #   * Lowrail first (RUBYOPT=-rlowrail/setup), Bootsnap after: our
  #     Module#prepend_features hook sees Bootsnap's prepend onto the
  #     ISeq singleton class and prepends a fresh Lowrail hook in front of it.
  # Files Lowrail does not serve fall through to the next hook (Bootsnap) and
  # then to MRI (nil = compile the source).
  #
  # While Coverage is running we serve nothing (like Bootsnap): binary ISeqs
  # carry no coverage counters, and coverage tools must see the source.
  module Loader
    class << self
      attr_reader :manifest

      def install(manifest)
        @manifest = manifest
        prepend_hook
      end

      def installed? = !@manifest.nil?

      def iseq_singleton = RubyVM::InstructionSequence.singleton_class

      # Called from Guard::ModuleHooks#prepend_features after any prepend.
      def prepended_to(base, mod)
        return unless @manifest && base.equal?(iseq_singleton)
        return if mod.equal?(@hook)
        prepend_hook
      end

      # Returns a lowered ISeq for path, or nil to fall through.
      def serve(path)
        return nil if defined?(::Coverage) && ::Coverage.respond_to?(:running?) && ::Coverage.running?
        bin = @manifest.iseq_for(path) or return nil
        iseq = RubyVM::InstructionSequence.load_from_binary(File.binread(bin))
        Stats.loaded(path) if defined?(Stats)
        iseq
      rescue StandardError => e
        Lowrail.debug("#{path}: #{e.class}: #{e.message}; compiling original source")
        nil
      end

      private

      def prepend_hook
        hook = Module.new do
          def load_iseq(path)
            ::Lowrail::Loader.serve(path) || (defined?(super) ? super : nil)
          end
        end
        @hook = hook
        iseq_singleton.prepend(hook)
      end
    end
  end
end
