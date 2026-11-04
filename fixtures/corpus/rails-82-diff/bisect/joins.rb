require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.integer :author_id }; create_table(:authors); create_table(:comments) { |t| t.integer :post_id } }
class Author < ActiveRecord::Base; end
class Comment < ActiveRecord::Base; belongs_to :post; end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; end
sql = Post.includes([:author, :comments]).references([:author, :comments]).left_joins([:author, :comments]).to_sql
puts sql.include?('"authors_posts"."id" AS') ? "OLD" : "NEW"
