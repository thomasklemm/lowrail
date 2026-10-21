# frozen_string_literal: true

require_relative "passes"
require_relative "paths"

module Lowrail
  # Minimal JSON reader for the manifest. Boot runs before bundler/setup when
  # Lowrail is loaded through RUBYOPT, and requiring the json default gem there
  # would activate a version that can conflict with the app's lockfile (see
  # lowrail.rb). The manifest is machine-written, so a strict tokenizer plus a
  # recursive-descent parser is enough. Raises ArgumentError on bad input.
  module MiniJSON
    # scan skips only what no alternative matches; \S makes that whitespace.
    TOKEN = /"[^"\\]*(?:\\.[^"\\]*)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null|\S/m
    ESCAPES = { '"' => '"', "\\" => "\\", "/" => "/", "b" => "\b", "f" => "\f", "n" => "\n", "r" => "\r", "t" => "\t" }.freeze
    QUOTE = '"'.ord
    MINUS = "-".ord
    DIGITS = ("0".ord.."9".ord)

    def self.parse(src)
      tokens = src.scan(TOKEN)
      pos, value = parse_value(tokens, 0)
      raise ArgumentError, "trailing data in JSON" unless pos == tokens.size
      value
    end

    def self.parse_value(t, i)
      tok = t[i] or raise ArgumentError, "unexpected end of JSON"
      c = tok.getbyte(0)
      if c == QUOTE
        raise ArgumentError, "unterminated string" if tok.size < 2
        [i + 1, string(tok)]
      elsif tok == "{"
        h = {}
        i += 1
        return [i + 1, h] if t[i] == "}"
        loop do
          key = t[i]
          raise ArgumentError, "expected string key" unless key && key.getbyte(0) == QUOTE && key.size >= 2
          raise ArgumentError, "expected ':'" unless t[i + 1] == ":"
          i, h[string(key)] = parse_value(t, i + 2)
          sep = t[i]
          if sep == "," then i += 1
          elsif sep == "}" then return [i + 1, h]
          else raise ArgumentError, "expected ',' or '}'"
          end
        end
      elsif tok == "["
        a = []
        i += 1
        return [i + 1, a] if t[i] == "]"
        loop do
          i, v = parse_value(t, i)
          a << v
          sep = t[i]
          if sep == "," then i += 1
          elsif sep == "]" then return [i + 1, a]
          else raise ArgumentError, "expected ',' or ']'"
          end
        end
      elsif c == MINUS || DIGITS.cover?(c)
        raise ArgumentError, "bad number #{tok.inspect}" if tok == "-"
        [i + 1, tok.include?(".") || tok.include?("e") || tok.include?("E") ? Float(tok) : Integer(tok, 10)]
      elsif tok == "true" then [i + 1, true]
      elsif tok == "false" then [i + 1, false]
      elsif tok == "null" then [i + 1, nil]
      else raise ArgumentError, "unexpected JSON token #{tok[0, 20].inspect}"
      end
    end

    def self.string(tok)
      s = tok[1..-2]
      s = unescape(s) if s.include?("\\")
      s.force_encoding(Encoding::UTF_8)
    end

    def self.unescape(s)
      s.gsub(/\\u(d[89ab]\h\h)\\u(d[c-f]\h\h)|\\u(\h{4})|\\(.)/i) do
        if $1 then (((($1.hex - 0xD800) << 10) | ($2.hex - 0xDC00)) + 0x10000).chr(Encoding::UTF_8)
        elsif $3 then $3.hex.chr(Encoding::UTF_8)
        else ESCAPES.fetch($4) { raise ArgumentError, "bad escape \\#{$4}" }
        end
      end
    end
  end

  # Persisted app paths are relative; consumers see resolved absolute paths.
  # Each file names its ISeq binary and the original source's SHA-256.
  # Units are the guarded specializations, each with the facts it assumes.
  class Manifest
    attr_reader :dir, :format, :ruby_description, :compile_option, :files, :templates, :rails_env, :units, :units_by_method, :refusal_reason

    QUARANTINED_PASSES = %w[view/link_to route/path].freeze

    def self.load(path, dir = File.dirname(path), root: nil)
      new(MiniJSON.parse(File.read(path, encoding: Encoding::UTF_8)), dir, root: root)
    end

    def initialize(data, dir, root: nil)
      @dir = dir
      @format = data.fetch("format")
      root ||= File.expand_path(data.fetch("app_root", ".."), dir)
      moved = data["build_root"] && root != data["build_root"]
      if @format != FORMAT
        @refusal_reason = "unsupported manifest format #{@format}; rebuild for relocatable format #{FORMAT}"
      elsif data["iseq_root"] && root != data["iseq_root"]
        @refusal_reason = "relocation unsupported: path-bound ISeqs target #{data['iseq_root']}, not #{root}; rebuild with --target-root #{root}"
      elsif moved && !data.fetch("relocation_refusals", []).empty?
        @refusal_reason = "relocation unsupported: #{data.fetch('relocation_refusals').join('; ')}; rebuild at the runtime root"
      end
      Paths.resolve!(data, root: root)
      @ruby_description = data.fetch("ruby_description")
      @compile_option = data.fetch("compile_option")
      @files = data.fetch("files")
      # Lowered template code by template identifier (see lowrail/templates.rb).
      @templates = data.fetch("templates", {})
      # Builds partially evaluate with one environment's config; another
      # environment's process must not use them (checked in Guard.validate,
      # because RAILS_ENV is often set only after setup).
      @rails_env = data["rails_env"]
      @units = data.fetch("units")
      @refusal_reason ||= data["delivery_refusal"]
      sealed_units = @units.any? { Passes.sealed_only?(_1["pass"]) || _1["pass"].to_s.start_with?("sealed/") }
      if data["tier"] == "sealed-v1"
        unless ENV["LOWRAIL_SEALED"] == "1" && ENV["RAILS_ENV"] == "production" &&
            @rails_env == "production" && @units.all? { Passes.sealed_only?(_1["pass"]) }
          @refusal_reason = "sealed artifact requires LOWRAIL_SEALED=1, production, and the separate SEAL001–009 contract; this test runs unoptimized"
        end
      elsif data["tier"] || sealed_units
        names = @units.filter_map { _1["pass"] if Passes.sealed_only?(_1["pass"]) }.uniq
        @refusal_reason = "unknown or missing sealed artifact version (sealed-only: #{names.join(', ')}); cached hooks cannot certify post-seal mutations (SEAL001); rebuild with --sealed required"
      end
      unsafe = @units.filter_map { |unit| unit["pass"] if QUARANTINED_PASSES.include?(unit["pass"]) }.uniq
      unless unsafe.empty?
        @refusal_reason = "quarantined source passes: #{unsafe.join(', ')}; receiver certificates and post-argument/conversion continuations are incomplete; rebuild required"
      end
      # Symbol keys: the method_added hooks look up every defined name, and a
      # Symbol lookup does not allocate.
      by_method = Hash.new { |h, k| h[k] = [] }
      @units.each do |unit|
        unit.fetch("facts").each { |fact| by_method[fact.fetch("method").to_sym] << unit.fetch("id") }
      end
      by_method.each_value(&:uniq!)
      @units_by_method = {}.merge!(by_method).freeze
    end

    # Cheap checks done at setup. The per-file loader fingerprint needs
    # SHA-256 and is checked lazily on the first lookup (see #iseq_for).
    def compatible?
      @refusal_reason.nil? && @format == FORMAT && Manifest.normalize(@ruby_description) == Manifest.normalize(RUBY_DESCRIPTION)
    end

    def lowered?(source_path)
      @files.key?(source_path)
    end

    # Returns the ISeq binary path when the on-disk source still matches what
    # was lowered, else nil (the caller compiles the source normally).
    def iseq_for(source_path, original: nil, compile_option: nil)
      return nil if @refusal_reason
      entry = @files[source_path] or return nil
      return Lowrail.refuse("source missing: #{source_path}") unless File.file?(source_path)
      unless Manifest.sha256_file(source_path) == entry.fetch("source_sha256")
        return Lowrail.refuse("source digest mismatch: #{source_path}; rebuild required")
      end
      # Old builds have no loader contract: rebuild rather than assume their
      # process-wide defaults describe the app's per-file compilation.
      fingerprint = entry["original_iseq_sha256"] or return Lowrail.refuse("missing original ISeq certificate: #{source_path}; rebuild required")
      unless compile_option && compile_option == entry["compile_option"]
        return Lowrail.refuse("compiler recipe mismatch or unobserved: #{source_path}; using original source")
      end
      # The recipe alone cannot detect external source transforms or hijacks.
      unless original && [fingerprint, entry["native_iseq_sha256"]].include?(Manifest.iseq_fingerprint(original, portable: entry["portable_fingerprint"]))
        return Lowrail.refuse("original ISeq mismatch: #{source_path}; loader transform or target-root recipe differs")
      end
      lowered = File.expand_path(entry.fetch("lowered"), @dir)
      unless File.file?(lowered) && Manifest.sha256_file(lowered) == entry.fetch("lowered_sha256")
        return Lowrail.refuse("lowered source digest mismatch: #{source_path}; rebuild required")
      end
      File.join(@dir, entry.fetch("iseq"))
    end

    # YJIT and the parser are runtime choices that do not change the ISeq
    # format; strip them so a build made without YJIT serves a YJIT process.
    def self.normalize(desc)
      desc.sub(/ \+YJIT( dev)?/, "").sub(/ \+ZJIT( dev)?/, "").sub(/ \+PRISM/, "").sub(/ \+MN/, "")
    end

    def self.compile_option_fingerprint(opts = RubyVM::InstructionSequence.compile_option, overrides = nil)
      sorted = opts.sort_by { |k, _| k.to_s }
      sorted = [sorted, overrides.is_a?(Hash) ? overrides.sort_by { |k, _| k.to_s } : overrides] unless overrides.nil?
      digest.hexdigest(sorted.inspect)
    end

    def self.iseq_fingerprint(iseq, portable: false)
      return digest.hexdigest(iseq.to_binary) unless portable
      portable_iseq_fingerprint(iseq.to_a)
    end

    def self.portable_iseq_fingerprint(data)
      unless data[0] == "YARVInstructionSequence/SimpleDataFormat" && data[1] == 4 &&
          ["<main>", "<compiled>", "<top (required)>"].include?(data[5])
        raise ArgumentError, "unsupported target-root ISeq serialization"
      end
      # Normalize only the known root labels of native, file and text
      # compilation. Preserve entry lines, operands, nested ISeqs and strings.
      data[5] = "<top>"
      digest.hexdigest(Marshal.dump(data))
    end

    def self.sha256_file(path)
      digest.file(path).hexdigest
    end

    def self.digest
      return ::Digest::SHA256 if defined?(::Digest::SHA256)
      # Lazy default-gem activation must not change the compiler context of
      # the app file that triggered it (Freezolite runs on nested requires).
      options = RubyVM::InstructionSequence.compile_option
      require "digest"
      ::Digest::SHA256
    ensure
      RubyVM::InstructionSequence.compile_option = options if options
    end
  end
end
