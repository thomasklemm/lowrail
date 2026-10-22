# frozen_string_literal: true

# One fresh process per arm. The orchestrator balances A/B/draft order.
require "json"
require "digest"
root, output = ARGV
root = File.expand_path(root)
$LOAD_PATH.unshift "#{root}/activesupport/lib"
require "active_support"
require "active_support/cache"

coder = ActiveSupport::Cache::Coder.new(Marshal, Zlib)
plain = coder.dump(ActiveSupport::Cache::Entry.new("héllo-37"))
version = "v-37".b
versioned = coder.dump(ActiveSupport::Cache::Entry.new("héllo-37", version: version))
compressed = coder.dump_compressed(ActiveSupport::Cache::Entry.new(["x" * 1000, { a: [1, 37] }]), 1)
legacy = Marshal.dump(ActiveSupport::Cache::Entry.new("legacy"))
cases = {
  plain: -> { coder.load(plain).value },
  binary_version: -> { entry = coder.load(versioned); entry.value unless entry.mismatched?(version) },
  compressed: -> { coder.load(compressed).value },
  legacy_control: -> { coder.load(legacy).value }
}
expected = ["héllo-37", "héllo-37", ["x" * 1000, { a: [1, 37] }], "legacy"]
raise "decoded values differ" unless cases.values.map(&:call) == expected

def jit_stats
  if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats
  elsif defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats
  else
    {}
  end
end

results = cases.map do |name, operation|
  warmup = 30_000
  count = 200_000
  warmup.times { operation.call }
  GC.start
  before = GC.stat(:total_allocated_objects)
  5_000.times { operation.call }
  allocations = (GC.stat(:total_allocated_objects) - before).fdiv(5_000)
  stats_before = jit_stats
  start = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
  count.times { operation.call }
  seconds = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - start
  stats_after = jit_stats
  delta = stats_after.to_h.filter_map do |key, value|
    next unless value.is_a?(Numeric) && stats_before[key].is_a?(Numeric)
    [key, value - stats_before[key]] if key.to_s.match?(/compil|invalid|code_gc/)
  end.to_h
  { case: name, objects: allocations, seconds: seconds, operations: count, jit_delta: delta }
end
source = "activesupport/lib/active_support/cache/coder.rb"
File.write(output, JSON.pretty_generate({ ruby: RUBY_DESCRIPTION,
  yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?,
  zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?,
  source_sha256: Digest::SHA256.file("#{root}/#{source}").hexdigest,
  warmup: 30_000, allocation_operations: 5_000, results: results }) + "\n")
