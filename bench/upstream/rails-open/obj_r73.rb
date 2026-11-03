require "bundler/setup"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author }
  create_table(:comments) { |t| t.references :post }
end
class Author < ActiveRecord::Base; end
class Post < ActiveRecord::Base; belongs_to :author; end
class FK < String; def to_ary = ["post_id"]; end
class Comment < ActiveRecord::Base
  belongs_to :post
  has_one :post_author, through: :post, source: :author
end
class Comment2 < ActiveRecord::Base
  self.table_name = "comments"
  belongs_to :post, foreign_key: FK.new("post_id")
  has_one :post_author, through: :post, source: :author
end
c = Comment.find(Comment.create!(post: Post.create!(author: Author.create!)).id); c.post_author
3.times { 2000.times { c.post_author } }
GC.disable; b = GC.stat(:total_allocated_objects); 2000.times { c.post_author }
puts "objects per loaded read: #{(GC.stat(:total_allocated_objects) - b) / 2000.0}"; GC.enable
c2 = Comment2.find(c.id)
fk = Comment2.reflect_on_association(:post).foreign_key
puts "subclass fk: #{fk.class} -> state #{c2.association(:post_author).send(:stale_state).inspect}"
