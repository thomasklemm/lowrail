# Per-call CPU and objects for open Rails perf PRs: ruby cpu_open.rb CASE N MODE
# MODE ir:  the N calls run inside Array#cycle, for Callgrind's --toggle-collect=rb_ary_cycle, GC disabled.
# MODE ns:  prints ns per call over N calls (GC disabled), for interleaved wall time.
# MODE obj: prints objects allocated per call over N calls.
require "bundler/setup"
require "active_support"
require "active_support/core_ext/enumerable"
require "action_view"
require "action_view/testing/resolvers"
require "active_record"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title; t.string :body }
  create_table(:comments) { |t| t.references :post; t.references :author; t.string :body }
end
class Author < ActiveRecord::Base; end
class Comment < ActiveRecord::Base; belongs_to :post; belongs_to :author; end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  has_many :commenters, through: :comments, source: :author
end
authors = 3.times.map { |i| Author.create!(name: "a#{i}") }
3.times do |i|
  post = Post.create!(author: authors[i], title: "t#{i}", body: "b")
  2.times { |j| Comment.create!(post: post, author: authors[j], body: "c") }
end
post = Post.first
post_record = Post.find(post.id)
hm = post.association(:comments)
hmt = post.association(:commenters)

def strings(n) = Array.new(n) { |i| -"column_#{i}" }
A3, A8, A50, A6 = strings(3), strings(8), strings(50), strings(6)

buffer = ActionView::OutputBuffer.new
unsafe = +"Tom & Jerry <b>"
plain = +"Tom and Jerry"
safe = "<b>bold</b>".html_safe
resolver = ActionView::FixtureResolver.new(
  "cards/_card.html.erb" => %(<div class="card"><h2><%= title %></h2><p><%= body %></p></div>\n)
)
view = ActionView::Base.with_empty_template_cache.with_view_paths([resolver])
locals = { title: "Tom & Jerry", body: "Fish <and> chips" }

CASES = {
  "iw_3" => -> { A3.index_with { |c| c } },
  "iw_8" => -> { A8.index_with { |c| c } },
  "iw_50" => -> { A50.index_with { |c| c } },
  "iw_default_6" => -> { A6.index_with(nil) },
  "serializable_hash" => -> { post_record.serializable_hash },
  "ob_unsafe" => -> { buffer << unsafe },
  "ob_unsafe_plain" => -> { buffer << plain },
  "ob_safe" => -> { buffer << safe },
  "ob_render" => -> { view.render(partial: "cards/card", locals: locals) },
  "preload_hm" => -> { Post.preload(:comments).to_a },
  "preload_hmt" => -> { Post.preload(:commenters).to_a },
  "scope_hm" => -> { hm.reset_scope; hm.scope },
  "scope_hmt" => -> { hmt.reset_scope; hmt.scope },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
buffer = ActionView::OutputBuffer.new if CASE.start_with?("ob_")
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "ns"
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N).round(2)
end
