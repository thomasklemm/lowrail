# frozen_string_literal: true

require_relative "compilation"

module Lowrail
  # Deliver after compilation/cache deserialization, never through load_iseq.
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
        @served = {}
        return if manifest.files.empty?
        iseq_singleton.prepend(Compilation::Capture) unless iseq_singleton < Compilation::Capture
        Compilation.hook_bootsnap
        RubyVM::InstructionSequence.prepend(Evaluation) unless RubyVM::InstructionSequence < Evaluation
      end

      def installed? = !@manifest.nil?

      # Cold-delivery witness for sealed admission. Record at the successful
      # source of truth, not through a VM-wide return observer or a wrapper.
      def served?(path) = @served&.key?(path)

      def iseq_singleton = RubyVM::InstructionSequence.singleton_class

      # Called from Guard::ModuleHooks#prepend_features after any prepend.
      def prepended_to(base, _mod)
        return unless @manifest && !@manifest.files.empty? && base.equal?(iseq_singleton)
        Compilation.hook_bootsnap
      end

      # Returns a lowered ISeq for path, or nil to fall through.
      def serve(path, original: nil)
        # The eval seam must not validate our replacement as an original.
        return nil if original && @replacements&.key?(original)
        return nil if defined?(::Coverage) && ::Coverage.respond_to?(:running?) && ::Coverage.running?
        options = Compilation.options_for(original)
        bin = @manifest.iseq_for(path, original: original, compile_option: options) or return nil
        binary = File.binread(bin)
        unless Manifest.digest.hexdigest(binary) == @manifest.files.fetch(path).fetch("iseq_sha256")
          return Lowrail.refuse("lowered ISeq digest mismatch: #{path}; using original source")
        end
        iseq = RubyVM::InstructionSequence.load_from_binary(binary)
        (@replacements ||= ObjectSpace::WeakKeyMap.new)[iseq] = true
        Stats.loaded(path) if defined?(Stats)
        JitDiagnostics.record(iseq, path, @manifest.units) if defined?(JitDiagnostics)
        @served[path] = true
        iseq
      rescue StandardError => e
        Lowrail.refuse("#{path}: #{e.class}: #{e.message}; compiling original source")
        nil
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
