# frozen_string_literal: true

# Fixed-heap, seam-subtracted guard micros. One case per fresh process so
# shared JIT profiles cannot make one implementation subsidize another.
# Driver: ruby bench/guard_breakdown.rb OUT (requires Valgrind).
require "json"
require "fileutils"
require "rbconfig"
require_relative "request_pairs"

CASES = {
  "loop" => "true",
  "dispatch" => "GuardCostSite.yes(0, GuardCostReceiver)",
  "receiver" => "GuardCostSite.yes(0, object.class)",
  "array" => "Lowrail::V[0]",
  "hash" => "cache[GuardCostReceiver]",
  "cached" => "Lowrail.ok?(0, object.class)",
  "inline" => "object.class.equal?(Lowrail::K[0]) || Lowrail.ok?(0, object.class)",
  "inline_truthy" => "(Lowrail::K[0] && object.class.equal?(Lowrail::K[0])) || Lowrail.ok?(0, object.class)",
  "mono" => "object.class.equal?(@klass) && @epoch == GuardCostSite.epoch",
  "method_identity" => "@klass.instance_method(:foo) == @method",
  "object_method" => "object.method(:foo).unbind == @method",
  "visibility" => "@klass.public_method_defined?(:foo)",
  "constant_identity" => "::GuardCostReceiver.equal?(@klass)",
  "constant_counter" => "RubyVM.stat(:constant_cache_invalidations)",
  "constant_epoch" => "RubyVM.stat(:constant_cache_invalidations) == @constant_epoch",
  "snapshot" => "@options == @snapshot",
  "exact_method" => "object.class.equal?(@klass) && @epoch == GuardCostSite.epoch && @klass.instance_method(:foo) == @method && @klass.public_method_defined?(:foo)",
  "exact_residuals" => "(object.class.equal?(Lowrail::K[0]) || Lowrail.ok?(0, object.class)) && @klass.instance_method(:foo) == @method && @klass.public_method_defined?(:foo) && ::GuardCostReceiver.equal?(@klass) && @options == @snapshot"
}.freeze

if ARGV.first == "--worker"
  JitStability.assert_mode!
  $LOAD_PATH.unshift(ENV.fetch("GUARD_LOWRAIL_LIB", File.expand_path("../gem/lib", __dir__)))
  require "lowrail"
  require "lowrail/manifest"
  require "lowrail/guard"
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  class GuardCostReceiver
    def foo = 7
  end
  class GuardCostSite
    @klass, @epoch, @method = GuardCostReceiver, 0, GuardCostReceiver.instance_method(:foo)
    @options = { limit: 7, mode: :fast }
    @snapshot = @options.dup.freeze
    @constant_epoch = RubyVM.stat(:constant_cache_invalidations)
    def self.epoch = @epoch
    def self.yes(id, klass) = true
  end
  fact = { "receiver" => "@self", "method" => "foo", "owner" => "GuardCostReceiver", "visibility" => "public",
    "source_location" => GuardCostReceiver.instance_method(:foo).source_location.join(":") }
  manifest = Lowrail::Manifest.new({ "format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION, "compile_option" => "",
    "files" => {}, "units" => [{ "id" => 0, "facts" => [fact] }] }, "/tmp")
  Lowrail::Guard.install(manifest)
  100_000.times { Lowrail.ok?(0, GuardCostReceiver) }
  name = ARGV.fetch(1)
  # The case is compiled outside counters; no case dispatch in the loop.
  GuardCostSite.singleton_class.class_eval(<<~RUBY, __FILE__, __LINE__ + 1)
    def run(n)
      object = GuardCostReceiver.new
      cache = Lowrail::V[0]
      n.times { #{CASES.fetch(name)} }
    end
  RUBY
  GuardCostSite.run(100_000)
  jit_warmup = JitStability.warm { |count| GuardCostSite.run(count) } if JitStability.enabled?
  anchors = HeapWindows.prepare_heap
  if JitStability.enabled?
    200.times do
      GC.stat_heap.transform_values { _1.fetch(:heap_eden_slots) }
      JitStability.snapshot
    end
  end
  n = Integer(ENV.fetch("GUARD_REQUESTS", "100000"))
  modes = Integer(ENV.fetch("GUARD_ROUND", "0")).even? ? %w[total no_gc] : %w[no_gc total]
  windows = modes.product([0, n]).map do |mode, count|
    3.times { GC.start }
    before = GC.stat_heap.transform_values { _1.fetch(:heap_eden_slots) }
    jit_before = JitStability.snapshot if JitStability.enabled?
    LowrailCallgrindBench.start(mode == "no_gc")
    GuardCostSite.run(count)
    segments = LowrailCallgrindBench.finish
    jit_after = JitStability.snapshot if JitStability.enabled?
    { mode: mode, checks: count, capacities: before, gc_segments: segments,
      jit_before: jit_before, jit_after: jit_after }
  end
  puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, case: name, windows: windows, jit_warmup: jit_warmup)}"
  exit
