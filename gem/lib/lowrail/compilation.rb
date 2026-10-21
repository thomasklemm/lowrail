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
        api = RubyVM::InstructionSequence
        unless [api.singleton_class, Capture].include?(api.method(:compile_file).owner) && native_compiler?(:compile_file)
          raise ArgumentError, "cannot certify an unobserved compiler override"
        end
        defaults = RubyVM::InstructionSequence.compile_option
        native = capture_native(path)
        record(path, File.read(path, encoding: Encoding::UTF_8), defaults, nil, :compile, 1,
               api.compile_file(path))
        compilation = files.fetch(path)
        if native
          compilation[:native_iseq] = native
          compilation[:native_iseq_sha256] = Digest::SHA256.hexdigest(native.to_binary)
        end
        compilation
      end

      def native_compiler?(name)
        api = RubyVM::InstructionSequence
        compiler = api.singleton_class < Capture ? Capture.instance_method(name).bind(api).super_method : api.method(name)
        compiler && compiler.owner.equal?(api.singleton_class) && compiler.source_location.nil?
      end

      def native_warnings?
        warning = Warning.method(:warn)
        warning.owner.equal?(Warning) && warning.source_location.nil?
      end

      def native_translation?
        api = RubyVM::InstructionSequence
        return true unless api.respond_to?(:translate, true)
        translator = api.method(:translate)
        translator.owner.equal?(Capture) && !translator.super_method
      end

      # Standalone builds have no app boot to observe. Obtain the native root
      # ISeq by aborting MRI's load at translate, before evaluation or the
      # script_compiled event. Never attempt this through an app's loader,
      # translator, warning callback, or active TracePoint.
      def capture_native(path)
        api = RubyVM::InstructionSequence
        return if api.respond_to?(:load_iseq, true) || !Kernel.method(:load).source_location.nil? || !native_warnings?
        return if ObjectSpace.each_object(TracePoint).any?(&:enabled?)
        api.singleton_class.prepend(Capture) unless api.singleton_class < Capture
        return unless native_translation?
        previous = Thread.current[:lowrail_native_compilation]
        capture = [[path, File.realpath(path)], Object.new]
        begin
          Thread.current[:lowrail_native_compilation] = capture
          catch(capture[1]) { Kernel.load(path) }
        ensure
          Thread.current[:lowrail_native_compilation] = previous
        end
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
      # MRI calls translate after native compilation, including plain require.
      # Do not deliver from explicit compiler APIs: a caller such as Bootsnap
      # may serialize their result. Only native top-level files come here;
      # method/block ISeqs must retain their lexical environment. An existing
      # translator owns this boundary, so delegate without substituting.
      def translate(iseq)
        return super if defined?(super)
        path = iseq.absolute_path
        capture = Thread.current[:lowrail_native_compilation]
        throw(capture[1], iseq) if capture && capture[0].include?(path) && iseq.to_a[9] == :top
        return iseq if Thread.current[:lowrail_compilation] || !Compilation.tracked?(path)
        return iseq unless iseq.to_a[9] == :top
        return iseq unless RubyVM::InstructionSequence.method(:translate).owner.equal?(Capture)
        return iseq if defined?(::Coverage) && ::Coverage.respond_to?(:running?) && ::Coverage.running?
        # A warning callback can change compiler options during parsing. Its
        # final defaults do not certify the options of this native compilation.
        return iseq unless Compilation.native_warnings?
        begin
          defaults = RubyVM::InstructionSequence.compile_option
          if Compilation.booted?
            Compilation.record(path, File.read(path, encoding: Encoding::UTF_8), defaults, nil, :compile, 1, iseq)
            compilation = Compilation.files.fetch(path)
            compilation[:native_iseq] = iseq
            compilation[:native_iseq_sha256] = compilation.fetch(:iseq_sha256)
            iseq
          else
            Compilation.record_options(iseq, defaults, nil)
            ::Lowrail::Loader.serve(path, original: iseq) || iseq
          end
        rescue StandardError, ScriptError => e
          Lowrail.debug("#{path}: cannot certify native compilation: #{e.class}: #{e.message}")
          iseq
        end
      end

      %i[compile compile_prism compile_parsey].each do |compiler|
        next unless RubyVM::InstructionSequence.respond_to?(compiler)
        define_method(compiler) do |source, *args|
          path = args[1] || args[0]
          tracked = Compilation.tracked?(path)
          defaults = RubyVM::InstructionSequence.compile_option if tracked
          previous = Thread.current[:lowrail_compilation]
          begin
            Thread.current[:lowrail_compilation] = true
            iseq = super(source, *args)
          ensure
            Thread.current[:lowrail_compilation] = previous
          end
          return iseq unless tracked && Compilation.native_compiler?(compiler)
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
          tracked = Compilation.tracked?(path)
          defaults = RubyVM::InstructionSequence.compile_option if tracked
          previous = Thread.current[:lowrail_compilation]
          begin
            Thread.current[:lowrail_compilation] = true
            iseq = super(path, *args)
          ensure
            Thread.current[:lowrail_compilation] = previous
          end
          return iseq unless tracked && Compilation.native_compiler?(compiler)
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
        ::Lowrail::Loader.serve(iseq.absolute_path, original: iseq) || iseq
      end
    end
  end
end
