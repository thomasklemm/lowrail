# frozen_string_literal: true

# HM3's reviewers' repro (a keyword-flagged Hash reaching method_missing through SimpleDelegator) and the objects a
# method read and a setter allocate. Usage: ruby -I HASHIE/lib mm_anonymous_rest.rb
require 'hashie'
require 'delegate'

def receive(*positional, **keywords) = [positional, keywords]

def objects
  GC.disable
  before = GC.stat(:total_allocated_objects)
  yield
  GC.stat(:total_allocated_objects) - before
ensure
  GC.enable
end

value = SimpleDelegator.new(Hashie::Mash.new).public_send(:item=, a: 13)
puts "delegated setter then receive(*[value]): #{receive(*[value]).inspect}"
mash = Hashie::Mash.new(name: 'a')
mash.name
mash.other = 1
puts "5 reads: #{objects { 5.times { mash.name } }} objects; 5 setters: #{objects { 5.times { mash.other = 1 } }} objects"
puts "no argument: #{mash.public_send(:x=).inspect}; two arguments: #{mash.public_send(:y=, 1, 2).inspect}"
