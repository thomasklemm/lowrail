# frozen_string_literal: true

module Lowrail
  # Reuse a file hash only after reading exactly the current binary stream.
  # Cache misses hash those same bytes: never reopen a path after comparison.
  module DigestMemo
    LIMIT = 1024 * 1024
    ENTRIES = 32
    CLASS = Kernel.instance_method(:class)
    IVAR = Kernel.instance_method(:instance_variable_get)

    class << self
      def install(manifest)
        @units = manifest.units.select { _1["pass"] == "digest/file_memo" }.to_h { [_1.fetch("id"), _1] }
        @cache = {}
        @algorithms = {}
        @digest = @instance = nil
      end

      def valid?(id)
        state = Guard.state
        return state[id] unless state[id].nil?
        unit = @units.fetch(id)
        valid = Guard.validate(id) && unit.fetch("digest_memo").fetch("sources").all? do |path, sha|
          Manifest.sha256_file(path) == sha
        end && unit.fetch("facts").all? do |fact|
          mod = Object.const_get(fact.fetch("receiver"))
          mod = mod.singleton_class if fact["singleton"]
          mod.instance_method(fact.fetch("method")).original_name.to_s == fact.fetch("original_name")
        end
        if valid
          @algorithms[id] = unit.fetch("digest_memo").fetch("algorithms").map { Object.const_get(_1) }
          # Setup runs before Bundler. Do not activate Digest until the app has.
          @digest ||= ::Digest
          @instance ||= ::Digest::Instance
        end
        state[id] = valid
      rescue StandardError
        state[id] = false
      end

      def hexdigest(id, algorithm, name)
        return algorithm.file(name).hexdigest unless Ractor.main?
        if supported_path?(name) && valid?(id) && @digest.equal?(::Digest) &&
            @digest.const_defined?(:Instance, false) && @instance.equal?(@digest.const_get(:Instance, false)) &&
            !@digest.const_defined?(:File, false) && !@instance.const_defined?(:File, false) &&
            @algorithms[id].any? { _1.equal?(algorithm) }
          file_hexdigest(id, algorithm, name)
        else
          Stats.count(id, false) if defined?(Stats) && Stats.enabled?
          algorithm.file(name).hexdigest
        end
      end

      def supported_path?(name)
        klass = CLASS.bind_call(name)
        klass.equal?(::String) || klass.equal?(::Integer) ||
          (defined?(::Pathname) && klass.equal?(::Pathname) &&
            CLASS.bind_call(IVAR.bind_call(name, :@path)).equal?(::String))
      end

      def file_hexdigest(id, algorithm, name)
        bytes = +"".b
        streamed = nil
        # Match Digest::Instance#file's open mode, chunk size and read buffer.
        # If a pathname is replaced during reading, the open descriptor wins.
        ::File.open(name, "rb") do |file|
          buffer = +""
          while file.read(16_384, buffer)
            if streamed
              streamed.update(buffer)
            elsif bytes.bytesize + buffer.bytesize <= LIMIT
              bytes << buffer
            else
              streamed = algorithm.new
              streamed.update(bytes)
              streamed.update(buffer)
              bytes = nil
            end
          end
        end
        return streamed.hexdigest if streamed

        cache = (@cache[id] ||= {})
        # The hash is only an index. Full byte equality proves every hit,
        # including collisions; no path coercion or extra file operation.
        key = [algorithm, bytes.hash]
        if (entry = cache[key]) && entry[0] == bytes
          Stats.count(id, true) if defined?(Stats) && Stats.enabled?
          return entry[1].dup
        end
        result = algorithm.new.update(bytes).hexdigest
        cache.shift if cache.size >= ENTRIES && !cache.key?(key)
        cache[key] = [bytes.freeze, result.dup.freeze].freeze
        result
      end
    end
  end
end
