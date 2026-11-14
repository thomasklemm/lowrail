# #59141 generates aliases declared on abstract classes per concrete model, and only where the target exists.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:comments) { |t| t.string :body } }
class ApplicationRecord < ActiveRecord::Base; self.abstract_class = true; alias_attribute :name, :title; end
class Comment < ApplicationRecord; end
c = Comment.new(body: "b")
p respond_to: c.respond_to?(:name)
begin
  p name: c.name
rescue => e
  puts "name: #{e.class}: #{e.message.lines.first.strip}"
end
# The same alias declared on the concrete model itself.
class Note < ActiveRecord::Base; self.table_name = "comments"; alias_attribute :name, :title; end
begin
  n = Note.new(body: "b"); p note_respond_to: n.respond_to?(:name), note_name: n.name
rescue => e
  puts "Note#name: #{e.class}: #{e.message.lines.first.strip}"
end
