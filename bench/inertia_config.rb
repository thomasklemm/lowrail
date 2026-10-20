# frozen_string_literal: true

# From a prepared corpus app: LOWRAIL=0 bundle exec ruby --yjit
# /abs/lowrail/bench/inertia_config.rb micro
# Or with a production config-bind-only build and LOWRAIL_STATS enabled:
# RUBYOPT='-I/abs/lowrail/gem/lib -rlowrail/setup' ... inertia_config.rb check
require "json"
require "rack/mock"
require File.expand_path("config/environment", Dir.pwd)
require_relative "../gem/lib/lowrail"
require_relative "../gem/lib/lowrail/manifest"
require_relative "../gem/lib/lowrail/guard"
require_relative "../gem/lib/lowrail/inertia_config_build"

Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT required" unless RubyVM::YJIT.enabled?
pass = Lowrail::Passes::InertiaConfig

case ARGV.fetch(0)
when "micro"
  abort "boot without Lowrail" if Lowrail.manifest
  config = InertiaRails.configuration
  controller = ApplicationController.new
  # Normal method dispatch on both arms, not Method#call charged only to Rails.
  config.singleton_class.alias_method(:lowrail_original_bind_controller, :bind_controller)
  original = -> { config.lowrail_original_bind_controller(controller) }
  built = Lowrail::InertiaConfigBuild.build
  abort built[:ledger].inspect unless built[:units].size == 1
  built[:units].first["id"] = 0
  manifest = Lowrail::Manifest.new({"format" => 1, "ruby_description" => RUBY_DESCRIPTION,
    "compile_option" => Lowrail::Manifest.compile_option_fingerprint, "files" => {}, "units" => built[:units]}, Dir.pwd)
  Lowrail::Guard.install(manifest)
  pass.install(manifest.units)
  pass.activate
  a, b = original.call, config.bind_controller(controller)
  raise "not a fast path" unless Lowrail::G[0]
  raise "different result" unless a.class == b.class && a.instance_variable_get(:@options) == b.instance_variable_get(:@options) &&
    !a.instance_variable_get(:@options).equal?(b.instance_variable_get(:@options))
  arms = {"original" => original, "guarded" => -> { config.bind_controller(controller) }}
  n = Integer(ENV.fetch("BIND_CALLS", "50000"))
  rows = Array.new(5) do |round|
    arms.keys.rotate(round % 2).to_h do |name|
      call = arms.fetch(name)
      2000.times { call.call }
      allocated = GC.stat(:total_allocated_objects)
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      n.times { call.call }
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      [name, {us: elapsed * 1e6 / n, objects: (GC.stat(:total_allocated_objects) - allocated).fdiv(n)}]
    end
  end
  median = ->(xs) { xs.sort[xs.size / 2] }
  puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, app: Rails.application.class.name,
    calls: n, rounds: rows, median: arms.keys.to_h { |name|
      [name, %i[us objects].to_h { |metric| [metric, median.call(rows.map { _1.fetch(name).fetch(metric) })] }]
    })
when "check"
  require "active_support/testing/time_helpers"
  include ActiveSupport::Testing::TimeHelpers
  abort "enable stats and only config-bind" unless defined?(Lowrail::Stats) && Lowrail::Stats.enabled? &&
    Lowrail.manifest.units.size == 1 && Lowrail.manifest.units.first["pass"] == pass::PASS
  id = Lowrail.manifest.units.first.fetch("id")
  # No authentication stubs, body masking or token substitution. Replay the
  # exact entropy stream and freeze the clock for a literal byte comparison.
  entropy = Module.new do
    attr_accessor :tape, :replay, :cursor
    def random_bytes(n = nil)
      if replay
        args, value = tape.fetch(cursor)
        raise "different entropy call" unless args == n
        self.cursor += 1
        value.dup
      else
        super.tap { |value| tape << [n, value.dup] if tape }
      end
    end
  end
  random_sources = [SecureRandom, OpenSSL::Random]
  random_sources.each { _1.singleton_class.prepend(entropy) }
  paths = JSON.parse(File.read("tmp/m0/paths.json"))
  client = Rack::MockRequest.new(Rails.application)
  rows = []
  travel_to(Time.utc(2026, 10, 20, 12), with_usec: true) do
    paths.each do |name, path|
      %w[html json].each do |format|
        headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on"}.merge(JSON.parse(File.read("tmp/m0/headers-#{format}.json")))
        request = -> { client.get(path, headers).tap { raise "HTTP #{_1.status}" unless _1.status == 200 } }
        20.times { request.call }
        Lowrail::Guard.state[id] = false
        random_sources.each { _1.tape, _1.replay, _1.cursor = [], false, 0 }
        off = request.call
        Lowrail::Guard.state[id] = nil
        random_sources.each { _1.replay = true }
        on = request.call
        raise "different entropy count" unless random_sources.all? { _1.cursor == _1.tape.size }
        raise "body bytes differ: #{name}/#{format}" unless off.body.b == on.body.b
        different_headers = (off.headers.keys | on.headers.keys).select { off.headers[_1] != on.headers[_1] }
        # Rack::Runtime deliberately measures each request; it is not content.
        raise "response headers differ: #{name}/#{format}: #{different_headers.inspect}" unless (different_headers - ["x-runtime"]).empty?
        random_sources.each { _1.replay, _1.tape = false, nil }
        Lowrail::Stats.reset_counts!
        20.times { request.call }
        hits = Lowrail::Stats.unit_hits.fetch(id.to_s, 0)
        raise "unexplained fallbacks" unless Lowrail::Stats.unit_fallbacks.empty?
        raise "no hits" unless hits.positive?
        rows << {route: name, format: format, bytes: on.body.bytesize,
          sha256: Digest::SHA256.hexdigest(on.body), hits_per_request: hits.fdiv(20), fallbacks: 0}
      end
    end
  end
  puts JSON.pretty_generate(rows)
else
  abort "expected micro or check"
end
