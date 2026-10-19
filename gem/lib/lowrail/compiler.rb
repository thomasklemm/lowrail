# frozen_string_literal: true

require "json"
require "digest"
require "fileutils"
require_relative "../lowrail"
require_relative "manifest"

module Lowrail
  # Build step behind `gem/exe/lowrail-compile UNITS_JSON` (see
  # docs/FORMATS.md): compiles each lowered source to an ISeq binary as if it
  # were the original file, then atomically writes manifest.json.
  #
  # Equivalence: `RubyVM::InstructionSequence.compile(src, path, path, 1)`
  # with the source read as UTF-8 (what Bootsnap does) produces the same
  # instructions as `compile_file_prism(path)`, the compiler that `require`
  # and Bootsnap use on Ruby 3.4+/4.0: magic comments (frozen_string_literal,
  # encoding, shareable_constant_value) are read by the parser from the
  # source text, and compile options come from the current process, which is
  # what the manifest fingerprint records. Verified by comparing `to_a` over
  # ~430 Rails and app files (gem/test/compiler_test.rb keeps a sample). The
  # one difference: top-level frames are labelled "<compiled>" instead of
  # "<main>" (plain MRI says "<top (required)>"), which only shows in
  # backtraces through a file's top-level code.
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
        manifest = compile(JSON.parse(File.read(input)), err: err)
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
        manifest["templates"] = templates unless templates.empty?
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
        binary = RubyVM::InstructionSequence.compile(src, path, path, 1).to_binary
        name = "#{Digest::SHA256.hexdigest(binary)}.bin"
        dest = File.join(iseq_dir, name)
        unless File.exist?(dest)
          tmp = "#{dest}.tmp.#{Process.pid}"
          File.binwrite(tmp, binary)
          File.rename(tmp, dest)
        end
        { "iseq" => "iseq/#{name}", "source_sha256" => sha }
      end
    end
  end
end
