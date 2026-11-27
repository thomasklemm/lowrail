require "cancancan"

class Product; end
class Order; end

class Ability
  include CanCan::Ability

  def initialize(user)
    can :read, Product
    can [:read, :update], Order, user_id: user
    cannot :destroy, Order
    can :update, Order, [:name, :email], user_id: user
    can(:show, Order) { |order| order }
  end
end

before = GC.stat(:total_allocated_objects)
1_000.times { Ability.new(1) }
puts (GC.stat(:total_allocated_objects) - before) / 1_000
