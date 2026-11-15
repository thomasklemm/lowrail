require "active_support/ordered_options"
o = ActiveSupport::OrderedOptions.new
o[:_get] = "v"; o.a = 1
io = ActiveSupport::InheritableOptions.new(o)
def t; yield.inspect; rescue => e; "#{e.class}: #{e.message[0, 60]}"; end
puts "o._get           #{t { o._get }}"
puts "o._get(:a)       #{t { o._get(:a) }}"
puts "o._get('a')      #{t { o._get("a") }}"
puts "io._get(:a)      #{t { io._get(:a) }}"
puts "io.a / io[:a]    #{t { [io.a, io[:a], io["a"], io.fetch(:a), io.dig(:a)] }}"
puts "respond_to?      #{t { [o.respond_to?(:_get), o.public_methods.include?(:_get)] }}"
puts "Hash#_get        #{t { {}.respond_to?(:_get) }}"