end

out = File.expand_path(ARGV.fetch(0))
unless ARGV[1] == "--summarize"
  abort "output must be new" if File.exist?(out)
  FileUtils.mkdir_p(out)
  extension = RequestPairs.compile_counter_extension(out)
  rows = []
  env = { "BENCH_CALLGRIND_EXTENSION" => extension, "RUBYOPT" => nil, "LOWRAIL_SPECULATE" => nil,
    "BENCH_JIT" => ENV.fetch("GUARD_JIT", ENV.fetch("BENCH_JIT", "1")) }
  HeapWindows.floors.each_with_index { |n, i| env["RUBY_GC_HEAP_#{i}_INIT_SLOTS"] = n.to_s }
  RequestPairs.valgrind_preflight(out, env.select { |key, _| key.start_with?("RUBY_GC_HEAP_") }, app: Dir.pwd, env: env)
  6.times do |round|
    samples = {}
    (ENV.fetch("GUARD_CASES", CASES.keys.join(",")).split(",") + ["loop_b"]).shuffle(random: Random.new(41231 + round)).each do |label|
      name = label == "loop_b" ? "loop" : label
      prefix = File.join(out, "#{round}-#{label}")
      ok = system(env.merge("GUARD_ROUND" => round.to_s), "valgrind", "--tool=callgrind", "--instr-atstart=no", "--smc-check=all-non-file",
        "--log-file=#{prefix}.valgrind.log", "--callgrind-out-file=#{prefix}.callgrind",
        RbConfig.ruby, *JitStability.flags(env.fetch("BENCH_JIT")), __FILE__, "--worker", name,
        out: prefix + ".log", err: [:child, :out])
      RequestPairs.check_valgrind_log!(out, "#{round}-#{label}")
      abort "failed: #{prefix}.log" unless ok
      meta = JSON.parse(File.readlines(prefix + ".log").find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
      values = 4.times.map { |i| Integer(File.read("#{prefix}.callgrind.#{i + 1}")[/^totals: (\d+)/, 1]) }
      metrics = %w[total no_gc].to_h do |mode|
        indices = meta.fetch("windows").each_index.select { meta.fetch("windows")[_1].fetch("mode") == mode }
        [mode, (values[indices[1]] - values[indices[0]]).fdiv(meta.fetch("windows")[indices[1]].fetch("checks"))]
      end
      samples[label] = metrics.merge(metadata: meta)
    end
    rows << samples
    File.write(File.join(out, "samples.json"), JSON.pretty_generate(rows))
    warn "guard round #{round + 1}/6"
  end
end
rows = JSON.parse(File.read(File.join(out, "samples.json")))
summary = rows.first.keys.to_h do |name|
  [name, %i[total no_gc].to_h do |metric|
    [metric, RequestPairs.estimate(rows.map { _1.fetch(name).fetch(metric.to_s) }, seed: 41231)]
  end]
end
capacities = rows.flat_map { |row| row.values.flat_map { _1.fetch("metadata").fetch("windows").map { |w| w.fetch("capacities") } } }
# Match the request harness: actual floors in every pool, and at most one
# page's difference. Ruby can move one embedded Array between size pools.
floors = HeapWindows.floors
heap_ok = floors.each_with_index.all? do |floor, pool|
  values = capacities.map { _1.fetch(pool.to_s) }
  values.min >= floor && values.max - values.min <= GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / GC.stat_heap(pool, :slot_size)
end
aa = %w[total no_gc].to_h do |metric|
  estimate = RequestPairs.estimate(rows.map { 100 * (_1.fetch("loop_b").fetch(metric) / _1.fetch("loop").fetch(metric) - 1) }, seed: 41231)
  lo, hi = estimate.fetch(:ci95)
  [metric, estimate.merge(pass: lo <= 0 && hi >= 0 && lo >= -0.5 && hi <= 0.5)]
end
workers = rows.each_with_index.flat_map { |row, round| row.map { |name, sample| ["#{round}-#{name}", sample.fetch("metadata")] } }.to_h
jit = JitStability.control(workers, requested: ENV.fetch("GUARD_JIT", ENV.fetch("BENCH_JIT", "1")))
File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary: summary, capacities: capacities.uniq, heap_ok: heap_ok, aa: aa, jit: jit))
puts JSON.pretty_generate(summary)
abort "heap, A/A or JIT gate failed" unless heap_ok && aa.values.all? { _1.fetch(:pass) } && jit.fetch(:pass)
