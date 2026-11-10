class Parent; def self.foo(x) = x + 1; end
n = Integer(ARGV[0])
GC.start
before = ObjectSpace.count_objects[:T_CLASS]
n.times { |i| c = Class.new(Parent); c.singleton_class.class_eval("def baz(x) = x + #{i}; def foo(x) = baz(x) + 1"); 3.times { c.foo(i) } }
4.times { GC.start }
s = RubyVM::YJIT.runtime_stats
warn "retained_classes=#{ObjectSpace.count_objects[:T_CLASS] - before} isc=#{s[:invokesuper_singleton_class]} rss_kb=#{File.read('/proc/self/status')[/VmRSS:\s+(\d+)/,1]} code_gc=#{s[:code_gc_count]} cr=#{s[:code_region_size]}"
