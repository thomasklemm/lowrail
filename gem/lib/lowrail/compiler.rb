# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require_relative "../lowrail"
require_relative "manifest"
require_relative "compilation"
require_relative "jit_shapes"

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
        Compilation.boot(input) if input["rails_env"] && File.file?("config/environment.rb")
        manifest = compile(input, err: err)
        err.puts "[lowrail] compiled #{manifest["files"].size} file(s), #{manifest["units"].size} unit(s)"
        0
      end

      def compile(input, err: $stderr)
        out = File.expand_path(input.fetch("out"))
        iseq_dir = File.join(out, "iseq")
        FileUtils.mkdir_p(iseq_dir)

        files = {}
        Array(input["files"]).each do |entry|
          path = entry.fetch("path")
          expected = entry["source_sha256"] || (entry["original"] && Digest::SHA256.file(entry["original"]).hexdigest)
          compiled = compile_file(path, entry.fetch("lowered"), expected, iseq_dir)
          files[path] = compiled
        rescue StandardError, ScriptError => e
          err.puts "[lowrail] skipping #{path}: #{e.class}: #{e.message.lines.first&.chomp}"
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
          "compile_option" => Manifest.compile_option_fingerprint,
          "files" => files,
          "units" => units
        }
        manifest["rails_env"] = input["rails_env"] if input["rails_env"]
        manifest["tier"] = input["tier"] if input["tier"]
        manifest["templates"] = templates unless templates.empty?
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
        ledger.reject! { _1["pass"] == "jit/shape" }
        Lowrail.write_json(ledger_path, ledger + warnings)
        err.puts "[lowrail] #{warnings.size} JIT shape warning(s); diagnostic only (ledger.json)" unless warnings.empty?
        Lowrail.write_json(File.join(out, "manifest.json"), manifest)
        manifest
      end

      def compile_file(path, lowered, expected_sha, iseq_dir)
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
        binary = Compilation.lowered(src, path, compilation).to_binary
        name = "#{Digest::SHA256.hexdigest(binary)}.bin"
        dest = File.join(iseq_dir, name)
        unless File.exist?(dest)
          tmp = "#{dest}.tmp.#{Process.pid}"
          File.binwrite(tmp, binary)
          File.rename(tmp, dest)
        end
        { "iseq" => "iseq/#{name}", "source_sha256" => sha,
          "original_iseq_sha256" => compilation.fetch(:iseq_sha256),
          "compile_option" => compilation.fetch(:compile_option) }
      end
    end
  end
end
