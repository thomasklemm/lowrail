# frozen_string_literal: true

# Observed run (docs/PLAN.md 9.4, docs/FORMATS.md observed.json): records
# what a test run builds after boot and samples the classes that flow
# through app methods. Loaded without touching the app:
#
#   LOWRAIL_OBSERVE=APP/.lowrail/observe RUBYOPT="-I<gem>/lib -rlowrail/observe" bin/rails test
#
# Independent of the Lowrail runtime (works with LOWRAIL=0). Every process
# that loaded it writes LOWRAIL_OBSERVE/observed-<pid>.json at exit;
# `lowrail observe` merges them into APP/.lowrail/observed.json.
#
# Environment:
#   LOWRAIL_OBSERVE          output directory (required, else this is a no-op)
#   LOWRAIL_OBSERVE_ROOT     app root (default: Dir.pwd)
#   LOWRAIL_OBSERVE_TYPES    0 = no type sampling (definitions and scripts only)
#   LOWRAIL_OBSERVE_SAMPLES  calls sampled per method before its hook is
#                            disabled (default 16)
#   LOWRAIL_OBSERVE_METHODS  extra methods to sample, "Mod#meth,Mod.meth"
#
# Boot is the after_initialize load hook (config/environment loaded). A
# snapshot of every method there is the baseline for "defined after boot".
#
# Type sampling uses one TracePoint(:call, :return) per method, enabled with
# `target:` so only that method's ISeq is instrumented. Calls are capped;
# hooks retire when in-flight calls drain. A global :raise hook taints active
# sampled frames in that fiber: tainted nil return/ivar samples are omitted,
# even if rescued, rather than mistaking an unwind for nil. Non-nil returns
# cannot be exception-unwind events and remain usable.
# App methods are hooked at boot and as Zeitwerk loads constants (on_load).
#
# Like lowrail/setup this file must not load default gems at require time
# (json is required at exit).
require_relative "script_capture"

