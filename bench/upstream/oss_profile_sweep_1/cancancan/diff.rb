# diff.rb CANCAN_DIR: the rules and index that many can/cannot shapes build, printed for diffing two trees.
$LOAD_PATH.unshift File.join(ARGV[0], "lib")
require "cancan"
class Product; end
class Order; end
SHAPES = [
  [:read, Product], [[:read, :update], Order], ["read", Product], [:manage, :all], [nil, nil],
  [:read, [Product, Order]], [:read, [Product, nil]], [:read, [nil]], [:update, Order, [:name, :email]],
  [:update, Order, :name], [:update, Order, "name"], [:update, Order, [:name], { user_id: 1 }],
  [:update, Order, { user_id: 1 }], [:update, Order, user_id: 1], [:read, Order, nil], [:read, Order, []],
  [:read, Order, [:name], nil], [:read, Order, "sql", ["sql"]], [:read, :dashboard], [:read, "string_subject"]
]
SHAPES.each_with_index do |args, i|
  [true, false].each do |can|
    [false, true].each do |with_block|
      ability = Object.new.extend(CanCan::Ability)
      begin
        blk = with_block ? proc { |*| true } : nil
        can ? ability.can(*args, &blk) : ability.cannot(*args, &blk)
        r = ability.send(:rules).last
        index = ability.instance_variable_get(:@rules_index)
        puts [i, can, with_block, r.actions, r.subjects, r.attributes, r.conditions, !r.block.nil?, r.instance_variable_get(:@match_all), index].inspect
      rescue => e
        puts [i, can, with_block, e.class, e.message].inspect
      end
    end
  end
end
