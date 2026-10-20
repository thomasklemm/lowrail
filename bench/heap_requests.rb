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
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")

Rails.application.eager_load!
Rails.logger.level = :warn
ActiveRecord::Base.logger = nil
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
order = %w[total no_gc]
order.reverse! if ENV["BENCH_PHASE_ORDER"] == "1"
windows = order.product([0, n]).map do |mode, count|
  { mode: mode, requests: count, before: GC.stat, after: GC.stat,
    pools_before: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] },
    pools_after: GC.stat_heap.keys.to_h { [_1, GC.stat_heap(_1)] } }
end
counted_requests(Integer(ENV.fetch("BENCH_WARMUP", "50")), session, verb, path, headers)

# Init slots are lazy growth floors, not preallocated pages. Fill each pool
# explicitly, then discard most fillers. On 64-bit MRI these Array lengths
# occupy 40/80/160/320/640-byte slots; actual capacities are checked by the
# driver. GC is disabled only during this untimed preparation, never during
# warmup or a measured request. Sparse anchors keep pages from moving to the
# tomb heap during full GC. Their small, artificial live set is reported.
3.times { GC.start }
raise "app disabled GC" if GC.disable
lengths = [0, 4, 9, 19, 39]
anchors = []
GC.stat_heap.each do |pool, stats|
  target = Integer(ENV.fetch("RUBY_GC_HEAP_#{pool}_INIT_SLOTS"))
  length = lengths.fetch(pool)
  count = [target - GC.stat_heap(pool, :heap_live_slots), 0].max
  fillers = Array.new(count) { Array.new(length) }
  stride = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / stats.fetch(:slot_size) / 2
  fillers.each_with_index { |object, index| anchors << object if (index % stride).zero? }
  anchors << fillers.last unless fillers.empty?
  fillers.clear
end
GC.enable

windows.each do |window|
  # Mature surviving objects as well as collecting garbage. Anchored pages
  # keep capacities comparable; the driver checks every measured window.
  3.times { GC.start }
  window[:pools_before].each { |pool, stats| GC.stat_heap(pool, stats) }
  GC.stat(window[:before])
  LowrailCallgrindBench.start(window[:mode] == "no_gc")
  counted_requests(window[:requests], session, verb, path, headers)
  segments = LowrailCallgrindBench.finish
  GC.stat(window[:after])
  window[:pools_after].each { |pool, stats| GC.stat_heap(pool, stats) }
  window[:gc_segments] = segments
end
ar_installed = 0
if defined?(Lowrail::ARInstantiate)
  ar_installed = Lowrail.manifest.units.count do |unit|
    unit["pass"] == "active_record/instantiate" &&
      Object.const_get(unit.fetch("ar_instantiate").fetch("model")).instance_variable_defined?(:@_lowrail_instantiate)
  end
end
puts "LOWRAIL_BENCH #{JSON.generate(ruby: RUBY_DESCRIPTION, yjit: !!RubyVM::YJIT.enabled?, windows: windows,
  heap_anchors: anchors.size, ar_installed: ar_installed,
  compiled_iseqs: RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats[:compiled_iseq_count] : 0)}"
