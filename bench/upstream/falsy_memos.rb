# frozen_string_literal: true

# ruby falsy_memos.rb /path/to/rails
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each do |component|
  $LOAD_PATH.unshift File.join(rails, component, "lib")
end
require "active_record"

model = Class.new(ActiveRecord::Base)
puts "getter: #{model.method(:connection_class).source_location.join(':')}"
puts "initially defined: #{model.instance_variable_defined?(:@connection_class)}"
puts "read: #{model.connection_class.inspect}"
puts "defined after read: #{model.instance_variable_defined?(:@connection_class)}"

model.connection_class = nil
puts "nil setter, then read: #{model.connection_class.inspect}"
puts "raw flag after read: #{model.instance_variable_get(:@connection_class).inspect}"

model.connection_class = false
# Freeze the class object itself, without Active Support's metadata freeze hook.
Object.instance_method(:freeze).bind_call(model)
begin
  puts "frozen false read: #{model.connection_class.inspect}"
rescue FrozenError => error
  puts "frozen false read: #{error.class}"
end

class KeywordReader
  def read(*args, **keywords, &block)
    [args, keywords, block&.call]
  end
end

class RestReader < KeywordReader
  def read(*)
    super
  end
end

class ForwardingReader < KeywordReader
  def read(...)
    super
  end
end

puts "rest forwarding: #{RestReader.new.read(:name, locale: :en) { :block }.inspect}"
puts "ellipsis forwarding: #{ForwardingReader.new.read(:name, locale: :en) { :block }.inspect}"

value = Object.new
def value.tap
  yield self
  :custom_tap_result
end
puts "replaceable tap result: #{value.tap { }.inspect}; explicit local would return value: #{value.inspect}"
