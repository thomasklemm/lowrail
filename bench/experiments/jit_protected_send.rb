# frozen_string_literal: true

# Z3: the protected Hash#[] alias used by Rails' InheritableOptions default
# block. No app changes. The optional count also supplies the interpreter Ir
# window; the fixed startup-entropy shim is for that disposable control only.
require "json"
require "digest"
mode = ARGV.fetch(0)
abort "wrong ZJIT" unless RubyVM::ZJIT.enabled? == (mode == "zjit")
abort "wrong YJIT" unless RubyVM::YJIT.enabled? == (mode == "yjit")

class ProtectedOptions < Hash
  alias_method :_get, :[]
  protected :_get

  def initialize(parent = nil)
    super() { |_hash, key| parent._get(key) }
  end
end
PARENT_OPTIONS = ProtectedOptions.new
PARENT_OPTIONS[:left] = 29
PARENT_OPTIONS[:right] = 3
OPTIONS = ProtectedOptions.new(PARENT_OPTIONS)

def hot_loop(n)
  i = total = 0
  while i < n
    total += OPTIONS[:left] - OPTIONS[:right]
    i += 1
  end
  total
end

100.times { abort "wrong warmup" unless hot_loop(2_000) == 52_000 }
GC.start
n = ARGV[1] ? Integer(ARGV.fetch(1)) : 2_000_000
if ENV["LOWRAIL_CALLGRIND_EXT"]
  require ENV.fetch("LOWRAIL_CALLGRIND_EXT")
  GC.disable
end
before = RubyVM::ZJIT.stats if mode == "zjit" && ENV["Z3_STATS"]
objects = GC.stat(:total_allocated_objects)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
LowrailCallgrindBench.start(false) if defined?(LowrailCallgrindBench)
result = hot_loop(n)
LowrailCallgrindBench.finish if defined?(LowrailCallgrindBench)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
objects = GC.stat(:total_allocated_objects) - objects
after = RubyVM::ZJIT.stats if before
abort "wrong result" unless result == 26 * n
puts JSON.generate(wall_seconds: elapsed, objects: objects, result: result,
  jit: mode, binary_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
  ruby: RUBY_DESCRIPTION,
  jit_delta: before && after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] })
