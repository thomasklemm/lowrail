# frozen_string_literal: true

# Bet Z2's compiled-caller micro. Used by jit_hooks.rb via micro_code; the
# same loop supplies the interpreter Callgrind window (second argument).
require "json"
require "digest"
abort "wrong JIT" unless RubyVM::ZJIT.enabled? == (ARGV.fetch(0) == "zjit")

def literal_keywords(a: 13, **kwargs)
  a + kwargs[:left] - kwargs[:right]
end

def hot_loop(n)
  i = 0
  total = 0
  while i < n
    total += literal_keywords(right: 3, a: 17, left: 29)
    i += 1
  end
  total
end

100.times { abort "wrong warmup" unless hot_loop(2_000) == 86_000 }
GC.start
n = ARGV[1] ? Integer(ARGV.fetch(1)) : 2_000_000
if ENV["LOWRAIL_CALLGRIND_EXT"]
  require ENV.fetch("LOWRAIL_CALLGRIND_EXT")
  GC.disable
end
before = RubyVM::ZJIT.stats if RubyVM::ZJIT.enabled? && ENV["Z2_STATS"]
objects = GC.stat(:total_allocated_objects)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
LowrailCallgrindBench.start(false) if defined?(LowrailCallgrindBench)
result = hot_loop(n)
LowrailCallgrindBench.finish if defined?(LowrailCallgrindBench)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
objects = GC.stat(:total_allocated_objects) - objects
after = RubyVM::ZJIT.stats if before
abort "wrong result" unless result == 43 * n
puts JSON.generate(wall_seconds: elapsed, objects: objects, result: result,
  jit: RubyVM::ZJIT.enabled?, binary_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
  ruby: RUBY_DESCRIPTION,
  jit_delta: before && after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] })
