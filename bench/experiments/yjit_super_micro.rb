# frozen_string_literal: true

# Y2: model Rails' singleton-prepended ERB escaping wrapper around a C method.
# Census/timing and Callgrind use the same workload, but separate processes.
require "json"
require "digest"
require "cgi/escape"

mode = ARGV.fetch(0)
abort "wrong YJIT" unless RubyVM::YJIT.enabled? == (mode == "yjit")
abort "wrong ZJIT" unless RubyVM::ZJIT.enabled? == (mode == "zjit")

module EscapeWrapper
  def escapeHTML(string)
    super(string)
  end
end
CGI.singleton_class.prepend(EscapeWrapper)
SOURCE = "<a&b>"
abort "wrong escape" unless CGI.escapeHTML(SOURCE) == "&lt;a&amp;b&gt;"

def hot_loop(n)
  i = total = 0
  while i < n
    total += CGI.escapeHTML(SOURCE).bytesize
    i += 1
  end
  total
end

100.times { abort "wrong warmup" unless hot_loop(2_000) == 30_000 }
GC.start
n = ARGV[1] ? Integer(ARGV.fetch(1)) : 2_000_000
if ENV["LOWRAIL_CALLGRIND_EXT"]
  require ENV.fetch("LOWRAIL_CALLGRIND_EXT")
  GC.disable
end
snapshot = -> {
  if mode == "yjit"
    RubyVM::YJIT.runtime_stats
  elsif mode == "zjit"
    RubyVM::ZJIT.stats
  end&.select { |_, value| value.is_a?(Numeric) }
}
before = snapshot.call if ENV["Y2_STATS"]
objects = GC.stat(:total_allocated_objects)
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
LowrailCallgrindBench.start(false) if defined?(LowrailCallgrindBench)
result = hot_loop(n)
LowrailCallgrindBench.finish if defined?(LowrailCallgrindBench)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
objects = GC.stat(:total_allocated_objects) - objects
after = snapshot.call if before
abort "wrong result" unless result == 15 * n
puts JSON.generate(wall_seconds: elapsed, objects: objects, result: result,
  jit: mode, binary_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
  ruby: RUBY_DESCRIPTION,
  jit_delta: before && after.to_h { |key, value| [key, value - before.fetch(key, 0)] })
