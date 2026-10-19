# frozen_string_literal: true

module Lowrail
  # Hooks RubyVM::InstructionSequence.load_iseq, the same seam Bootsnap uses.
  # Prepended after Bootsnap, so files Lowrail did not lower (or whose source
  # changed since the build) fall through to Bootsnap and then to MRI.
  module Loader
    module Hook
      def load_iseq(path)
        if (bin = Lowrail::Loader.manifest.iseq_for(path))
          begin
            iseq = RubyVM::InstructionSequence.load_from_binary(File.binread(bin))
            Lowrail::Stats.loaded(path) if defined?(Lowrail::Stats)
            return iseq
          rescue RuntimeError, TypeError, ArgumentError => e
            warn "[lowrail] #{path}: #{e.message}; compiling original source" if ENV["LOWRAIL_DEBUG"]
          end
        end
        defined?(super) ? super : nil
      end
    end

    class << self
      attr_reader :manifest

      def install(manifest)
        @manifest = manifest
        RubyVM::InstructionSequence.singleton_class.prepend(Hook) unless RubyVM::InstructionSequence.singleton_class < Hook
      end
    end
  end
end
