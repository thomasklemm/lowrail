module ExhaustWrite
  def write(v) = (@astra_after_exhaustion = v)
end
klass = Class.new
objects = 100.times.map { klass.new.extend(ExhaustWrite) }
RubyVM::Shape.exhaust_shapes
objects.each_with_index { |o, i| raise unless o.write(i) == i }
raise unless objects.all? { |o| RubyVM::Shape.of(o).complex? }
raise unless objects.sum { |o| o.instance_variable_get(:@astra_after_exhaustion) } == 4950
puts 'exhausted shapes: 100 complex objects, sum=4950'
