# Per-call CPU for the R7 candidates: ruby cpu_r7.rb CASE N [MODE]
# MODE ir: the N calls run inside Array#cycle, for Callgrind's --toggle-collect=rb_ary_cycle, with GC disabled.
# MODE ns: prints ns per call over N calls (GC disabled), for interleaved wall time.
require "bundler/setup"
require "action_view"
require "active_record"
require "active_support/core_ext/object/json"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title; t.string :status }
  create_table(:comments) { |t| t.references :post; t.string :body }
end
class Author < ActiveRecord::Base; end
class Post < ActiveRecord::Base; belongs_to :author; end
class Comment < ActiveRecord::Base
  belongs_to :post
  has_one :post_author, through: :post, source: :author
end
comment = Comment.create!(post: Post.create!(author: Author.create!(name: "a"), title: "t"), body: "b")
comment = Comment.find(comment.id)
comment.post_author
post = Post.new(status: "In progress")

view = ActionView::Base.empty
attrs = { id: 1, name: "David", email: "d@example.com", created_at: nil }
classes = ["btn", "btn-primary"]

CASES = {
  "tag_div_class_array" => -> { view.tag.div(class: classes) },
  "class_names_hash" => -> { view.class_names("btn", active: true) },
  "tag_div_aria_array" => -> { view.tag.div(aria: { describedby: classes }) },
  "hash_as_json" => -> { attrs.as_json },
  "render_json_hash" => -> { ActiveSupport::JSON.encode(attrs) },
  "to_json_except" => -> { attrs.to_json(except: :created_at) },
  "through_read" => -> { comment.post_author },
  "radio_button" => -> { view.radio_button(:post, :status, "In progress", object: post) },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start
GC.disable
if MODE == "ir"
  [0].cycle(1) { N.times { f.() } }
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
