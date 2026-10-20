# frozen_string_literal: true

require_relative "compilation"

module Lowrail
  # Hooks RubyVM::InstructionSequence.load_iseq, the seam Bootsnap uses.
  #
  # Let the app's loader produce the original ISeq first. Only an exact
  # fingerprint match permits substitution; this includes per-file compiler
  # options, source transforms, and warm Bootsnap caches. require-hooks evals
  # inside load_iseq (returning an empty ISeq), so substitute at #eval too.
  # Never substitute before serialization: Bootsnap must cache originals,
  # including when the next process disables Lowrail or uses a newer build.
  #
  # While Coverage is running we serve nothing (like Bootsnap): binary ISeqs
  # carry no coverage counters, and coverage tools must see the source.
  module Loader
    class << self
      attr_reader :manifest

      def install(manifest)
        @manifest = manifest
        iseq_singleton.prepend(Compilation::Capture) unless iseq_singleton < Compilation::Capture
        Compilation.hook_bootsnap
        RubyVM::InstructionSequence.prepend(Evaluation) unless RubyVM::InstructionSequence < Evaluation
        prepend_hook
      end

      def installed? = !@manifest.nil?

      def iseq_singleton = RubyVM::InstructionSequence.singleton_class

      # Called from Guard::ModuleHooks#prepend_features after any prepend.
      def prepended_to(base, mod)
        return unless @manifest && base.equal?(iseq_singleton)
        return if mod.equal?(@hook)
        Compilation.hook_bootsnap
        prepend_hook
      end

      # Returns a lowered ISeq for path, or nil to fall through.
      def serve(path, original: nil)
        return nil if defined?(::Coverage) && ::Coverage.respond_to?(:running?) && ::Coverage.running?
        options = Compilation.options_for(original)
        bin = @manifest.iseq_for(path, original: original, compile_option: options) or return nil
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
            original = defined?(super) ? super : nil
            return original unless ::Lowrail::Loader.manifest.lowered?(path)
            return original if defined?(::Coverage) && ::Coverage.running?
            original ||= RubyVM::InstructionSequence.compile_file(path)
            ::Lowrail::Loader.serve(path, original: original) || original
          end
        end
        @hook = hook
        iseq_singleton.prepend(hook)
      end
    end

    module Evaluation
      def eval
        loader = ::Lowrail::Loader
        if loader.manifest.lowered?(absolute_path)
          lowered = loader.serve(absolute_path, original: self)
          return lowered.eval if lowered
        end
        super
      end
    end
  end
end
