# The private ActiveModel::Validations#validation_context= writer, which Rails main removed
# (0f9d127083): ancestry 5.1.0 calls it when a node moves, OpenProject's ModelContract on every
# contract validation. RAILS=/path/to/rails ruby validation_context_writer.rb (PostgreSQL via PG* env)
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |g| $LOAD_PATH.unshift File.join(rails, g, "lib") }
require "active_record"
gem "ancestry", "5.1.0"
require "ancestry"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :nodes, force: true do |t|
    t.string :name
    t.string :ancestry, collation: "C"
  end
end

class Node < ActiveRecord::Base
  has_ancestry
end

begin
  a = Node.create!(name: "a")
  b = Node.create!(name: "b")
  c = Node.create!(name: "c", parent: a)
  Node.create!(name: "d", parent: c)
  c.update!(parent: b)
  puts "moved: #{Node.find_by(name: "d").ancestors.map(&:name).inspect}"
rescue => e
  puts "#{e.class}: #{e.message.lines.first}"
ensure
  ActiveRecord::Base.connection.drop_table :nodes
end
