def a(*args) = yield(*args)
def b(*) = yield(*)
def m(n, &f) = (GC.disable; x = GC.stat(:total_allocated_objects); n.times(&f); (GC.stat(:total_allocated_objects) - x).fdiv(n))
2000.times { a { 1 }; b { 1 } }
puts "#{RUBY_VERSION} #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'yjit' : ''}#{defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? 'zjit' : ''}: args #{m(1000) { a { 1 } }} anon #{m(1000) { b { 1 } }}"
