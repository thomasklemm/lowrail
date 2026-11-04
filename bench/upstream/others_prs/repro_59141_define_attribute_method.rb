require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base
  define_attribute_method :nickname # what activerecord-typedstore 1.6.0 does for each store accessor
end
Post.create!(title: "a")
p Post.first.title
