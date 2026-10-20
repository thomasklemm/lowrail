# frozen_string_literal: true

require "uri"
require "digest"

module Lowrail
  # Audited intrinsic certificates. A build cannot certify an arbitrary method
  # merely by recording its current owner/source. Unknown implementations decline.
  module MemoFacts
    SOURCES = {
      "common.rb" => %w[34d54db928f8bbe0f809054fe14227754f8fed0a6e8571dc76cfc63bfbe9c2db cbd572dad20a8146bda78001cc94b3ecf5f3f10786401579429f35c52b0d3026],
      "generic.rb" => %w[29153bbd5f742b5666fd99b00abd9dc81619cdda2647efcf9e1177660cf4965b 92977ce363df1b55dd2b8215d8854504ba125045ff7cb04e817189f8482c2568],
      "http.rb" => %w[41506c2a655ae190cd8a7f30ab578e4127d2b54dda455f5f6a3fae559bda17fa],
      "https.rb" => %w[f0ccad29b07fb7dab6a8e6a343fb1b123b5849ac122e9b83d8b57ab6831684ab],
      "rfc3986_parser.rb" => %w[cedc7db16a939169305abd08b9558b7b835081fdad31c4372aeb74fbdd92f34a]
    }.freeze
    # Static closure of native dispatch in the certified HTTP(S) join path.
    # The oracle probes exercise branches too, but probes alone are not purity proof.
    NATIVE = {
      String => %i[to_str ascii_only? upcase tr downcase empty? to_i dup initialize_dup initialize_copy encode! delete! force_encoding gsub! split == freeze << index [] []= length bytesize match? start_with? hash eql? % ord is_a? kind_of? equal? nil?],
      Array => %i[[] []= last first each << push delete empty? pop shift size join index slice! clear unshift include? inject hash eql?],
      Hash => %i[[] empty? default default_proc], MatchData => %i[[]], Regexp => %i[match],
      Integer => %i[> < + - ==], Encoding => %i[hash eql?],
      Kernel => %i[is_a? kind_of? class dup initialize_dup initialize_copy freeze nil?],
      BasicObject => %i[== ! equal? __send__], NilClass => %i[nil?],
      Module => %i[const_defined? const_get], Class => %i[new allocate]
    }.freeze
    module_function

    def method_fact(mod, name, singleton: false)
      holder = singleton ? mod.singleton_class : mod
      m = holder.instance_method(name)
      { "receiver" => mod.name, "method" => name.to_s, "singleton" => singleton,
        "exact" => true, "owner" => m.owner.name || "#<Class:#{m.owner.attached_object.name}>",
        "source_location" => m.source_location&.join(":"),
        "visibility" => holder.public_method_defined?(name) ? "public" : holder.protected_method_defined?(name) ? "protected" : "private" }
    end

    def build
      return { "decline" => "URI version has no purity certificate" } unless %w[1.1.1 1.1.2].include?(URI::VERSION)
      root = File.dirname(URI.method(:join).source_location.fetch(0))
      raise "uncertified URI#join" unless File.basename(URI.method(:join).source_location.first) == "common.rb"
      files = SOURCES.to_h do |file, hashes|
        path = File.join(root, file)
        digest = Digest::SHA256.file(path).hexdigest
        raise "uncertified URI source #{file}" unless hashes.include?(digest)
        stat = File.stat(path)
        [path, { "mtime" => stat.mtime.to_r.to_s, "size" => stat.size, "sha256" => digest }]
      end
      facts = []
      methods = %i[initialize parser set_scheme set_host set_port set_userinfo split_userinfo set_path set_opaque
        query= fragment= default_port merge absolute? authority set_authority path query fragment merge_path split_path]
      ruby = [[URI, true, %i[join for]], [URI.const_get(:Schemes), true, %i[escape find]],
        [URI::RFC3986_Parser, false, %i[join convert_to_uri parse split regexp]]]
      [URI::Generic, URI::HTTP, URI::HTTPS].each do |mod|
        ruby << [mod, false, methods]
        ruby << [mod, true, %i[default_port]]
      end
      ruby.each do |mod, singleton, names|
        names.each do |name|
          m = (singleton ? mod.singleton_class : mod).instance_method(name)
          location = m.source_location
          raise "uncertified #{mod}##{name}" unless location && files.key?(location.first) && m.original_name == name
          facts << method_fact(mod, name, singleton: singleton)
        end
      end
      native = NATIVE.merge(URI::RFC3986_Parser => %i[== __send__],
        URI::Generic => %i[class dup initialize_dup initialize_copy],
        URI::HTTP => %i[class dup initialize_dup initialize_copy],
        URI::HTTPS => %i[class dup initialize_dup initialize_copy])
      native.each do |mod, names|
        names.each do |name|
          m = mod.instance_method(name)
          raise "non-native #{mod}##{name}" unless (!m.source_location || m.source_location.first.start_with?("<internal:")) && m.original_name == name
          facts << method_fact(mod, name)
        end
      end
      raise "custom string conversion" if String.method(:try_convert).source_location || String.method(:try_convert).original_name != :try_convert
      facts << method_fact(String, :try_convert, singleton: true)
      timeout = Regexp.method(:timeout)
      raise "custom regexp timeout getter" if timeout.source_location || timeout.original_name != :timeout
      facts << method_fact(Regexp, :timeout, singleton: true)
      %i[const_defined? const_get].each do |name|
        schemes = URI.const_get(:Schemes)
        m = schemes.method(name)
        raise "custom scheme dispatch" if m.source_location || m.original_name != name
        facts << method_fact(schemes, name, singleton: true)
      end
      [URI::Generic, URI::HTTP, URI::HTTPS].each do |mod|
        %i[new allocate].each do |name|
          m = mod.method(name)
          raise "custom URI constructor" if m.source_location || m.original_name != name
          facts << method_fact(mod, name, singleton: true)
        end
      end
      %w[memo.rb memo_facts.rb].each do |file|
        path = File.join(__dir__, file)
        stat = File.stat(path)
        files[path] = { "mtime" => stat.mtime.to_r.to_s, "size" => stat.size, "sha256" => Digest::SHA256.file(path).hexdigest }
      end
      { "facts" => facts.uniq, "sources" => files, "config" => config }
    rescue StandardError => e
      { "decline" => e.message }
    end

    # Only immutable parser state and primitive class constants are inputs.
    # Request/asset/config helpers are residual calls, not boot constants.
    def config
      parser = URI::DEFAULT_PARSER
      raise "regexp timeouts are observable runtime inputs" unless Regexp.timeout.nil? &&
        [*parser.regexp.values, URI::RFC3986_Parser::RFC3986_URI, URI::RFC3986_Parser::RFC3986_relative_ref].all? { _1.timeout.nil? }
      raise "mutable/custom URI parser" unless parser.instance_of?(URI::RFC3986_Parser) && parser.frozen? &&
        parser.regexp.frozen? && parser.regexp.values.all?(&:frozen?) && URI::PARSER.equal?(parser)
      escapes = %i[ReservedChars EscapedChars].map { URI.const_get(:Schemes).singleton_class.const_get(_1) }
      raise "mutable/custom scheme config" unless escapes.all? { _1.instance_of?(String) && _1.frozen? } &&
        URI::HTTP::DEFAULT_PORT.instance_of?(Integer) && URI::HTTPS::DEFAULT_PORT.instance_of?(Integer) && URI::Generic::DEFAULT_PORT.nil?
      initial = URI.const_get(:INITIAL_SCHEMES)
      raise "custom scheme table" unless initial.instance_of?(Hash) && initial.frozen? && initial.empty? &&
        initial.default.nil? && initial.default_proc.nil? && initial.singleton_methods.empty?
      { "version" => URI::VERSION, "ports" => [URI::HTTP::DEFAULT_PORT, URI::HTTPS::DEFAULT_PORT],
        "scheme_escapes" => escapes, "regexp_timeout" => nil,
        "regexp" => parser.regexp.to_h { |k, v| [k.to_s, [v.source, v.options]] },
        "absolute" => [URI::RFC3986_Parser::RFC3986_URI.source, URI::RFC3986_Parser::RFC3986_URI.options],
        "relative" => [URI::RFC3986_Parser::RFC3986_relative_ref.source, URI::RFC3986_Parser::RFC3986_relative_ref.options] }
    end
  end
end
