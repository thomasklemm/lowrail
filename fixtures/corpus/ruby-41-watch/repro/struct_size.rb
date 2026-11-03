require "objspace"
puts (1..8).map { |n| s = Struct.new(*(1..n).map { :"m#{_1}" }); "#{n}:#{ObjectSpace.memsize_of(s.new(*Array.new(n, 1)))}" }.join(" ") +
  "  Data(3):#{ObjectSpace.memsize_of(Data.define(:a, :b, :c).new(a: 1, b: 2, c: 3))}"
