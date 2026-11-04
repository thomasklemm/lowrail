# ruby micro.rb CASE N MODE   (MODE: ir | ns | obj)
require "bundler/setup"
require "action_controller"
require "action_view"
require "active_record"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", prepared_statements: ENV["PREPARED"] != "0")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.references :author; t.string :title; t.string :status }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; end
author = Author.create!(name: "a")
2.times { |i| Post.create!(author: author, title: "t#{i}") }
post = Post.first
post_id = post.id

view = ActionView::Base.empty
require "useragent"
UA = {
  "firefox" => "Mozilla/5.0 (X11; Linux x86_64; rv:132.0) Gecko/20100101 Firefox/132.0",
  "safari" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
}
def blocker(ua, versions)
  env = Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => ua)
  ActionController::AllowBrowser::BrowserBlocker.new(ActionDispatch::Request.new(env), versions: versions)
end
custom = { firefox: 100, chrome: 100 }

CASES = {
  "find" => -> { Post.find(post_id) },
  "belongs_to" => -> { post.association(:author).reset; post.author },
  "has_many" => -> { author.association(:posts).reset; author.posts.to_a },
  "blocked_modern_firefox" => -> { blocker(UA["firefox"], :modern).blocked? },
  "blocked_modern_safari" => -> { blocker(UA["safari"], :modern).blocked? },
  "blocked_custom_firefox" => -> { blocker(UA["firefox"], custom).blocked? },
  "tag_div_block" => -> { view.tag.div { "x" } },
  "content_for" => -> { view.content_for(:x) { "y" }; view.view_flow.set(:x, ActiveSupport::SafeBuffer.new) },
  "capture" => -> { view.capture { "y" } },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 3000).to_i.times { f.() }
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
