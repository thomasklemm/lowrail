require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :score } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", score: 1)

post = Post.select(:score, :title).first
p post.attributes.keys
puts post.to_json
p Post.select("title AS name, id").first.attributes.keys
