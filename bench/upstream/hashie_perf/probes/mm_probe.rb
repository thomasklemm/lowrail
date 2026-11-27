class A; def method_missing(n, *args, &b) = 1; def respond_to_missing?(*) = true; end
class B; def method_missing(n, &b) = 1; def respond_to_missing?(*) = true; end
class C; def method_missing(n, ...) = 1; def respond_to_missing?(*) = true; end
class D; def method_missing(n, a = nil, *rest, &b) = 1; def respond_to_missing?(*) = true; end
[A, B, C, D].each do |k|
  o = k.new; 100.times { o.foo }
  x = GC.stat(:total_allocated_objects); 1000.times { o.foo }; y = GC.stat(:total_allocated_objects)
  x2 = GC.stat(:total_allocated_objects); 1000.times { (o.foo(1) rescue nil) }; y2 = GC.stat(:total_allocated_objects)
  puts "#{k} #{RUBY_VERSION} no-arg #{(y - x) / 1000.0} one-arg #{(y2 - x2) / 1000.0}"
end
