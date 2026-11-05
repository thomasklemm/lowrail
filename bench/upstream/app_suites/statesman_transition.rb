# statesman 13.4.0's ActiveRecord adapter reads the association's join key through
# `join_primary_key`, falling back to the Rails 5.x `join_keys`; Rails main removed both.
# RAILS=/path/to/rails ruby statesman_transition.rb   (PostgreSQL via PG* env)
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |g| $LOAD_PATH.unshift File.join(rails, g, "lib") }
require "active_record"
gem "statesman", "13.4.0"
require "statesman"
Statesman.configure { storage_adapter(Statesman::Adapters::ActiveRecord) }
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :orders, force: true
  create_table :order_transitions, force: true do |t|
    t.string :to_state, null: false
    t.jsonb :metadata, default: {}
    t.integer :sort_key, null: false
    t.references :order, null: false
    t.boolean :most_recent
    t.timestamps
  end
end

class OrderStateMachine
  include Statesman::Machine
  state :pending, initial: true
  state :paid
  transition from: :pending, to: :paid
end

class OrderTransition < ActiveRecord::Base
  belongs_to :order
end

class Order < ActiveRecord::Base
  has_many :order_transitions, autosave: false
  include Statesman::Adapters::ActiveRecordQueries[transition_class: OrderTransition, initial_state: :pending]

  def state_machine
    @state_machine ||= OrderStateMachine.new(self, transition_class: OrderTransition)
  end
end

begin
  order = Order.create!
  order.state_machine.transition_to!(:paid)
  puts "transitioned: #{order.state_machine.current_state}"
rescue => e
  puts "#{e.class}: #{e.message.lines.first}"
  $stderr.puts e.backtrace.first(6) if ENV["BT"]
ensure
  %i[order_transitions orders].each { ActiveRecord::Base.connection.drop_table _1 }
end
