# frozen_string_literal: true

# Per-call micro for schema-context reads (docs/upstream/schema-context.md),
# loading AR from RAILS_DIR. TZA=1 sets time_zone_aware_attributes, as every
# Rails app does, which puts the models on SchemaContext's slow path. ENUM=1 adds an
# enum to Post. ALLSLOW=1 keeps Author and Comment on the slow path (a Proc default).
# ruby [--yjit] micro.rb RAILS_DIR CASE[,CASE...] [ITERS] [ROUNDS]
# Prints one line per case: median ns/call over ROUNDS and objects/call.
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
cases = ARGV.fetch(1).split(",")
iters = Integer(ARGV[2] || 20_000)
rounds = Integer(ARGV[3] || 7)

require "active_record"
require "logger"
ActiveRecord::Base.establish_connection(adapter: ENV.fetch("ADAPTER", "sqlite3"),
                                        database: ENV.fetch("DATABASE", ":memory:"))
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Base.time_zone_aware_attributes = ENV["TZA"] == "1"
Time.zone = "UTC"

NCOLS = Integer(ENV.fetch("NCOLS", "12"))
ActiveRecord::Schema.define do
  create_table :authors, force: true do |t|
    t.string :name
    t.timestamps
  end
  create_table :posts, force: true do |t|
    t.references :author
    t.string :title
    t.text :body
    t.boolean :published, default: false
    t.integer :comments_count, default: 0
    (NCOLS - 7).times { |i| t.string :"extra_#{i}" } if NCOLS > 7
    t.integer :status, default: 0 if ENV["ENUM"] == "1"
    t.timestamps
  end
  create_table :comments, force: true do |t|
    t.references :post
    t.text :body
    t.timestamps
  end
end

class Author < ActiveRecord::Base
  has_many :posts
  attribute :scratch, :string, default: -> { "x" } if ENV["ALLSLOW"] == "1"
end

class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  scope :published, -> { where(published: true) }
  enum :status, [:draft, :live] if ENV["ENUM"] == "1"
end

class Comment < ActiveRecord::Base
  belongs_to :post
  attribute :scratch, :string, default: -> { "x" } if ENV["ALLSLOW"] == "1"
end

author = Author.create!(name: "a")
20.times do |i|
  post = Post.create!(author: author, title: "post #{i}", body: "body", published: i.even?)
  3.times { Comment.create!(post: post, body: "c") }
end

conn = Post.lease_connection
RESULT_ARGS = begin
  r = conn.select_all("SELECT * FROM posts LIMIT 10")
  [r.columns, r.rows, r.columns.each_index.map { |i| r.column_types[i] }]
end
POST = Post.first
ATTRS = POST.attributes_before_type_cast.freeze
# Like a request without a permanent lease: every query checks a connection out and in.
ActiveRecord::Base.connection_handler.clear_active_connections!(:all) unless ENV["LEASE"] == "1"

SLOW = Post.schema_context.instance_variable_get(:@attributes).nil?
warn "Post on #{SLOW ? "slow" : "fast"} path" if ENV["SHOW"]

CASES = {
  "attribute_types" => proc { Post.attribute_types },
  "columns_hash" => proc { Post.columns_hash },
  "has_attribute" => proc { Post.has_attribute?(:title) },
  "type_for_attribute" => proc { Post.type_for_attribute(:title) },
  "new" => proc { Post.new },
  "instantiate" => proc { Post.instantiate(ATTRS) },
  "load_from_sql_1" => proc { Post.send(:_load_from_sql, ActiveRecord::Result.new(RESULT_ARGS[0], RESULT_ARGS[1].first(1), RESULT_ARGS[2])) },
  "load_from_sql_10" => proc { Post.send(:_load_from_sql, ActiveRecord::Result.new(RESULT_ARGS[0], RESULT_ARGS[1], RESULT_ARGS[2])) },
  "find" => proc { Post.find(1) },
  "find_by" => proc { Post.find_by(title: "post 3") },
  "where_to_a" => proc { Post.where(author_id: 1).limit(5).to_a },
  "published_first" => proc { Post.published.order(:id).first },
  "belongs_to" => proc { POST.association(:author).reset; POST.author },
  "has_many_to_a" => proc { POST.association(:comments).reset; POST.comments.to_a },
  "where_to_sql" => proc { Post.where(author_id: 1, published: true).order(:id).limit(5).to_sql },
  "where_build" => proc { Post.where(author_id: 1, published: true).order(:id).limit(5).arel },
  "includes" => proc { Post.where(author_id: 1).limit(5).includes(:comments).to_a },
  "assoc_scope" => proc { a = POST.association(:comments); a.reset_scope; a.scope },
  "assoc_where" => proc { POST.comments.where(body: "c").to_a },
  "fresh_belongs_to" => proc { Post.instantiate(ATTRS).author },
  "fresh_has_many" => proc { Post.instantiate(ATTRS).comments.to_a },
  "fresh_has_many_where" => proc { Post.instantiate(ATTRS).comments.where(body: "c").to_a },
  "cached_find" => proc { Post.cache { Post.find(1); Post.find(1) } },
}

CLOCK = ENV["CLOCK"] == "cpu" ? Process::CLOCK_PROCESS_CPUTIME_ID : Process::CLOCK_MONOTONIC
def measure(blk, iters)
  GC.start
  t = Process.clock_gettime(CLOCK)
  iters.times(&blk)
  (Process.clock_gettime(CLOCK) - t) * 1e9 / iters
end

def objects(blk)
  blk.call
  GC.disable
  before = GC.stat(:total_allocated_objects)
  100.times(&blk)
  (GC.stat(:total_allocated_objects) - before) / 100.0
ensure
  GC.enable
end

if ENV["IR"]
  # Under callgrind --toggle-collect=rb_ary_cycle: one case, warmed up, then
  # ITERS calls collected with GC off. Instructions per call = Collected / ITERS.
  blk = CASES.fetch(cases.first)
  Integer(ENV.fetch("WARMUP", "2000")).times(&blk)
  GC.start
  GC.disable
  [nil].cycle(1) { iters.times(&blk) }
  exit
end

cases.each do |name|
  blk = CASES.fetch(name)
  measure(blk, iters) # warmup (and YJIT compile)
  times = Array.new(rounds) { measure(blk, iters) }.sort
  puts format("%-18s %9.1f ns  (min %.1f)  %6.1f obj", name, times[rounds / 2], times.first, objects(blk))
end
