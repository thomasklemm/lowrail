# frozen_string_literal: true

require "json"
require "digest"
require "rbconfig"

module BlogProduction
  # Disposable scenario inputs, NOT a runtime feature or production security
  # recipe. Never active in raw workers or outside the current request thread.
  module Entropy
    POLICY = File.expand_path("blog-entropy-controls.json", __dir__)
    SECRET = "lowrail-disposable-blog-companion-only-" * 4
    CONTEXT = :lowrail_blog_entropy_companion

    def self.source_pin(app)
      files = Dir[File.join(app, "{app,config,db,test}/**/*")].select do |file|
        File.file?(file) && %w[.rb .erb .jbuilder .yml].include?(File.extname(file))
      end.sort.to_h { [_1.delete_prefix(app + "/"), Digest::SHA256.file(_1).hexdigest] }
      Digest::SHA256.hexdigest(JSON.generate(files))
    end

    def self.source_path(key)
      gem, file = key.split(":", 2)
      root = gem == "ruby" ? RbConfig::CONFIG.fetch("rubylibdir") : (Gem.loaded_specs[gem] || Gem::Specification.find_by_name(gem)).full_gem_path
      File.join(root, file)
    end

    def self.validate(app, policy: JSON.parse(File.read(POLICY)))
      reason = if policy.fetch("app_source_sha256") != source_pin(app)
        "app source pin mismatch"
      elsif policy.fetch("lock_sha256") != Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest
        "lockfile pin mismatch"
      elsif policy.fetch("ruby_version") != RUBY_VERSION
        "Ruby version pin mismatch"
      else
        policy.fetch("runtime_sources").find { |key, digest| Digest::SHA256.file(source_path(key)).hexdigest != digest }&.then { |key, _| "runtime source pin mismatch: #{key}" }
      end
      {"active" => reason.nil?, "reason" => reason, "policy" => policy}
    rescue KeyError, Errno::ENOENT, Gem::LoadError => error
      {"active" => false, "reason" => "missing entropy pin: #{error.message}", "policy" => policy}
    end

    def self.install(policy)
      @sites = policy.fetch("random_sites").map { _1.merge("path" => source_path(_1.fetch("source"))) }
      @runtime_path = source_path("rack:lib/rack/runtime.rb")
      require "securerandom"
      require "openssl"
      require "rack/utils"
      SecureRandom.singleton_class.prepend(Bytes)
      OpenSSL::Random.singleton_class.prepend(Bytes)
      Rack::Utils.singleton_class.prepend(RuntimeClock)
      Time.singleton_class.prepend(WallClock) if policy["wall_clock"]
      @wall_clock = policy["wall_clock"]
    end

    def self.with(seed, scenario, requests: 1, wall_clock: false)
      raise "nested entropy control" if Thread.current.thread_variable_get(CONTEXT)
      context = {"seed" => seed, "scenario" => scenario, "requests" => requests, "wall_clock" => wall_clock,
        "rngs" => {}, "trace" => [], "clock_reads" => [], "wall_clock_reads" => [], "errors" => []}
      Thread.current.thread_variable_set(CONTEXT, context)
      result = yield
      if context.fetch("clock_reads").size != 2 * context.fetch("requests")
        context.fetch("errors") << "expected exactly two Rack::Runtime clock reads per declared request"
      end
      [result, context.reject { %w[rngs seed scenario requests].include?(_1) }]
    ensure
      Thread.current.thread_variable_set(CONTEXT, nil)
    end

    def self.expect_request!
      context = Thread.current.thread_variable_get(CONTEXT)
      context["requests"] += 1 if context
    end

    def self.wall_clock(real, callers, options)
      context = Thread.current.thread_variable_get(CONTEXT)
      return real unless context && context["wall_clock"] && @wall_clock
      pinned = Time.at(@wall_clock.fetch("epoch"), **options)
      context.fetch("wall_clock_reads") << {"real" => real.to_f, "pinned" => pinned.to_i, "caller" => callers.first.to_s}
      context.fetch("trace") << {"site" => "Time.now", "epoch" => pinned.to_i,
        "caller" => callers.first.to_s}
      pinned
    end

    def self.bytes(provider, size, callers)
      context = Thread.current.thread_variable_get(CONTEXT)
      return unless context
      site = @sites.find do |entry|
        entry.fetch("provider") == provider && entry.fetch("bytes") == size &&
          callers.any? { _1.path == entry.fetch("path") && _1.base_label == entry.fetch("method") }
      end
      unless site
        context.fetch("errors") << "undeclared entropy: #{provider}.random_bytes(#{size}) at #{callers.first}"
        return # Delegate normally, but reject the companion; never widen a pin.
      end
      name = site.fetch("name")
      rng = context.fetch("rngs")[name] ||= Random.new(Digest::SHA256.hexdigest(
        "#{context.fetch('seed')}/#{context.fetch('scenario')}/#{name}").to_i(16))
      bytes = Array.new(size) { rng.rand(256) }.pack("C*")
      context.fetch("trace") << {"site" => name, "bytes" => size, "sha256" => Digest::SHA256.hexdigest(bytes)}
      bytes
    end

    # Materialize arguments/backtraces only in a controlled companion.
    def self.controlled_random_bytes(provider, *args)
      bytes(provider.name, args.fetch(0, 16), caller_locations(2, 12))
    end

    def self.clock(real, caller)
      context = Thread.current.thread_variable_get(CONTEXT)
      return real unless context && caller.path == @runtime_path && caller.base_label == "call"
      reads = context.fetch("clock_reads")
      pinned = 1000.0 + reads.size * 0.001
      reads << {"real" => real, "pinned" => pinned}
      context.fetch("trace") << {"site" => "Rack::Runtime#call", "clock" => pinned}
      pinned
    end

    module Bytes
      def random_bytes(...)
        return super unless Thread.current.thread_variable_get(CONTEXT)
        Entropy.controlled_random_bytes(self, ...) || super
      end
    end

    module RuntimeClock
      def clock_time
        return super unless Thread.current.thread_variable_get(CONTEXT)
        Entropy.clock(super, caller_locations(1, 1).first)
      end
    end

    module WallClock
      def now(**options)
        return super unless Thread.current.thread_variable_get(CONTEXT)
        Entropy.wall_clock(super, caller_locations(1, 1), options)
      end
    end
  end
end
