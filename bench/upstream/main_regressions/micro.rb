# frozen_string_literal: true

# Per-call micro for the 8-1-stable vs main regression round, for a Rails
# checkout given in RAILS (loads its lib directories, no bundle):
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ir     N calls inside Array#cycle (GC off), for
#                                                         Callgrind --toggle-collect=rb_ary_cycle (ir.sh)
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N stats  objects per call
#   RAILS=DIR ruby [--yjit|--zjit] micro.rb CASE N ns     wall ns per call over N calls
#   RAILS=DIR ruby micro.rb list                          case names
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
# As in a production app (Rails sets this from the log level): debug-only
# structured events stay silenced.
ActiveSupport.event_reporter.debug_mode = false
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.text :body; t.integer :views, default: 0; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body; t.timestamps }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
end
class Comment < ActiveRecord::Base; belongs_to :post; end
AUTHOR = Author.create!(name: "a")
3.times { |i| AUTHOR.posts.create!(title: "t#{i}", body: "b") }
POST = Post.first
3.times { POST.comments.create!(body: "c") }

[ActiveSupport::Inflector.method(:pluralize), ActiveRecord::Base.method(:find)].each do |m|
  raise "#{m.name} not loaded from #{rails}" unless m.source_location.first.start_with?(File.expand_path(rails) + "/")
end

ROUTES = ActionDispatch::Routing::RouteSet.new
ROUTES.draw { resources(:posts) { resources :comments } }
class View < ActionView::Base
  include ROUTES.url_helpers
end
VIEW = View.empty
FLIP = [false]

CONN = ActiveRecord::Base.connection
BINDS = [ActiveRecord::Relation::QueryAttribute.new("id", 1, Post.type_for_attribute("id")),
  ActiveRecord::Relation::QueryAttribute.new("title", "t1", Post.type_for_attribute("title"))]

CASES = {
  "type_casted_binds" => -> { CONN.send(:type_casted_binds, BINDS) },
  "value_for_database" => -> { BINDS[1].instance_variable_set(:@value_for_database, nil) if BINDS[1].instance_variable_defined?(:@value_for_database); BINDS[1].value_for_database },
  "find" => -> { Post.find(1) },
  "find_by" => -> { Post.find_by(title: "t1") },
  "where_to_a" => -> { Post.where(author_id: 1).to_a },
  "assoc_to_a" => -> { AUTHOR.posts.reset; AUTHOR.posts.to_a },
  "belongs_to" => -> { Post.find(1).author },
  "has_many_reader" => -> { p = Post.find(1); p.comments.to_a },
  "includes" => -> { Author.includes(:posts).to_a },
  "count" => -> { Post.where(author_id: 1).count },
  "exists" => -> { Post.exists?(1) },
  "pluck" => -> { Post.where(author_id: 1).pluck(:id) },
  "new_model" => -> { Post.new(title: "x", body: "y") },
  "attr_read" => -> { POST.title },
  "attributes" => -> { POST.attributes },
  "update" => -> { FLIP[0] = !FLIP[0]; POST.update!(views: FLIP[0] ? 1 : 2) },
  "create_rollback" => -> { Post.transaction { Post.create!(title: "x", author: AUTHOR); raise ActiveRecord::Rollback } },
  "to_param" => -> { POST.to_param },
  "cache_key" => -> { POST.cache_key_with_version },
  "as_json" => -> { POST.as_json },
  "path_helper" => -> { VIEW.post_comment_path(POST, 1) },
  "link_to" => -> { VIEW.link_to("x", VIEW.post_path(1), class: "a") },
  "content_tag" => -> { VIEW.content_tag(:div, "x", class: "a", data: { b: 1 }) },
  "tag_builder" => -> { VIEW.tag.div("x", class: "a") },
}

if ARGV[0] == "list"
  puts CASES.keys
  exit
end

name, n, mode = ARGV[0], Integer(ARGV[1]), ARGV[2] || "ir"
fn = CASES.fetch(name)
500.times { fn.() }
GC.start
GC.disable
case mode
when "ir"
  [nil].cycle(n) { fn.() }
when "stats"
  before = GC.stat(:total_allocated_objects)
  1000.times { fn.() }
  puts "#{name} #{(GC.stat(:total_allocated_objects) - before) / 1000.0} objects"
when "ns"
  GC.enable
  20_000.times { fn.() }
  GC.start
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond)
  n.times { fn.() }
  puts format("%.1f", (Process.clock_gettime(Process::CLOCK_MONOTONIC, :nanosecond) - t).fdiv(n))
end
