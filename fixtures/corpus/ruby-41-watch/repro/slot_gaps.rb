require "objspace"
klasses = (1..50).map { |n| c = Class.new { define_method(:initialize) { n.times { |i| instance_variable_set(:"@i#{i}", i) } } }; 3.times { c.new }; [n, c] }
row = klasses.select { |n, _| [3, 5, 8, 10, 14, 18, 22, 26, 30, 31, 34, 38, 40, 46, 50].include?(n) }.map { |n, c| "#{n}:#{ObjectSpace.memsize_of(c.new)}" }
puts "ivars:memsize  " + row.join(" ")
puts "str len:memsize " + [0, 20, 23, 30, 50, 60, 100, 120, 140, 200, 230, 250, 300, 480, 600].map { |l| "#{l}:#{ObjectSpace.memsize_of(String.new("x" * l))}" }.join(" ")
puts "ary len:memsize " + [1, 3, 5, 8, 10, 16, 20, 30, 40, 60].map { |l| "#{l}:#{ObjectSpace.memsize_of(Array.new(l, 1))}" }.join(" ")
