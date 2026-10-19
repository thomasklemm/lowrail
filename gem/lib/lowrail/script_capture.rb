# frozen_string_literal: true

module Lowrail
  # Captures generated code: every string compiled by eval, class_eval,
  # module_eval, instance_eval or Binding#eval, through
  # TracePoint(:script_compiled). Files (require/load) are not recorded:
  # their source is on disk. Bootsnap only caches file ISeqs, so it does not
  # hide evals and the order of installation relative to it does not matter;
  # what matters is installing before the code that evals runs.
  #
  # Each distinct compilation site is one script: (source digest, eval
  # path, eval line, defining module, caller). The top-level ISeq of every
  # compilation is retained so that, at dump time, a method's ISeq can be
  # mapped back to the script that defined it by identity
  # (RubyVM::InstructionSequence#each_child). Wrapper objects are cached by
  # the VM, so identity holds.
  #
  # Loaded from RUBYOPT by lowrail/observe: requires no default gems at load
  # (digest is required at dump time).
  module ScriptCapture
    Script = Struct.new(:source, :path, :lineno, :mod, :kind, :caller, :caller_label, :phase, :count, :iseqs)

    MOD_NAME = Module.instance_method(:name)
    KERNEL_IS_A = Kernel.instance_method(:is_a?)
    KERNEL_CLASS = Kernel.instance_method(:class)

    class << self
      attr_reader :scripts, :compiled_bytes
      attr_accessor :phase

      # keep_iseqs: retain ISeqs for method linking (boot facts). The
      # observed run keeps them too, but only for the first compilation of
      # each script.
      def start(phase: "boot", keep_iseqs: true)
        return self if @tp
        @scripts = {}
        @order = []
        @phase = phase
        @keep_iseqs = keep_iseqs
        @compiled_bytes = 0
        @compilations = 0
        @seconds = 0.0
        @tp = TracePoint.new(:script_compiled) { |tp| on_compiled(tp) }
        @tp.enable
        self
      end

      def stop
        @tp&.disable
      end

      def started? = !@tp.nil?

      def compilations = @compilations || 0

      # Seconds spent inside the hook itself (not counting the VM's cost of
      # firing it, which is measured from the outside).
      def hook_seconds = @seconds || 0.0

      def on_compiled(tp)
        src = tp.eval_script
        return unless src
        t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        iseq = tp.instruction_sequence
        receiver = tp.self
        # [0] is the eval method itself (its label names the kind), [1] the
        # code that called it.
        locs = caller_locations(2, 2) || []
        kind = locs[0]&.base_label.to_s
        site = locs[1]
        mod = KERNEL_IS_A.bind_call(receiver, Module) ? receiver : KERNEL_CLASS.bind_call(receiver)
        caller_s = site ? "#{site.path}:#{site.lineno}" : nil
        key = [src, iseq.path, iseq.first_lineno, mod.__id__, caller_s]
        script = @scripts[key]
        if script
          script.count += 1
          script.iseqs << iseq if @keep_iseqs
        else
          src = src.frozen? ? src : src.dup.freeze
          script = Script.new(src, iseq.path, iseq.first_lineno, mod, kind, caller_s,
                              site&.label, @phase, 1, [iseq])
          @scripts[key] = script
          @order << script
        end
        @compiled_bytes += src.bytesize
        @compilations += 1
      ensure
        @seconds += Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0 if t0
      end

      def list = @order || []

      def count = list.size

      # Identity map from every ISeq compiled inside a script (methods,
      # blocks, class bodies) to the script.
      def iseq_index
        index = {}.compare_by_identity
        list.each do |s|
          s.iseqs.each { |iseq| walk(iseq, s, index) }
        end
        index
      end

      def walk(iseq, script, index)
        iseq.each_child do |child|
          next if index.key?(child)
          index[child] = script
          walk(child, script, index)
        end
      end

      def digest(script)
        require "digest"
        @digests ||= {}.compare_by_identity
        @digests[script] ||= Digest::SHA256.hexdigest(script.source)
      end

      # Writes every script source to dir/<sha256>.rb (once) and returns the
      # index entries (docs/FORMATS.md, generated_scripts). +label+ turns a
      # module into its fact label.
      def write(dir, label:, scripts: list)
        require "fileutils"
        FileUtils.mkdir_p(dir)
        scripts.map do |s|
          sha = digest(s)
          file = File.join(dir, "#{sha}.rb")
          File.binwrite(file, s.source) unless File.exist?(file)
          entry(s, sha, label)
        end
      end

      def entry(s, sha, label)
        e = {
          "sha256" => sha,
          "bytes" => s.source.bytesize,
          "lines" => s.source.count("\n") + (s.source.end_with?("\n") || s.source.empty? ? 0 : 1),
          "path" => s.path.to_s,
          "lineno" => s.lineno,
          "kind" => s.kind,
          "module" => label.call(s.mod),
          "caller" => s.caller,
          "caller_label" => s.caller_label,
          "phase" => s.phase,
          "count" => s.count,
        }
        name = MOD_NAME.bind_call(s.mod)
        e["module_anonymous"] = true unless name.is_a?(String)
        e
      end
    end
  end
end
