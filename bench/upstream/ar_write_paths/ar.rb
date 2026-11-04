# ruby ar.rb CASE N MODE   (MODE: ir | ns | obj | sites)
require "bundler/setup"
require "active_record"
require "objspace"

CASE, N, MODE = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
ActiveSupport.event_reporter.debug_mode = false unless ENV["DEBUG_EVENTS"]

if ENV["DB"] == "pg"
  dbname = "arbench_#{Process.pid}"
  system("psql", "-q", "-h", "/tmp", "-U", "postgres", "-c", "create database #{dbname}", exception: true)
  at_exit { system("psql", "-q", "-h", "/tmp", "-U", "postgres", "-c", "drop database if exists #{dbname} with (force)") }
  ActiveRecord::Base.establish_connection(adapter: "postgresql", host: "/tmp", username: "postgres", database: dbname, prepared_statements: ENV["PREPARED"] != "0", min_messages: "warning")
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", prepared_statements: ENV["PREPARED"] != "0", **(ENV["TZCFG"] ? { default_timezone: ENV["TZCFG"] } : {}))
end
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  %w[taggings tags comments posts authors].each { |t| drop_table(t, if_exists: true) }
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) do |t|
    t.references :author; t.string :title; t.string :status; t.text :body
    t.integer :views, default: 0; t.boolean :published, default: false; t.timestamps
  end
  create_table(:comments) { |t| t.references :post; t.string :body; t.timestamps }
  create_table(:tags) { |t| t.string :name }
  create_table(:taggings) { |t| t.references :post; t.references :tag }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  has_many :taggings
  has_many :tags, through: :taggings
  before_save { self.status ||= "draft" }
  after_commit { }
end
class Comment < ActiveRecord::Base; belongs_to :post; end
class VPost < ActiveRecord::Base
  self.table_name = "posts"
  belongs_to :author
  validates :title, presence: true, length: { maximum: 100 }
  validates :views, numericality: true
end
class TComment < ActiveRecord::Base
  self.table_name = "comments"
  belongs_to :post, touch: true
end
class Tag < ActiveRecord::Base; end
class Tagging < ActiveRecord::Base; belongs_to :post; belongs_to :tag; end

author = Author.create!(name: "a")
tags = 3.times.map { |i| Tag.create!(name: "t#{i}") }
20.times do |i|
  p = Post.create!(author: author, title: "t#{i}", body: "b" * 50, views: i)
  2.times { |j| Comment.create!(post: p, body: "c#{j}") }
  tags.each { |t| Tagging.create!(post: p, tag: t) }
end
post = Post.first
post_id = post.id
ids = Post.limit(5).pluck(:id)
created = []
vpost = VPost.find(post_id)
tcomment = TComment.first
rows10 = 10.times.map { |i| { post_id: post_id, body: "i#{i}" } }
tagrows = Tag.all.map { |t| { id: t.id, name: t.name } }

CASES = {
  "find" => -> { Post.find(post_id) },
  "find_by" => -> { Post.find_by(title: "t3") },
  "where_to_a" => -> { Post.where(author_id: author.id).limit(5).to_a },
  "where_in" => -> { Post.where(id: ids).to_a },
  "order_limit" => -> { Post.order(:id).limit(10).to_a },
  "order_desc" => -> { Post.order(created_at: :desc).limit(10).to_a },
  "select_cols" => -> { Post.select(:id, :title).limit(10).to_a },
  "load20" => -> { Post.all.to_a },
  "read_attr" => -> { post.title; post.views; post.published; post.created_at },
  "write_attr" => -> { post.title = "x"; post.views = 3; post.restore_attributes },
  "belongs_to" => -> { post.association(:author).reset; post.author },
  "has_many" => -> { author.association(:posts).reset; author.posts.to_a },
  "through" => -> { post.association(:tags).reset; post.association(:taggings).reset; post.tags.to_a },
  "assoc_where" => -> { post.comments.where(body: "c1").to_a },
  "preload" => -> { Post.preload(:author).limit(10).to_a },
  "includes_many" => -> { Post.includes(:comments).limit(10).to_a },
  "eager_load" => -> { Post.eager_load(:author).limit(10).to_a },
  "count" => -> { Post.where(author_id: author.id).count },
  "exists" => -> { Post.where(id: post_id).exists? },
  "pluck" => -> { Post.where(author_id: author.id).pluck(:id) },
  "create" => -> { created << Post.create!(author_id: author.id, title: "n") },
  "update" => -> { post.update!(views: post.views + 1) },
  "save_nochange" => -> { post.save! },
  "transaction" => -> { Post.transaction { } },
  "touch" => -> { post.touch },
  "update_columns" => -> { post.update_columns(views: 7) },
  "vupdate" => -> { vpost.update!(views: vpost.views + 1) },
  "vcreate" => -> { created << VPost.create!(author_id: author.id, title: "n", views: 1) },
  "touch_parent" => -> { tcomment.update!(body: tcomment.body == "a" ? "b" : "a") },
  "insert_all" => -> { Comment.insert_all(rows10) },
  "upsert_all" => -> { Tag.upsert_all(tagrows) },
  "create_destroy" => -> { Comment.create!(post_id: post_id, body: "z").destroy! },
  "new_record" => -> { Post.new(title: "x", views: 2) },
  "where_chain" => -> { Post.where(author_id: 1).where(published: false).order(:id).to_sql },
  "attributes_hash" => -> { post.attributes },
  "as_json" => -> { post.as_json },
}
f = CASES.fetch(CASE)
(ENV["WARMUP"] || 2000).to_i.times { f.() }
if %w[create vcreate insert_all].include?(CASE)
  Post.where("id > 20").delete_all
  Comment.where("body LIKE 'i%'").delete_all
  created.clear
end
GC.start
GC.disable
case MODE
when "ir"
  [0].cycle(1) { N.times { f.() } }
when "obj"
  b = GC.stat(:total_allocated_objects)
  N.times { f.() }
  puts (GC.stat(:total_allocated_objects) - b).fdiv(N)
when "sites"
  counts = Hash.new(0)
  ObjectSpace.trace_object_allocations do
    b = GC.stat(:total_allocated_objects)
    objs = []
    N.times { f.() }
  end
  ObjectSpace.each_object do |o|
    file = ObjectSpace.allocation_sourcefile(o) or next
    next unless ObjectSpace.allocation_generation(o) == GC.count
    counts["#{file.sub(/.*\/(active\w+|arel)\//, '\1/')}:#{ObjectSpace.allocation_sourceline(o)} #{o.class}"] += 1
  end
  counts.sort_by { -_2 }.first(25).each { |k, v| puts format("%7.2f %s", v.fdiv(N), k) }
else
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  N.times { f.() }
  puts (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(N).round(1)
end
