# frozen_string_literal: true

module Lowrail
  # Per-site pure-expression memo. Bounded storage, no exception caching, no
  # retained request/controller/helper objects and no shared mutable returns.
  module Memo
    LIMIT = 256
    CLASS = Kernel.instance_method(:class)
    SINGLETON_METHODS = Kernel.instance_method(:singleton_methods)
    PRIVATE_METHODS = Kernel.instance_method(:private_methods)
    IVARS = Kernel.instance_method(:instance_variables)
    IVGET = Kernel.instance_method(:instance_variable_get)
    IVSET = Kernel.instance_method(:instance_variable_set)
    TRACE_STAT = TracePoint.method(:stat)
    STRING_PRIVATE = String.private_instance_methods(false).sort.freeze
    module_function

    def install(manifest)
      @units = manifest.units.select { _1["pass"] == "memo/uri_join" }.to_h { [_1.fetch("id"), _1] }
      @prepared = {}
    end

    def join(id, receiver, base, relative)
      unit = @units[id]
      # Keep traced calls in the original program, including target TracePoints
      # and set_trace_func. Do not hide instrumentation events on cache hits.
      return yield(receiver, base, relative) unless unit && TRACE_STAT.call.each_value.all? { _1.first.zero? }
      state = Guard.state
      # Any method invalidation starts a new memo generation, even if a patch
      # restores the same owner/source line. Never revive an old generation.
      if state[id].nil?
        @prepared.delete(id)
        state[id] = Guard.validate(id)
      end
      return yield(receiver, base, relative) unless state[id]
      memo = @prepared.fetch(id) { @prepared[id] = prepare(unit) }
      return yield(receiver, base, relative) unless memo && receiver.equal?(memo[:uri]) && constants_hold?(memo) &&
        plain_string?(base) && plain_string?(relative) && base.ascii_only? && relative.ascii_only? &&
        /\Ahttps?:\/\//i.match?(base) && !/\A(?!https?:)[a-z][a-z0-9+.-]*:/i.match?(relative)
      # Encoding is part of the key: Ruby string equality alone equates ASCII
      # strings in several encodings, but URI component encodings are observable.
      key = [base, base.encoding, relative, relative.encoding]
      if (value = memo[:values][key])
        result = copy(value)
        Stats.count(id, true) if defined?(Stats) && Stats.enabled?
        return result
      end
      result = yield(receiver, base, relative) # original lexical dispatch; exceptions outside rescue
      if memo[:values].size < LIMIT && [URI::HTTP, URI::HTTPS].include?(result.class) &&
          IVARS.bind_call(result).all? { |v| x = IVGET.bind_call(result, v); x.nil? || x.instance_of?(String) || x.instance_of?(Integer) }
        memo[:values][[base.dup.freeze, base.encoding, relative.dup.freeze, relative.encoding]] = copy(result)
      end
      result
    end

    def plain_string?(s)
      CLASS.bind_call(s).equal?(String) && SINGLETON_METHODS.bind_call(s).empty? &&
        PRIVATE_METHODS.bind_call(s, false).sort == STRING_PRIVATE
    end

    def copy(uri)
      result = uri.dup
      IVARS.bind_call(uri).each do |name|
        value = IVGET.bind_call(uri, name)
        if value.instance_of?(String)
          string = value.dup
          string.freeze if value.frozen?
          IVSET.bind_call(result, name, string)
        end
      end
      result
    end

    def prepare(unit)
      require_relative "memo_facts"
      data = unit.fetch("memo")
      return false unless data.fetch("sources").all? { |path, fact|
        File.file?(path) && File.size(path) == fact.fetch("size") && File.mtime(path).to_r.to_s == fact.fetch("mtime") &&
          Digest::SHA256.file(path).hexdigest == fact.fetch("sha256")
      } && MemoFacts.config == data.fetch("config")
      # Guard's source-location facts intentionally tolerate restored aliases;
      # certification also rejects native aliases with a different original name.
      return false if MemoFacts.build["decline"]
      initial = URI.const_get(:INITIAL_SCHEMES)
      schemes = URI.const_get(:Schemes)
      return false unless initial.instance_of?(Hash) && initial.frozen? && initial.empty? &&
        initial.default.nil? && initial.default_proc.nil? && initial.singleton_methods.empty? &&
        schemes.const_get(:HTTP).equal?(URI::HTTP) && schemes.const_get(:HTTPS).equal?(URI::HTTPS)
      { uri: URI, constants: constants, values: {} }
    rescue StandardError, LoadError
      false # stale/incompatible input: original program still runs
    end

    def constants_hold?(memo)
      constants.each_with_index.all? { |v, i| v.equal?(memo[:constants][i]) }
    rescue NameError
      false
    end

    def constants
      [URI, URI::Generic, URI::HTTP, URI::HTTPS, URI::RFC3986_Parser, URI::DEFAULT_PARSER,
        URI.const_get(:INITIAL_SCHEMES), URI::RFC3986_Parser::RFC3986_URI, URI::RFC3986_Parser::RFC3986_relative_ref,
        URI::HTTP::DEFAULT_PORT, URI::HTTPS::DEFAULT_PORT, URI::Generic::DEFAULT_PORT, URI::PARSER, URI.const_get(:Schemes),
        URI.const_get(:Schemes).const_get(:HTTP), URI.const_get(:Schemes).const_get(:HTTPS),
        URI.const_get(:Schemes).singleton_class.const_get(:ReservedChars), URI.const_get(:Schemes).singleton_class.const_get(:EscapedChars),
        Encoding::UTF_8, Encoding::ASCII_8BIT, Encoding::US_ASCII]
    end
  end
end