module Lowrail
  module Observe
    MOD_NAME = Module.instance_method(:name)
    MOD_SINGLETON_P = Module.instance_method(:singleton_class?)
    MOD_PUBLIC_IMS = Module.instance_method(:public_instance_methods)
    MOD_PROTECTED_IMS = Module.instance_method(:protected_instance_methods)
    MOD_PRIVATE_IMS = Module.instance_method(:private_instance_methods)
    MOD_INSTANCE_METHOD = Module.instance_method(:instance_method)
    MOD_ANCESTORS = Module.instance_method(:ancestors)
    CLASS_SUPERCLASS = Class.instance_method(:superclass)
    KERNEL_CLASS = Kernel.instance_method(:class)
    KERNEL_IS_A = Kernel.instance_method(:is_a?)
    KERNEL_SINGLETON_CLASS = Kernel.instance_method(:singleton_class)
    KERNEL_IVARS = Kernel.instance_method(:instance_variables)
    KERNEL_IVAR_GET = Kernel.instance_method(:instance_variable_get)
    # Not app code for type sampling: vendored, generated and test code.
    SKIP_DIRS = %w[vendor node_modules tmp .lowrail test spec].freeze
    RETURN_SAMPLING = "exception_tainted_nil_omitted_v1"
    Frame = Struct.new(:record, :sampled, :tainted)

    class << self
      attr_reader :dir, :root, :samples

      def install(dir:, root: Dir.pwd, types: true, samples: 16, methods: [], types_only: false)
        return if @installed
        @installed = true
        @dir = dir
        @root = File.join(File.expand_path(root), "")
        @types = types
        @types_only = types_only
        @samples = [samples, 1].max
        @extra = methods
        @hooked = {} # UnboundMethod equality survives fresh ISeq wrappers.
        @records = []
        @active_frames = {}.compare_by_identity
        @t0 = clock
        @timings = {}
        ScriptCapture.start(phase: "boot") unless @types_only
        Object.singleton_class.prepend(ConstHook)
        at_exit { write }
      end

      # -- boot ---------------------------------------------------------------

      def const_added(_name)
        return if @load_hook || !defined?(::ActiveSupport.on_load)
        @load_hook = true
        ::ActiveSupport.on_load(:after_initialize) { Lowrail::Observe.booted }
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      # Baseline snapshot, then hooks on app methods.
      def booted
        return if @baseline
        t = clock
        @timings["boot_seconds"] = (t - @t0).round(3)
        @baseline = @types_only ? {} : snapshot
        @baseline_modules = @baseline.size
        ScriptCapture.phase = "test" unless @types_only
        @timings["snapshot_seconds"] = (clock - t).round(3)
        return unless @types
        t = clock
        # A targeted TracePoint cannot see raises in untraced callees (and
        # Ruby may clear $! before an unwinding :return). Those VM events
        # carry nil, indistinguishable from some rescued normal returns.
        @raise_trace = TracePoint.new(:raise) do
          @active_frames[Fiber.current]&.each { |frame| frame.tainted = true }
        end
        @raise_trace.enable
        each_module { |mod| hook_module(mod) }
        @extra.each { |spec| hook_spec(spec) }
        if defined?(::Rails.autoloaders)
          ::Rails.autoloaders.each do |loader|
            loader.on_load { |_cpath, value, _abspath| hook_module(value) if KERNEL_IS_A.bind_call(value, Module) }
          end
        end
        @timings["hook_install_seconds"] = (clock - t).round(3)
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "[lowrail observe] boot hook failed: #{e.class}: #{e.message}"
      end

      # {module => {"name#" or "name." => true}} for every module.
      def snapshot
        snap = {}.compare_by_identity
        each_module(all: true) do |mod|
          names = {}
          own_names(mod).each { |n| names[n] = true }
          snap[mod] = names
        end
        snap
      end

      def each_module(all: false)
        ObjectSpace.each_object(Module).to_a.each do |mod|
          next if !all && MOD_SINGLETON_P.bind_call(mod)
          yield mod
        rescue Exception # rubocop:disable Lint/RescueException
          next
        end
      end

      def own_names(mod)
        MOD_PUBLIC_IMS.bind_call(mod, false) + MOD_PROTECTED_IMS.bind_call(mod, false) + MOD_PRIVATE_IMS.bind_call(mod, false)
      end

      # -- type sampling -----------------------------------------------------

      def app_path?(path)
        path.start_with?(@root) && SKIP_DIRS.none? { |d| path.start_with?("#{@root}#{d}/") }
      end

      # Hooks every app-defined method of +mod+ and of its singleton class.
      def hook_module(mod)
        [mod, KERNEL_SINGLETON_CLASS.bind_call(mod)].each do |m|
          own_names(m).each do |name|
            um = MOD_INSTANCE_METHOD.bind_call(m, name)
            loc = um.source_location
            next unless loc && app_path?(loc[0])
            hook(um, m)
          end
        end
      rescue Exception # rubocop:disable Lint/RescueException
        nil
      end

      def hook_spec(spec)
        sep = spec.rindex(/[#.]/) or return
        mod = Object.const_get(spec[0...sep])
        mod = KERNEL_SINGLETON_CLASS.bind_call(mod) if spec[sep] == "."
        hook(MOD_INSTANCE_METHOD.bind_call(mod, spec[sep + 1..].to_sym), mod)
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "[lowrail observe] cannot hook #{spec}: #{e.class}: #{e.message}"
      end

      def hook(um, mod)
        iseq = RubyVM::InstructionSequence.of(um)
        return unless iseq
        return if @hooked.key?(um)
        rec = {"module" => label(mod), "name" => um.name.to_s, "singleton" => MOD_SINGLETON_P.bind_call(mod),
               "source_location" => (loc = um.source_location) && "#{loc[0]}:#{loc[1]}",
               "calls" => 0, "self" => Hash.new(0), "args" => {}, "ivars" => {}, "returns" => Hash.new(0),
               "exception_tainted_returns" => 0, "saturated" => false}
        @hooked[um] = rec
        cap = @samples
        pending = 0
        tp = TracePoint.new(:call, :return) do |t|
          fiber = Fiber.current
          if t.event == :call
            sampled = rec["calls"] < cap
            (@active_frames[fiber] ||= []) << Frame.new(rec, sampled, false)
            pending += 1
            next unless sampled
            rec["calls"] += 1
            rec["saturated"] = rec["calls"] >= cap
            rec["self"][class_label(t.self)] += 1
            sample_args(t, rec)
          else
            frames = @active_frames[fiber]
            index = frames&.rindex { |frame| frame.record.equal?(rec) }
            next unless index # no entry witness for an already-running frame
            frame = frames.delete_at(index)
            @active_frames.delete(fiber) if frames.empty?
            pending -= 1
            t.disable if rec["saturated"] && pending.zero?
            if frame.sampled
              if frame.tainted && KERNEL_IS_A.bind_call(t.return_value, NilClass)
                rec["exception_tainted_returns"] += 1
              else
                rec["returns"][class_label(t.return_value)] += 1
                KERNEL_IVARS.bind_call(t.self).each do |name|
                  value = KERNEL_IVAR_GET.bind_call(t.self, name)
                  (rec["ivars"][name.to_s] ||= Hash.new(0))[class_label(value)] += 1
                end
              end
            end
          end
        rescue Exception # rubocop:disable Lint/RescueException
          nil
        end
        tp.enable(target: um)
        @records << rec
      rescue Exception # rubocop:disable Lint/RescueException
        nil # cfunc, attr_*, or a method the VM cannot target
      end

      def sample_args(t, rec)
        params = t.parameters
        return if params.empty?
        b = t.binding
        params.each do |kind, name|
          next unless name && kind != :block
          v = b.local_variable_get(name)
          (rec["args"][name.to_s] ||= Hash.new(0))[class_label(v)] += 1
        end
      end

      # -- labels -------------------------------------------------------------

      def class_label(obj)
        label(KERNEL_CLASS.bind_call(obj))
      end

      def label(mod)
        name = MOD_NAME.bind_call(mod)
        return name if name.is_a?(String)
        if @synthetic && (syn = @synthetic[mod])
          return syn
        end
        if MOD_SINGLETON_P.bind_call(mod)
          attached = mod.attached_object
          return "#<Class:#{KERNEL_IS_A.bind_call(attached, Module) ? label(attached) : "#<#{class_label(attached)}>"}>"
        end
        if KERNEL_IS_A.bind_call(mod, Class)
          sup = CLASS_SUPERCLASS.bind_call(mod)
          return "#<Class < #{sup ? label(sup) : "?"}>"
        end
        "#<Module>"
      end

      # -- exit ---------------------------------------------------------------

      def write
        return unless @baseline
        return write_types if @types_only
        require "json"
        require_relative "facts"
        require_relative "materialize"
        t = clock
        # Anonymous modules get the facts' synthetic names (template
        # container, route helper modules, enum/store holders, ...), so
        # observed definitions compare with facts.json by name.
        named = []
        each_module do |mod|
          n = MOD_NAME.bind_call(mod)
          named << [n, mod] if n.is_a?(String) && !n.include?("#<")
        end
        @synthetic = {}.compare_by_identity
        Facts.synthetic_names(named).each { |n, mod| @synthetic[mod] ||= n }
        out = {"format" => 1, "pid" => Process.pid, "ppid" => Process.ppid, "app_root" => @root.chomp("/"),
               "ruby_description" => RUBY_DESCRIPTION}
        ScriptCapture.stop
        index = ScriptCapture.iseq_index
        Facts.script_index = index
        defined = []
        new_modules = 0
        each_module(all: true) do |mod|
          before = @baseline[mod]
          new_modules += 1 unless before
          names = own_names(mod)
          names.reject! { |n| before.key?(n) } if before
          next if names.empty?
          singleton = MOD_SINGLETON_P.bind_call(mod)
          owner = singleton ? mod.attached_object : mod
          mlabel = KERNEL_IS_A.bind_call(owner, Module) ? label(owner) : "#<#{class_label(owner)}>"
          vis = visibility_map(mod)
          names.each do |n|
            e = Facts.method_entry(mod, n, vis[n] || "public", singleton)
            e["module"] = mlabel
            e["module_new"] = true unless before
            defined << e
          rescue Exception # rubocop:disable Lint/RescueException
            next
          end
        end
        Facts.script_index = nil
        defined.sort_by! { |e| [e["module"], e["singleton"] ? 1 : 0, e["name"]] }
        out["modules_at_boot"] = @baseline_modules
        out["modules_after_boot"] = new_modules
        out["defined_after_boot"] = defined
        label_fn = ->(m) { label(m) }
        out["generated_scripts"] = ScriptCapture.write(File.join(File.dirname(@dir), "generated"), label: label_fn)
          .sort_by { |e| [e["path"], e["lineno"], e["sha256"]] }
        out["generated_stats"] = {"scripts" => ScriptCapture.count, "compilations" => ScriptCapture.compilations,
                                  "bytes" => ScriptCapture.compiled_bytes, "hook_seconds" => ScriptCapture.hook_seconds.round(3)}
        if (reason = ScriptCapture.linking_decline)
          out["generated_stats"]["linking_decline"] = reason
        end
        out["samples_per_method"] = @samples
        out["return_sampling"] = RETURN_SAMPLING
        out["types"] = (@records || []).select { |r| r["calls"] > 0 }.map { |r| finish(r) }
          .sort_by { |r| [r["module"], r["singleton"] ? 1 : 0, r["name"]] }
        out["hooked_methods"] = @records&.size || 0
        @timings["exit_seconds"] = (clock - t).round(3)
        @timings["process_seconds"] = (clock - @t0).round(3)
        out["timings"] = @timings
        require "fileutils"
        FileUtils.mkdir_p(@dir)
        path = File.join(@dir, "observed-#{Process.pid}.json")
        File.write("#{path}.tmp", JSON.generate(out))
        File.rename("#{path}.tmp", path)
      rescue Exception => e # rubocop:disable Lint/RescueException
        warn "[lowrail observe] could not write: #{e.class}: #{e.message}"
      end

      def finish(rec)
        rec.merge("self" => rec["self"].to_h, "returns" => rec["returns"].to_h,
                  "args" => rec["args"].transform_values(&:to_h),
                  "ivars" => rec["ivars"].transform_values(&:to_h))
      end

      # Verify needs only bounded type samples, not the definition census or
      # script capture. Do not load/materialize Rails methods at process exit.
      def write_types
        require "json"
        require "fileutils"
        FileUtils.mkdir_p(@dir)
        out = {"format" => 1, "pid" => Process.pid, "app_root" => @root.chomp("/"),
               "ruby_description" => RUBY_DESCRIPTION, "samples_per_method" => @samples,
               "hooked_methods" => @records.size, "return_sampling" => RETURN_SAMPLING,
               "types" => @records.select { |r| r["calls"] > 0 }.map { |r| finish(r) },
               "timings" => @timings.merge("process_seconds" => clock - @t0)}
        path = File.join(@dir, "observed-#{Process.pid}.json")
        File.write("#{path}.tmp", JSON.generate(out))
        File.rename("#{path}.tmp", path)
      end

      def visibility_map(mod)
        map = {}
        MOD_PRIVATE_IMS.bind_call(mod, false).each { |n| map[n] = "private" }
        MOD_PROTECTED_IMS.bind_call(mod, false).each { |n| map[n] = "protected" }
        map
      end

      def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    module ConstHook
      private

      def const_added(name)
        super
        Lowrail::Observe.const_added(name) if equal?(Object)
      end
    end
  end
end

if (dir = ENV["LOWRAIL_OBSERVE"]) && !dir.empty?
  Lowrail::Observe.install(
    dir: File.expand_path(dir),
    root: ENV.fetch("LOWRAIL_OBSERVE_ROOT") { Dir.pwd },
    types: ENV["LOWRAIL_OBSERVE_TYPES"] != "0",
    samples: Integer(ENV.fetch("LOWRAIL_OBSERVE_SAMPLES", "16"), exception: false) || 16,
    methods: ENV.fetch("LOWRAIL_OBSERVE_METHODS", "").split(",").map(&:strip).reject(&:empty?),
    types_only: ENV["LOWRAIL_OBSERVE_TYPES_ONLY"] == "1",
  )
end
