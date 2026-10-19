# frozen_string_literal: true

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

  # The build output. Files are keyed by absolute source path; each entry
  # names its ISeq binary and the SHA-256 of the source it was lowered from.
  # Units are the guarded specializations, each with the facts it assumes.
  class Manifest
    attr_reader :dir, :format, :ruby_description, :compile_option, :files, :units, :units_by_method

    def self.load(path, dir = File.dirname(path))
      new(MiniJSON.parse(File.read(path, encoding: Encoding::UTF_8)), dir)
    end

    def initialize(data, dir)
      @dir = dir
      @format = data.fetch("format")
      @ruby_description = data.fetch("ruby_description")
      @compile_option = data.fetch("compile_option")
      @files = data.fetch("files")
      @units = data.fetch("units")
      # Symbol keys: the method_added hooks look up every defined name, and a
      # Symbol lookup does not allocate.
      by_method = Hash.new { |h, k| h[k] = [] }
      @units.each do |unit|
        unit.fetch("facts").each { |fact| by_method[fact.fetch("method").to_sym] << unit.fetch("id") }
      end
      by_method.each_value(&:uniq!)
      @units_by_method = {}.merge!(by_method).freeze
      @compile_option_ok = nil
    end

    # Cheap checks done at setup. The compile-option fingerprint needs
    # SHA-256 and is checked lazily on the first lookup (see #iseq_for).
    def compatible?
      @format == FORMAT && Manifest.normalize(@ruby_description) == Manifest.normalize(RUBY_DESCRIPTION)
    end

    def lowered?(source_path)
      @files.key?(source_path)
    end

    # Returns the ISeq binary path when the on-disk source still matches what
    # was lowered, else nil (the caller compiles the source normally).
    def iseq_for(source_path)
      entry = @files[source_path] or return nil
      return nil unless compile_option_ok?
      return nil unless File.file?(source_path)
      return nil unless Manifest.sha256_file(source_path) == entry.fetch("source_sha256")
      File.join(@dir, entry.fetch("iseq"))
    end

    def compile_option_ok?
      return @compile_option_ok unless @compile_option_ok.nil?
      @compile_option_ok = (@compile_option == Manifest.compile_option_fingerprint).tap do |ok|
        Lowrail.debug("compile options differ from the build; not serving lowered files") unless ok
      end
    end

    # YJIT and the parser are runtime choices that do not change the ISeq
    # format; strip them so a build made without YJIT serves a YJIT process.
    def self.normalize(desc)
      desc.sub(/ \+YJIT( dev)?/, "").sub(/ \+ZJIT( dev)?/, "").sub(/ \+PRISM/, "").sub(/ \+MN/, "")
    end

    def self.compile_option_fingerprint
      require "digest"
      opts = RubyVM::InstructionSequence.compile_option
      Digest::SHA256.hexdigest(opts.sort_by { |k, _| k.to_s }.inspect)
    end

    def self.sha256_file(path)
      require "digest"
      Digest::SHA256.file(path).hexdigest
    end
  end
end
