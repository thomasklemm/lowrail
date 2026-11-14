require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :n } }
class Post < ActiveRecord::Base; end
p Post.create!(title: "a", n: 1).reload.title
