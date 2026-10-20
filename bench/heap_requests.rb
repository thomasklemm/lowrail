# frozen_string_literal: true

# Fixed-heap instruction worker. Keep separate from the native timing worker:
# even unused additional ISeqs can change its initial heap/GC phase.
if ENV.fetch("BENCH_JIT", "0") != "1"
  require File.expand_path("config/application", Dir.pwd)
  Rails.application.config.yjit = false
end
require File.expand_path("config/environment", Dir.pwd)
require "rack/mock"
require "json"
require_relative "heap_windows"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil if defined?(ActiveRecord::Base)
abort "usage: heap_requests.rb VERB:PATH" unless ARGV.size == 1
verb, path = ARGV.first.split(":", 2)
session = Rack::MockRequest.new(Rails.application)
headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")))
n = Integer(ENV.fetch("BENCH_REQUESTS", "50"))
raise "positive request count required" unless n.positive?

def counted_requests(n, session, verb, path, headers)
  n.times do
    response = session.request(verb, path, headers)
    raise "#{verb} #{path} -> #{response.status}" unless (200..299).cover?(response.status)
  end
end

# Prepopulate all observation hashes before warmup. No new reporting hashes
# or arrays are allocated between each window's GC.stat endpoints.
windows = HeapWindows.windows(n)
counted_requests(Integer(ENV.fetch("BENCH_WARMUP", "50")), session, verb, path, headers)
if RubyVM::YJIT.enabled?
  require_relative "jit_stability"
  jit_warmup = JitStability.warm { |count| counted_requests(count, session, verb, path, headers) }
  observe = JitStability.method(:snapshot)
end

# Init slots are lazy growth floors, not preallocated pages. Fill each pool
# explicitly, then discard most fillers. On 64-bit MRI these Array lengths
# occupy 40/80/160/320/640-byte slots; actual capacities are checked by the
# driver. GC is disabled only during this untimed preparation, never during
# warmup or a measured request. Sparse anchors keep pages from moving to the
# tomb heap during full GC. Their small, artificial live set is reported.
anchors = HeapWindows.run(windows, observe: observe) do |count|
  counted_requests(count, session, verb, path, headers)
end
ar_installed = 0
if defined?(Lowrail::ARInstantiate)
  ar_installed = Lowrail.manifest.units.count do |unit|
    unit["pass"] == "active_record/instantiate" &&
      Object.const_get(unit.fetch("ar_instantiate").fetch("model")).instance_variable_defined?(:@_lowrail_instantiate)
  end
end
puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?, windows: windows,
  heap_anchors: anchors, ar_installed: ar_installed, jit_warmup: jit_warmup,
  compiled_iseqs: RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_iseq_count] : 0)}"
