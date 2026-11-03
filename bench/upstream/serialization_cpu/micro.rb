# frozen_string_literal: true

# Per-call micro for JSON serialization (docs/upstream/serialization-cpu.md).
#   BUNDLE_GEMFILE=Gemfile.v-NAME bundle exec ruby [--yjit] micro.rb CASE[,CASE...] [ITERS] [ROUNDS]
# Prints median ns/call over ROUNDS and objects/call. With IR=1 (under
# callgrind --toggle-collect=rb_ary_cycle) runs one case ITERS times, GC off.
cases = ARGV.fetch(0).split(",")
iters = Integer(ARGV[1] || 2_000)
rounds = Integer(ARGV[2] || 7)

require "rails"
require "active_record"
require "action_controller"
require "action_view"
require "jbuilder"
require "jbuilder/jbuilder_template"
require "logger"
require "bigdecimal"
require "fileutils"

ActionView::Template.register_template_handler :jbuilder, JbuilderHandler
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
Time.zone = ENV.fetch("TZONE", "UTC")
ActiveRecord::Base.time_zone_aware_attributes = true
# load_defaults 8.1 (LEGACY=1 keeps the framework defaults: both escapes on).
unless ENV["LEGACY"] == "1"
  ActiveSupport.escape_js_separators_in_json = false
  ActionController::API.escape_json_responses = false
  ActionController::Base.escape_json_responses = false
end

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
    t.decimal :score, precision: 10, scale: 2
    t.datetime :published_at
    t.string :slug
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
end

class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

author = Author.create!(name: "Ada")
20.times do |i|
  post = Post.create!(author: author, title: ENV["PLAIN"] ? "Post #{i} about Ruby and Rails" : "Post #{i} about Ruby & Rails",
    body: (ENV["PLAIN"] ? "Body text #{i}, with “quotes” and é. " : "Body <b>#{i}</b> ") * 8,
    published: i.even?, score: BigDecimal("#{i}.25"), published_at: Time.utc(2026, 1, 1) + i * 3600, slug: "post-#{i}")
  3.times { |j| Comment.create!(post: post, body: "Comment #{j} on #{i}") }
end

POSTS = Post.order(:id).includes(:comments).to_a.freeze
POST = POSTS.first
RELATION = Post.order(:id).load

VIEWS = File.join(Dir.tmpdir, "serial-views-#{Process.pid}")
FileUtils.mkdir_p(File.join(VIEWS, "posts"))
File.write(File.join(VIEWS, "posts/index.json.jbuilder"), <<~J)
  json.array! @posts, partial: "posts/post", as: :post
J
File.write(File.join(VIEWS, "posts/_post.json.jbuilder"), <<~J)
  json.extract! post, :id, :title, :body, :published, :score, :published_at, :created_at, :updated_at
  json.author_name post.author.name
J
File.write(File.join(VIEWS, "posts/inline.json.jbuilder"), <<~J)
  json.array! @posts do |post|
    json.extract! post, :id, :title, :body, :published, :score, :published_at, :created_at, :updated_at
    json.author_name post.author.name
  end
J
at_exit { FileUtils.rm_rf(VIEWS) }
POSTS.each(&:author)

class ApiController < ActionController::API
  def index = render(json: POSTS)
  def show = render(json: POST)
end

class JbController < ActionController::Base
  prepend_view_path VIEWS
  def index
    @posts = POSTS
    render "posts/index", formats: [:json]
  end

  def inline
    @posts = POSTS
    render "posts/inline", formats: [:json]
  end
end

ENV_FOR = ->(path) { Rack::MockRequest.env_for(path, "HTTP_ACCEPT" => "application/json") }
API_INDEX = ApiController.action(:index)
API_SHOW = ApiController.action(:show)
JB_INDEX = JbController.action(:index)
JB_INLINE = JbController.action(:inline)
def call(app) = app.call(ENV_FOR.("/")).last.each { }

CASES = {
  "as_json" => proc { POST.as_json },
  "as_json_only" => proc { POST.as_json(only: [:id, :title, :created_at]) },
  "as_json_include" => proc { POST.as_json(include: :comments) },
  "serializable_hash" => proc { POST.serializable_hash },
  "to_json" => proc { POST.to_json },
  "array_as_json" => proc { POSTS.as_json },
  "relation_as_json" => proc { RELATION.as_json },
  "array_to_json" => proc { POSTS.to_json },
  "relation_to_json" => proc { RELATION.to_json },
  "render_json" => proc { call(API_INDEX) },
  "render_json_one" => proc { call(API_SHOW) },
  "jbuilder" => proc { call(JB_INDEX) },
  "jbuilder_inline" => proc { call(JB_INLINE) },
  "encode_hash" => proc { ActiveSupport::JSON.encode(POSTS.first.attributes) },
  "time_as_json" => proc { POST.created_at.as_json },
  "decimal_as_json" => proc { POST.score.as_json },
}

if ENV["SHOW"]
  cases.each { |c| r = CASES.fetch(c).call; puts "#{c}: #{(r.is_a?(String) ? r : r.inspect)[0, 300]}" }
  exit
end

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
  blk = CASES.fetch(cases.first)
  Integer(ENV.fetch("WARMUP", "300")).times(&blk)
  GC.start
  GC.disable
  [nil].cycle(1) { iters.times(&blk) }
  exit
end

if ENV["PROF"]
  require "stackprof"
  blk = CASES.fetch(cases.first)
  Integer(ENV.fetch("WARMUP", "300")).times(&blk)
  StackProf.run(mode: :wall, interval: 200, raw: true, out: ENV["PROF"]) { iters.times(&blk) }
  exit
end

cases.each do |name|
  blk = CASES.fetch(name)
  measure(blk, iters)
  times = Array.new(rounds) { measure(blk, iters) }.sort
  puts format("%-18s %10.1f ns  (min %.1f)  %7.1f obj", name, times[rounds / 2], times.first, objects(blk))
end
