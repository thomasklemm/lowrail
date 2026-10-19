# frozen_string_literal: true

require "digest"

module Lowrail
  # The build output. Files are keyed by absolute source path; each entry
  # names its ISeq binary and the SHA-256 of the source it was lowered from.
  # Units are the guarded specializations, each with the facts it assumes.
  class Manifest
    attr_reader :dir, :ruby_description, :compile_option, :files, :units, :units_by_method

    def self.load(path, dir)
      new(JSON.parse(File.read(path)), dir)
    end

    def initialize(data, dir)
      @dir = dir
      @format = data.fetch("format")
      @ruby_description = data.fetch("ruby_description")
      @compile_option = data.fetch("compile_option")
      @files = data.fetch("files")
      @units = data.fetch("units")
      @units_by_method = Hash.new { |h, k| h[k] = [] }
      @units.each do |unit|
        unit.fetch("facts").each { |fact| @units_by_method[fact.fetch("method")] << unit.fetch("id") }
      end
      @units_by_method.each_value(&:uniq!)
    end

    def compatible?
      @format == FORMAT &&
        Manifest.normalize(@ruby_description) == Manifest.normalize(RUBY_DESCRIPTION) &&
        @compile_option == Manifest.compile_option_fingerprint
    end

    # Returns the ISeq binary path when the on-disk source still matches what
    # was lowered, else nil (the caller compiles the source normally).
    def iseq_for(source_path)
      entry = @files[source_path] or return nil
      return nil unless File.exist?(source_path)
      return nil unless Digest::SHA256.file(source_path).hexdigest == entry.fetch("source_sha256")
      File.join(@dir, entry.fetch("iseq"))
    end

    def self.normalize(desc)
      desc.sub(/ \+YJIT( dev)?/, "").sub(/ \+PRISM/, "")
    end

    def self.compile_option_fingerprint
      opts = RubyVM::InstructionSequence.compile_option
      Digest::SHA256.hexdigest(opts.sort_by { |k, _| k.to_s }.inspect)
    end
  end
end
