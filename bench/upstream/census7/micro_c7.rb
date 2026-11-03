# Census 7 per-call micro: objects (GC counter) and time for order and where calls.
# Run with -I for each Rails component's lib (activerecord, activemodel, activesupport).
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.timestamps }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; end
a = Author.create!(name: "a")
3.times { a.posts.create!(title: "t") }
CASES = {
  "Post.order(:id).to_a" => -> { Post.order(:id).to_a },
  "Post.order(created_at: :desc).to_a" => -> { Post.order(created_at: :desc).to_a },
  "Post.order(\"posts.title\").to_a" => -> { Post.order("posts.title").to_a },
  "Post.where(id: 1).to_a" => -> { Post.where(id: 1).to_a },
  "Post.where(id: 1, title: \"t\").to_a" => -> { Post.where(id: 1, title: "t").to_a },
  "author.posts.to_a" => -> { a.posts.reset; a.posts.to_a },
  "author.posts.order(:id).to_a" => -> { a.posts.reset; a.posts.order(:id).to_a },
}
puts RUBY_DESCRIPTION
CASES.each do |label, fn|
  20.times { fn.() }
  GC.disable; b = GC.stat(:total_allocated_objects); 200.times { fn.() }; objs = (GC.stat(:total_allocated_objects) - b) / 200.0; GC.enable
  n = 3000
  us = 5.times.map { t = Process.clock_gettime(Process::CLOCK_MONOTONIC); n.times { fn.() }; (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) / n * 1e6 }.min
  puts format("%-40s %7.1f objects %7.2f us", label, objs, us)
end
