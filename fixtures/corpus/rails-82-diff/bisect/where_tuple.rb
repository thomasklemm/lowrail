require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :views } }
class Post < ActiveRecord::Base; end
puts Post.where([:views, :title] => []).to_sql.include?("1=0") ? "NEW" : "OLD"
