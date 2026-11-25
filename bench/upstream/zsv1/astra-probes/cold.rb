depth = Integer(ARGV.fetch(0))
klass = Class.new
100.times { |i| klass.class_eval("def writer#{i}; @a = 7; end") }
obj = klass.new
depth.times { obj.extend(Module.new) }
obj.instance_variable_set(:@a, 0)
100.times { |i| 29.times { obj.public_send("writer#{i}") } }
raise unless obj.instance_variable_get(:@a) == 7
puts 'cold profile value: 7'
