require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:users) { |t| t.string :name } }
class User < ActiveRecord::Base; end
User.create!(name: "a")
Match = Struct.new(:v)
r = {}
r[:pb_frozen] = User.predicate_builder.frozen?
r[:table_frozen] = User.predicate_builder.send(:table).frozen?
begin
  User.predicate_builder.register_handler(Match, proc { |col, m| col.matches("%#{m.v}%") })
  r[:register_handler] = User.where(name: Match.new("a")).count
rescue => e
  r[:register_handler] = "#{e.class}: #{e.message[0,60]}"
end
begin
  User.predicate_builder.send(:table).instance_variable_set(:@memo, true)
  r[:table_memo] = :ok
rescue => e
  r[:table_memo] = e.class
end
p r
