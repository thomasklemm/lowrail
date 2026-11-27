# frozen_string_literal: true

# Differential probe for QCK1 and ASC1: prints one line per observation, to be
# diffed between Rails main and a branch.
#   RAILS=/path/to/rails ruby probe.rb [prepared_statements]
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { "#{ENV.fetch("RAILS")}/#{_1}/lib" })
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:",
  prepared_statements: ARGV[0] != "false", query_cache: 3)
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.json :meta }
  create_table(:posts) { |t| t.references :author; t.string :title; t.boolean :published }
  create_table(:profiles) { |t| t.references :author; t.string :bio }
  create_table(:comments) { |t| t.references :commentable, polymorphic: true; t.string :body }
  create_table(:tags) { |t| t.references :post; t.string :name }
end

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

class Author < ApplicationRecord
  has_many :posts
  has_one :profile
  has_many :comments, as: :commentable
  has_many :tags, through: :posts
end

class Post < ApplicationRecord
  belongs_to :author
  has_many :tags
  has_many :comments, as: :commentable
end

class Profile < ApplicationRecord
  belongs_to :author
end

class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
end

class Tag < ApplicationRecord
  belongs_to :post
end

a = Author.create!(name: "a", meta: { "k" => [1, 2] })
b = Author.create!(name: "b")
3.times { |i| p = a.posts.create!(title: "t#{i}", published: i.odd?); p.tags.create!(name: "x#{i}") }
a.create_profile!(bio: "bio")
a.comments.create!(body: "c1")
Post.first.comments.create!(body: "c2")

EVENTS = []
ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
  EVENTS << [payload[:sql], payload[:cached] ? "cached" : "db", payload[:binds].map { _1.value_for_database rescue _1 }.inspect]
end
CHECKOUTS = Hash.new(0)
ActiveRecord::ConnectionAdapters::ConnectionPool.prepend(Module.new do
  def checkout(...)
    CHECKOUTS[:checkout] += 1
    super
  end
end)

def show(label)
  EVENTS.clear
  CHECKOUTS.clear
  result = begin
    yield.inspect
  rescue => e
    "#{e.class}: #{e.message}"
  end
  puts "#{label}: #{result}"
  EVENTS.each { puts "  #{_1.join(" | ")}" }
  puts "  checkouts=#{CHECKOUTS[:checkout]}"
end

pool = ActiveRecord::Base.connection_pool
reload = ->(r) { r.class.find(r.id) }

# Association loads without a leased connection, then with one.
ActiveRecord::Base.release_connection
%w[posts profile comments tags].each do |name|
  show("unleased #{name}") { reload.(a).public_send(name).to_a rescue reload.(a).public_send(name) }
end
show("unleased belongs_to") { reload.(Post.first).author }
show("unleased polymorphic") { reload.(Comment.last).commentable }
show("unleased async posts") { reload.(a).association(:posts).send(:find_target, async: true).value }
ActiveRecord::Base.lease_connection
%w[posts profile comments tags].each do |name|
  show("leased #{name}") { x = reload.(a).public_send(name); x.respond_to?(:to_a) ? x.to_a : x }
end
show("strict_loading") { r = reload.(a); r.strict_loading!; r.posts.to_a }
show("empty has_many") { reload.(b).posts.to_a }

# Query cache: hits, misses, eviction (max size 3) and mixed keys.
pool.enable_query_cache!
show("qc first") { Post.where(author_id: a.id, published: true).to_a.map(&:id) }
show("qc again") { Post.where(author_id: a.id, published: true).to_a.map(&:id) }
show("qc other value") { Post.where(author_id: a.id, published: false).to_a.map(&:id) }
show("qc no binds") { Post.connection.select_all("SELECT COUNT(*) FROM posts").rows }
show("qc no binds again") { Post.connection.select_all("SELECT COUNT(*) FROM posts").rows }
show("qc find") { Post.find(Post.first.id).title }
show("qc evicted?") { Post.where(author_id: a.id, published: true).to_a.map(&:id) }
show("qc json bind") { Author.where(meta: { "k" => [1, 2] }).pluck(:name) }
show("qc json bind again") { Author.where(meta: { "k" => [1, 2] }).pluck(:name) }
show("qc string bind") { Post.where(title: +"t1").pluck(:id) }
show("qc string bind again") { Post.where(title: "t1".dup).pluck(:id) }
show("qc find_by_sql raw binds") { Post.find_by_sql(["SELECT id FROM posts WHERE title = ?", "t2"]).map(&:id) }
show("qc find_by_sql raw binds again") { Post.find_by_sql(["SELECT id FROM posts WHERE title = ?", "t2"]).map(&:id) }
show("qc async") { Post.where(author_id: a.id).load_async.to_a.size }
show("qc write clears") { Post.where(id: 0).update_all(title: "z"); Post.where(author_id: a.id, published: true).to_a.map(&:id) }
show("qc uncached") { Post.uncached { Post.where(author_id: a.id, published: true).to_a.map(&:id) } }
show("qc lock not cached") { Post.lock.where(author_id: a.id).to_a.size }
show("qc size") { Post.connection.query_cache.size }
