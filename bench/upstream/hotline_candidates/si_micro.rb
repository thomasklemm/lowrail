# ruby si_micro.rb CR_TREE N CASE -> objects per call; run under callgrind for Ir (N=0 vs N)
$LOAD_PATH.unshift File.join(ARGV[0], "lib/concurrent-ruby")
require "concurrent"
n = Integer(ARGV[1])
Klass = Class.new(Concurrent::Synchronization::Object) { safe_initialization!; def initialize(a, b); super(); @a = a; @b = b; end }
cases = {
  "atomic_boolean" => -> { Concurrent::AtomicBoolean.new(false) },
  "atomic_reference" => -> { Concurrent::AtomicReference.new(nil) },
  "two_args" => -> { Klass.new(1, 2) },
  "resolvable_future" => -> { Concurrent::Promises.resolvable_future },
}
blk = cases.fetch(ARGV[2])
1000.times { blk.call }
GC.start
a = GC.stat(:total_allocated_objects)
i = 0
while i < n
  blk.call
  i += 1
end
b = GC.stat(:total_allocated_objects)
warn "#{ARGV[2]} #{Concurrent::AtomicBoolean.ancestors[1]} objects/call #{n.zero? ? 0 : (b - a).fdiv(n)}"
