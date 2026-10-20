# frozen_string_literal: true

module Lowrail
  # Observe the app's real compiler calls, not a reconstruction of its loader
  # policy. A fresh Bootsnap cache makes even warm app files visit the compiler.
  # Nothing is evaluated twice, and no lowered code enters Bootsnap's cache.
  module Compilation
    class << self
      def files = (@files ||= {})
      def booted? = !!@booted

      def boot(input)
        @paths = Array(input["files"]).to_h { [_1.fetch("path"), true] }
        return if @paths.empty?
        require "tmpdir"
        @booted = true
        ENV["RAILS_ENV"] = input.fetch("rails_env")
        ENV["LOWRAIL"] = "0"
        RubyVM::InstructionSequence.singleton_class.prepend(Capture)
        previous = ENV["BOOTSNAP_CACHE_DIR"]
        Dir.mktmpdir("lowrail-compile") do |cache|
          ENV["BOOTSNAP_CACHE_DIR"] = cache
          require File.expand_path("config/environment")
          Rails.application.eager_load! if defined?(Rails)
        end
      ensure
        ENV["BOOTSNAP_CACHE_DIR"] = previous if @booted
        @paths = nil
      end

      def tracked?(path)
        @paths ? @paths.key?(path) : (defined?(Loader) && Loader.manifest&.lowered?(path))
      end

      def record_options(iseq, defaults, options)
        return iseq unless iseq && tracked?(iseq.absolute_path)
        (@options ||= ObjectSpace::WeakKeyMap.new)[iseq] = Manifest.compile_option_fingerprint(defaults, options)
        iseq
      rescue StandardError => e
        Lowrail.debug("cannot record compiler options: #{e.class}: #{e.message}")
        iseq
      end

      def options_for(iseq) = @options && @options[iseq]

      # Native cache hits never call Ruby's compiler. Record the recipe at
      # Bootsnap's deserialization boundary instead; do not change its cache.
      def hook_bootsnap
        return unless defined?(::Bootsnap::CompileCache::ISeq::InstructionSequenceMixin)
        cache = ::Bootsnap::CompileCache::ISeq
        target = defined?(::Bootsnap::CompileCache::ISeq::Compiler) ? cache::Compiler : cache.singleton_class
        target.prepend(CachedOptions) unless target < CachedOptions
      end

      def record(path, source, defaults, options, compiler, line, iseq)
        portable = begin
          Manifest.iseq_fingerprint(iseq, portable: true)
        rescue ArgumentError, TypeError
          nil # Only target-root builds need this additional representation.
        end
        files[path] = {
          source_sha256: Digest::SHA256.hexdigest(source.b),
          iseq_sha256: Digest::SHA256.hexdigest(iseq.to_binary),
          portable_iseq_sha256: portable,
          compile_option: Manifest.compile_option_fingerprint(defaults, options),
          defaults: defaults, options: options.is_a?(Hash) ? options.dup : options, compiler: compiler, line: line
        }
        record_options(iseq, defaults, options)
      rescue StandardError => e
        Lowrail.debug("#{path}: cannot record compiler call: #{e.class}: #{e.message}")
        iseq
      end

      def original(path)
        defaults = RubyVM::InstructionSequence.compile_option
        record(path, File.read(path, encoding: Encoding::UTF_8), defaults, nil, :compile, 1,
               RubyVM::InstructionSequence.compile_file(path))
        files.fetch(path)
      end

      def lowered(source, path, compilation)
        previous = RubyVM::InstructionSequence.compile_option
        # Prism's frozen-literal parsing also consults process defaults, even
        # with an explicit options hash. Replay both parts of the real call.
        RubyVM::InstructionSequence.compile_option = compilation.fetch(:defaults)
        RubyVM::InstructionSequence.public_send(compilation.fetch(:compiler), source, path, path,
                                               compilation.fetch(:line), compilation.fetch(:options))
      ensure
        RubyVM::InstructionSequence.compile_option = previous
      end
    end

    module Capture
      # MRI's default compiler is internal; route only tracked files through
      # the observable compile_file API when no gem loader handled them.
      def load_iseq(path)
        iseq = defined?(super) ? super : nil
        iseq || (Compilation.booted? && Compilation.tracked?(path) ? compile_file(path) : nil)
      end

      %i[compile compile_prism compile_parsey].each do |compiler|
        next unless RubyVM::InstructionSequence.respond_to?(compiler)
        define_method(compiler) do |source, *args|
          path = args[0]
          return super(source, *args) unless Compilation.tracked?(path)
          defaults = RubyVM::InstructionSequence.compile_option
          iseq = super(source, *args)
          if Compilation.booted?
            Compilation.record(path, source, defaults, args[3], compiler, args[2] || 1, iseq)
          else
            Compilation.record_options(iseq, defaults, args[3])
          end
        end
      end

      %i[compile_file compile_file_prism compile_file_parsey].each do |compiler|
        next unless RubyVM::InstructionSequence.respond_to?(compiler)
        define_method(compiler) do |path, *args|
          return super(path, *args) unless Compilation.tracked?(path)
          defaults = RubyVM::InstructionSequence.compile_option
          iseq = super(path, *args)
          text_compiler = compiler.to_s.sub("_file", "").to_sym
          if Compilation.booted?
            Compilation.record(path, File.read(path, encoding: Encoding::UTF_8), defaults, args[0], text_compiler, 1, iseq)
          else
            Compilation.record_options(iseq, defaults, args[0])
          end
        end
      end
    end

    module CachedOptions
      def storage_to_output(...)
        defaults = RubyVM::InstructionSequence.compile_option
        iseq = super
        return iseq unless iseq && Compilation.tracked?(iseq.absolute_path)
        # A require-hooks hijack can compile with a different recipe from
        # Bootsnap's selected compiler. Warm caches do not reveal that call;
        # the binary alone cannot prove options unused by the original code.
        if defined?(::RequireHooks::Bootsnap) && ::RequireHooks.context_for(iseq.absolute_path).hijack?
          return iseq
        end
        # Unknown custom compilers must provide their real compiler call;
        # inherited cache code does not prove how they compiled the source.
        cache = ::Bootsnap::CompileCache::ISeq
        if equal?(cache) || (defined?(cache::Compiler) && instance_of?(cache::Compiler))
          Compilation.record_options(iseq, defaults, instance_variable_get(:@compile_options))
        end
        iseq
      end
    end
  end
end
