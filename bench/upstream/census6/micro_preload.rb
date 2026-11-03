require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title }
  create_table(:comments) { |t| t.integer :post_id; t.integer :author_id }
  create_table(:tags) { |t| t.integer :post_id }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; has_many :tags; end
class Comment < ActiveRecord::Base; belongs_to :post; belongs_to :author; end
class Tag < ActiveRecord::Base; belongs_to :post; end
a = Author.create!(name: "a")
3.times { p = a.posts.create!(title: "t"); 2.times { p.comments.create!(author: a) }; p.tags.create! }
CASES = {
  "Post.preload(:author)" => -> { Post.preload(:author).to_a },
  "Author.preload(posts: :comments)" => -> { Author.preload(posts: :comments).to_a },
  "Post.preload(:author, :tags, comments: :author)" => -> { Post.preload(:author, :tags, comments: :author).to_a },
}
puts RUBY_DESCRIPTION
CASES.each do |label, fn|
  10.times { fn.() }
  GC.disable; b = GC.stat(:total_allocated_objects); 200.times { fn.() }; objs = (GC.stat(:total_allocated_objects) - b) / 200.0; GC.enable
  n = 3000
  us = 3.times.map { t = Process.clock_gettime(Process::CLOCK_MONOTONIC); n.times { fn.() }; (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / n * 1e6 }.min
  puts format("%-50s %7.1f objects %7.1f us", label, objs, us)
end
