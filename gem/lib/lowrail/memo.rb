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
    TRACE_ENABLED = TracePoint.instance_method(:enabled?)
    TIMEOUT = Regexp.method(:timeout)
    NATIVE_TIMEOUT = TIMEOUT.source_location.nil? && TIMEOUT.original_name == :timeout
    STRING_PRIVATE = String.private_instance_methods(false).sort.freeze

    # TracePoint.stat excludes targeted hooks. Once Ruby tracing may have
    # become observable, keep this process on the original program forever.
    module TraceConstructors
      def new(...)
        Memo.tracing!
        super
      end

      def trace(...)
        Memo.tracing!
        super
      end
    end

    module TraceActivation
      def enable(...)
        Memo.tracing!
        super
      end
    end
    module_function

    def install(units)
      unless defined?(@tracing)
        @tracing = false
        TracePoint.singleton_class.prepend(TraceConstructors)
        TracePoint.prepend(TraceActivation)
        # Lowrail's preexisting RSpec attach hook observes only :end. Neither
        # certified operation executes class/module bodies; keep this hook intact.
        @reporter_trace = IVGET.bind_call(Lowrail::RSpec, :@load_hook) if defined?(Lowrail::RSpec)
        @reporter_trace = nil unless TracePoint === @reporter_trace
        sentinel = Object.new
        visible = false
        ObjectSpace.each_object do |object|
          visible = true if sentinel.equal?(object)
          @tracing = true if TracePoint === object && !object.equal?(@reporter_trace)
          if Ractor === object && !object.equal?(Ractor.main)
            @tracing = "ractor_trace_visibility: cannot certify tracing in another Ractor's heap"
          end
        end
        # 4.0 hides even our sentinel after multi-Ractor mode starts. 4.1
        # exposes our heap again, but still hides other Ractors' TracePoints.
        @tracing ||= "ractor_trace_visibility: ObjectSpace hides unshareable tracing state" unless visible
      end
      @units = units.to_h { [_1.fetch("id"), _1] }
      @prepared = {}
    end

    def refusal_reason = (String === @tracing ? @tracing : nil)

    def tracing!
      @tracing = true if Ractor.main?
    end

    def join(id, receiver, base, relative)
      return yield(receiver, base, relative) unless Ractor.main?
      return yield(receiver, base, relative) unless NATIVE_TIMEOUT && TIMEOUT.call.nil?
      memo = prepared(id)
      return yield(receiver, base, relative) unless memo && receiver.equal?(memo[:uri]) && constants_hold?(memo) &&
        plain_string?(base) && plain_string?(relative)
      base_snapshot, relative_snapshot = base.dup.freeze, relative.dup.freeze
      return yield(receiver, base, relative) unless base_snapshot.ascii_only? && relative_snapshot.ascii_only? &&
        /\Ahttps?:\/\//i.match?(base_snapshot) && !/\A(?!https?:)[a-z][a-z0-9+.-]*:/i.match?(relative_snapshot)
      # Encoding is part of the key: Ruby string equality alone equates ASCII
      # strings in several encodings, but URI component encodings are observable.
      key = [base_snapshot, base_snapshot.encoding, relative_snapshot, relative_snapshot.encoding]
      if (value = memo[:values][key])
        result = copy(value)
        Stats.count(id, true) if defined?(Stats) && Stats.enabled?
        return result
      end
      result = yield(receiver, base_snapshot, relative_snapshot) # original lexical dispatch; exceptions outside rescue
      if memo[:values].size < LIMIT && [URI::HTTP, URI::HTTPS].include?(result.class) &&
          IVARS.bind_call(result).all? { |v| x = IVGET.bind_call(result, v); x.nil? || x.instance_of?(String) || x.instance_of?(Integer) }
        memo[:values][key] = copy(result)
      end
      result
    end

    def digest(id, receiver, string)
      return yield(receiver, string) unless Ractor.main?
      memo = prepared(id)
      return yield(receiver, string) unless memo && constants_hold?(memo) && receiver.equal?(memo[:constants][1]) && plain_string?(string)
      # Lookup, computation and insertion must see identical bytes/encoding,
      # even if another thread mutates the caller's input at a Ruby return.
      input = string.dup.freeze
      key = [input, input.encoding]
      if (value = memo[:values][key])
        result = value.dup
        Stats.count(id, true) if defined?(Stats) && Stats.enabled?
        return result
      end
      result = yield(receiver, input)
      memo[:values][key] = result.dup.freeze if memo[:values].size < LIMIT
      result
    end

    def prepared(id)
      unit = @units[id]
      # TracePoint.stat excludes targeted hooks; @tracing is sticky for them.
      return false unless unit && !@tracing
      passive = @reporter_trace && TRACE_ENABLED.bind_call(@reporter_trace) ? 1 : 0
      return false unless TRACE_STAT.call.each_value.all? { _1.first == passive }
      state = Guard.state
      # Any method invalidation starts a new memo generation, even if a patch
      # restores the same owner/source line. Never revive an old generation.
      if state[id].nil?
        @prepared.delete(id)
        state[id] = Guard.validate(id)
      end
      state[id] && @prepared.fetch(id) { @prepared[id] = prepare(unit) }
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
      }
      if data["intrinsic"] == "sha256"
        certificate = MemoFacts.digest
        return false if certificate["decline"] || certificate["config"] != data.fetch("config")
        return { intrinsic: "sha256", constants: constants("sha256"), values: {} }
      end
      return false unless MemoFacts.config == data.fetch("config")
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
      constants(memo[:intrinsic]).each_with_index.all? { |v, i| v.equal?(memo[:constants][i]) }
    rescue NameError
      false
    end

    def constants(intrinsic = nil)
      return [Digest, Digest::SHA256, Digest::Class, Digest::Base, Digest::Instance] if intrinsic == "sha256"
      [URI, URI::Generic, URI::HTTP, URI::HTTPS, URI::RFC3986_Parser, URI::DEFAULT_PARSER,
        URI.const_get(:INITIAL_SCHEMES), URI::RFC3986_Parser::RFC3986_URI, URI::RFC3986_Parser::RFC3986_relative_ref,
        URI::HTTP::DEFAULT_PORT, URI::HTTPS::DEFAULT_PORT, URI::Generic::DEFAULT_PORT, URI::PARSER, URI.const_get(:Schemes),
        URI.const_get(:Schemes).const_get(:HTTP), URI.const_get(:Schemes).const_get(:HTTPS),
        URI.const_get(:Schemes).singleton_class.const_get(:ReservedChars), URI.const_get(:Schemes).singleton_class.const_get(:EscapedChars),
        Encoding::UTF_8, Encoding::ASCII_8BIT, Encoding::US_ASCII]
    end
  end

  module Passes
    Memo = Lowrail::Memo
  end
end
