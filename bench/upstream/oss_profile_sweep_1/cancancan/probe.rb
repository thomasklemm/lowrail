# probe.rb CANCAN_DIR: objects per rule definition, by line, for the cancancan tree given.
$LOAD_PATH.unshift File.join(ARGV[0], "lib")
require "cancan"
require "objspace"
class Product; end
class Order; end
class Ability
  include CanCan::Ability
  def initialize(user)
    can :read, Product
    can [:read, :update], Order, user_id: user
    can :manage, :all if user == 0
    cannot :destroy, Order
    can :update, Order, [:name, :email], user_id: user
    can(:show, Order) { |o| o }
  end
end
3.times { Ability.new(1) }
GC.start; GC.disable
n = 1000
before = GC.stat(:total_allocated_objects)
n.times { Ability.new(1) }
per = (GC.stat(:total_allocated_objects) - before).fdiv(n)
ObjectSpace.trace_object_allocations_start
Ability.new(1)
ObjectSpace.trace_object_allocations_stop
lines = Hash.new(0)
ObjectSpace.each_object { |o| f = ObjectSpace.allocation_sourcefile(o); lines["#{f.sub(ARGV[0] + "/", "")}:#{ObjectSpace.allocation_sourceline(o)}"] += 1 if f }
puts "#{RUBY_VERSION}: #{per} objects per Ability.new (5 rules + 1 block rule)"
lines.sort_by { -_2 }.first(14).each { puts "  #{_2}  #{_1}" }
