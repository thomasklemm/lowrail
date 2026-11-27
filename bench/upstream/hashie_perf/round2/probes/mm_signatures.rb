# frozen_string_literal: true

# Objects per call for the candidate signature, by argument count: ruby [--yjit|--zjit] mm_signatures.rb
class B
  def method_missing(name, value = nil, *, &blk) = value
  def direct(name, value = nil, *, &blk) = value
  def noblk(name, value = nil, *) = value
  def req(name, value, *) = value
end
o = B.new
def count; 3000.times { yield }; GC.disable; b = GC.stat(:total_allocated_objects); 1000.times { yield }; c1 = GC.stat(:total_allocated_objects) - b; b = GC.stat(:total_allocated_objects); 2000.times { yield }; c2 = GC.stat(:total_allocated_objects) - b; GC.enable; (c2 - c1) / 1000.0; end
puts RUBY_DESCRIPTION
{ 'mm o.foo' => -> { o.foo }, 'mm o.foo = 1' => -> { o.foo = 1 }, 'direct(:a)' => -> { o.direct(:a) }, 'direct(:a, 1)' => -> { o.direct(:a, 1) },
  'noblk(:a, 1)' => -> { o.noblk(:a, 1) }, 'req(:a, 1)' => -> { o.req(:a, 1) }, 'direct(:a, 1, 2)' => -> { o.direct(:a, 1, 2) } }.each { |k, v| puts "#{k}: #{count(&v)}" }
class A
  def method_missing(name, *args, &blk) = args.first
  def direct(name, *args, &blk) = args.first
end
a = A.new
{ '*args: mm a.foo' => -> { a.foo }, '*args: mm a.foo = 1' => -> { a.foo = 1 }, '*args: direct(:a, 1)' => -> { a.direct(:a, 1) } }.each { |k, v| puts "#{k}: #{count(&v)}" }
