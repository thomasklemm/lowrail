# CC1: an ability with six rules built per request, the shape Solidus and openstreetmap-website build in
# current_ability (a class rule, an action list with conditions, a cannot, attributes with conditions, a block rule).
require "cancancan"

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
    can(:show, Order) { |order| order }
  end
end

UpstreamBench.report("Ability.new(user)") { Ability.new(1) }
