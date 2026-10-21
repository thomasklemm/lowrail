# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require "pathname"
require_relative "../lowrail"
require_relative "manifest"
require_relative "compilation"
require_relative "jit_shapes"
require_relative "build_jit"

module Lowrail
  # Build step behind `gem/exe/lowrail-compile UNITS_JSON` (see
  # docs/FORMATS.md): compiles each lowered source to an ISeq binary as if it
  # were the original file, then atomically writes manifest.json.
  #
  # Compilation observes the app's actual per-file compiler calls during a
  # boot with a disposable Bootsnap cache. It replays process defaults AND
  # explicit options on the lowered source, preserving magic comments too.
  # Text compilation preserves compile_file's instructions (compiler_test.rb),
  # except the top-level frame label: "<compiled>" instead of "<main>".
  # The manifest guards both the compile recipe and the original ISeq, so a
  # later loader policy or source transformation cannot bypass the check.
  #
  # A file that fails (missing, unreadable, syntax error, source changed since
  # lowering) is skipped with a warning and its units are dropped; this never
  # fails the build. "Source changed" compares against "source_sha256" or,
  # when the input names one, the SHA-256 of the "original" copy the lowering
  # pass read. "templates" and "rails_env" are passed through to the manifest
  # (template units need no compiled file).
  module Compiler
    class << self
      def run(argv, err: $stderr)
        input = argv.first or (err.puts("usage: lowrail-compile UNITS_JSON"); return 2)
        input = JSON.parse(File.read(input))
        input["delivery_refusal"] = Lowrail.delivery_refusal(Dir.pwd)
        if input["verification_test"]
          Compilation.boot_test(input) do
            BuildJit.check(input["certification_jit"])
            manifest = compile(input, err: err)
            err.puts "[lowrail] verification compiled #{manifest['files'].size} file(s), #{manifest['units'].size} unit(s)"
          end
          return 0
        end
        mode = nil
        if input["rails_env"] && File.file?("config/environment.rb")
          Compilation.boot(input) { mode = BuildJit.prepare(input["certification_jit"]) }
        else
          mode = BuildJit.prepare(input["certification_jit"])
        end
        BuildJit.check(mode)
        manifest = compile(input, err: err)
        err.puts "[lowrail] compiled #{manifest["files"].size} file(s), #{manifest["units"].size} unit(s)"
        0
      end

      def compile(input, err: $stderr)
        BuildJit.check(input["certification_jit"])
        out = File.expand_path(input.fetch("out"))
        root = File.expand_path(input.fetch("app_root") { File.dirname(out) })
        target_root = input["target_root"] || root
        raise ArgumentError, "target_root must be absolute" unless target_root == File.expand_path(target_root)
        iseq_dir = File.join(out, "iseq")
        FileUtils.mkdir_p(iseq_dir)

        files = {}
        relocation_errors = []
        Array(input["files"]).each do |entry|
          path = entry.fetch("path")
          target = path.start_with?(root + "/") ? File.join(target_root, path.delete_prefix(root + "/")) : path
          expected = entry["source_sha256"] || (entry["original"] && Digest::SHA256.file(entry["original"]).hexdigest)
          compiled = compile_file(path, entry.fetch("lowered"), expected, iseq_dir, target: target)
          files[path] = compiled
        rescue StandardError, ScriptError => e
          err.puts "[lowrail] skipping #{path}: #{e.class}: #{e.message.lines.first&.chomp}"
          relocation_errors << "#{path}: #{e.message.lines.first&.chomp}" if target && target != path
        end

        templates = input["templates"] || {}
        units = Array(input["units"]).select do |unit|
          if unit["pass"] == "endpoint/action"
            begin
              data = unit.fetch("endpoint")
              binary = RubyVM::InstructionSequence.compile(data.fetch("code"), "lowrail:endpoint", "lowrail:endpoint", 1).to_binary
              name = "#{Digest::SHA256.hexdigest(binary)}.bin"
              File.binwrite(File.join(iseq_dir, name), binary)
              data["iseq"] = "iseq/#{name}"
              data["iseq_sha256"] = Digest::SHA256.hexdigest(binary)
              next true
            rescue StandardError, ScriptError => e
              err.puts "[lowrail] dropping endpoint #{unit['target']}: #{e.class}: #{e.message.lines.first&.chomp}"
              next false
            end
          end
          next true if %w[runtime method].include?(unit["kind"])
          next true if files.key?(unit["file"])
          next true if unit["kind"] == "template" && templates.key?(unit["file"])
          err.puts "[lowrail] dropping unit #{unit["id"]} (#{unit["method"]}): #{unit["file"]} not compiled"
          false
        end

        manifest = {
          "format" => FORMAT,
          "ruby_description" => RUBY_DESCRIPTION,
          "certification_jit" => Lowrail.jit_mode,
          "compile_option" => Manifest.compile_option_fingerprint,
          "files" => files,
          "units" => units
        }
        manifest["rails_env"] = input["rails_env"] if input["rails_env"]
        manifest["tier"] = input["tier"] if input["tier"]
        manifest["verification_test"] = input["verification_test"] if input["verification_test"]
        manifest["selected_passes"] = input["selected_passes"] if input["selected_passes"]
        manifest["templates"] = templates unless templates.empty?
        manifest["delivery_refusal"] = input["delivery_refusal"] if input["delivery_refusal"]
        warnings = []
        artifacts = files.map { |path, entry| [path, entry.fetch("iseq")] }
        units.each do |unit|
          if unit["pass"] == "endpoint/action"
            artifacts << [unit.fetch("target"), unit.fetch("endpoint").fetch("iseq")]
          elsif %w[runtime method].include?(unit["kind"])
            warnings << JitShapes.warning(unit["target"] || unit["file"], "*", 0, "uninspected",
              "#{unit['pass']}: runtime-installed body; no emitted binary at this build boundary")
          end
        end
        templates.each_key do |path|
          warnings << JitShapes.warning(path, "*", 0, "uninspected", "template method ISeq is compiled by Action View at runtime")
        end
        artifacts.each do |target, relative|
          iseq = RubyVM::InstructionSequence.load_from_binary(File.binread(File.join(out, relative)))
          warnings.concat(JitShapes.check(iseq, target))
        rescue StandardError, ScriptError => e
          warnings << JitShapes.warning(target, "*", 0, "uninspected", "#{e.class}: #{e.message.lines.first&.chomp}")
        end
        ledger_path = File.join(out, "ledger.json")
        ledger = File.file?(ledger_path) ? JSON.parse(File.read(ledger_path)) : []
        ledger.reject! { %w[jit/shape delivery].include?(_1["pass"]) }
        if input["delivery_refusal"]
          ledger << { "pass" => "delivery", "target" => "delivery", "site" => "*", "line" => 0,
                      "outcome" => "refused", "reason" => "bundlebun_load_order",
                      "detail" => input["delivery_refusal"], "copies" => 1 }
          err.puts "[lowrail] #{input['delivery_refusal']}"
        end
        err.puts "[lowrail] #{warnings.size} JIT shape warning(s); diagnostic only (ledger.json)" unless warnings.empty?
        manifest = Paths.relative(manifest, root: root, dir: out)
        manifest["build_root"] = root # provenance/refusal only, never a lookup root
        manifest["iseq_root"] = target_root unless files.empty?
        reasons = relocation_errors
        reasons << "endpoint factories retain path-derived compiled-method certificates" if units.any? { _1["pass"] == "endpoint/action" }
        if Paths.contains_root?(manifest["units"], root) || Paths.contains_root?(manifest["templates"], root)
          reasons << "opaque code/config/reflection values retain the build root"
        end
        manifest["relocation_refusals"] = reasons
        ledger.reject! { _1["pass"] == "delivery/relocation" }
        reasons.each do |reason|
          ledger << { "pass" => "delivery/relocation", "outcome" => "warning", "reason" => "nonrelocatable",
            "detail" => reason, "copies" => 1 }
        end
        Lowrail.write_json(ledger_path, ledger + warnings)
        Lowrail.write_json(File.join(out, "manifest.json"), manifest)
        manifest
      end

      def compile_file(path, lowered, expected_sha, iseq_dir, target: path)
        raise ArgumentError, "path must be absolute" unless path == File.expand_path(path)
        sha = Digest::SHA256.file(path).hexdigest
        if expected_sha && expected_sha != sha
          raise ArgumentError, "source changed since lowering (sha256 #{sha[0, 12]} != #{expected_sha[0, 12]})"
        end
        src = File.read(lowered, encoding: Encoding::UTF_8)
        compilation = Compilation.files[path]
        if Compilation.booted? && !compilation
          raise ArgumentError, "app loader did not compile this file"
        end
        compilation ||= Compilation.original(path)
        unless compilation.fetch(:source_sha256) == sha
          raise ArgumentError, "app loader transformed the source; lower the transformed source first"
        end
        fingerprint = compilation.fetch(:iseq_sha256)
        native_fingerprint = compilation[:native_iseq_sha256]
        if target != path
          original = File.read(path, encoding: Encoding::UTF_8)
          replay = Compilation.lowered(original, path, compilation)
          native = compilation[:native_iseq]&.to_a
          if native
            native_replay = replay.to_a
            native_replay[5], native_replay[8] = native.values_at(5, 8)
          end
          native_original = fingerprint == native_fingerprint
          reproducible = if native_original
            native_replay == native
          else
            compilation[:portable_iseq_sha256] &&
              Manifest.iseq_fingerprint(replay, portable: true) == compilation[:portable_iseq_sha256]
          end
          unless reproducible
            raise ArgumentError, "target-root recipe cannot reproduce the original ISeq (including nested frame labels)"
          end
          target_original = Compilation.lowered(original, target, compilation)
          fingerprint = Manifest.iseq_fingerprint(target_original, portable: true)
          native_fingerprint = nil
          if native && native_replay == native
            # Prove the entire original before transferring its native root
            # header. Keep entry line 0; never normalize it to API line 1.
            target_native = target_original.to_a
            target_native[5], target_native[8] = native.values_at(5, 8)
            native_fingerprint = Manifest.portable_iseq_fingerprint(target_native)
            fingerprint = native_fingerprint if native_original
          end
        end
        binary = Compilation.lowered(src, target, compilation).to_binary
        name = "#{Digest::SHA256.hexdigest(binary)}.bin"
        dest = File.join(iseq_dir, name)
        unless File.exist?(dest)
          tmp = "#{dest}.tmp.#{Process.pid}"
          File.binwrite(tmp, binary)
          File.rename(tmp, dest)
        end
        entry = { "iseq" => "iseq/#{name}", "source_sha256" => sha,
          "lowered" => Pathname.new(File.expand_path(lowered)).relative_path_from(Pathname.new(File.dirname(iseq_dir))).to_s,
          "lowered_sha256" => Digest::SHA256.hexdigest(src.b), "iseq_sha256" => Digest::SHA256.hexdigest(binary),
          "original_iseq_sha256" => fingerprint, "portable_fingerprint" => target != path,
          "compile_option" => compilation.fetch(:compile_option) }
        entry["native_iseq_sha256"] = native_fingerprint if native_fingerprint
        entry
      end
    end
  end
end
