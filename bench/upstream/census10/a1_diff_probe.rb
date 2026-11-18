# frozen_string_literal: true

# Lead A1 differential probe: for a Rails checkout in RAILS, prints the SQL, the loaded records and every
# deprecation warning of association loads, preloads, eager loads, joins and through chains, including
# scopes that unscope or rewhere the owner conditions, with KEEP=0/1 for
# association_scope_keeps_owner_conditions; and counts calls into a custom key type's ==/eql?/hash.
# Diff the output of two trees.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord.association_scope_keeps_owner_conditions = ENV.fetch("KEEP", "0") == "1"
WARN = []
ActiveRecord.deprecator.behavior = ->(msg, *) { WARN << msg.sub(/\(called from .*\z/m, "").strip }
$calls = Hash.new(0)
class KeyType < ActiveModel::Type::Integer
  def ==(o) = ($calls[:type_eq] += 1; super)
  alias eql? ==
  def hash = ($calls[:type_hash] += 1; super)
end
ActiveRecord::Schema.define do
  create_table(:users) { |t| t.string :name; t.string :type }
  create_table(:messages) { |t| t.integer :user_id; t.integer :sender_id; t.integer :recipient_id; t.string :body; t.boolean :visible, default: true }
  create_table(:posts) { |t| t.integer :user_id; t.string :title; t.string :type; t.boolean :published, default: true; t.datetime :deleted_at }
  create_table(:comments) { |t| t.integer :post_id; t.string :body; t.boolean :visible, default: true }
  create_table(:pictures) { |t| t.integer :imageable_id; t.string :imageable_type; t.string :url }
  create_table(:taggings) { |t| t.integer :post_id; t.integer :tag_id }
  create_table(:tags) { |t| t.string :name }
end
class User < ActiveRecord::Base
  attribute :id, KeyType.new
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :all_posts, -> { unscope(where: :user_id) }, class_name: "Post"
  has_many :rewhere_posts, -> { rewhere(user_id: 0) }, class_name: "Post"
  has_many :messages, ->(u) { unscope(where: :user_id).where("sender_id = :id OR recipient_id = :id", id: u.id) }
  has_many :visible_messages, -> { where(visible: true) }, class_name: "Message"
  has_many :comments, through: :posts
  has_many :visible_comments, -> { where(visible: true) }, through: :posts, source: :comments
  has_many :tags, through: :posts
  has_many :pictures, as: :imageable
  has_many :typeless_pictures, -> { unscope(where: :imageable_type) }, as: :imageable, class_name: "Picture"
  has_one :latest_post, -> { order(id: :desc) }, class_name: "Post"
end
class Admin < User; end
class Post < ActiveRecord::Base
  attribute :user_id, KeyType.new
  default_scope { where(deleted_at: nil) }
  belongs_to :user
  has_many :comments
  has_many :taggings
  has_many :tags, through: :taggings
  has_many :pictures, as: :imageable
end
class SpecialPost < Post; end
class Comment < ActiveRecord::Base
  attribute :post_id, KeyType.new
  belongs_to :post
end
class Message < ActiveRecord::Base; belongs_to :user; end
class Picture < ActiveRecord::Base; belongs_to :imageable, polymorphic: true; end
class Tagging < ActiveRecord::Base; belongs_to :post; belongs_to :tag; end
class Tag < ActiveRecord::Base; has_many :taggings; end

u = User.create!(name: "u"); a = Admin.create!(name: "a"); other = User.create!(name: "o")
[u, a, other].each do |owner|
  2.times { |i| owner.posts.create!(title: "p#{i}") }
  SpecialPost.create!(user: owner, title: "s")
  owner.pictures.create!(url: "x")
  Message.create!(user_id: owner.id, sender_id: owner.id, recipient_id: other.id, body: "m")
end
Post.find_each { |p| p.comments.create!(body: "c"); p.comments.create!(body: "h", visible: false); t = Tag.create!(name: "t#{p.id}"); p.taggings.create!(tag: t) }
Picture.create!(imageable_id: u.id, imageable_type: "Other", url: "foreign")

assocs = %i[posts published_posts all_posts rewhere_posts messages visible_messages comments visible_comments tags pictures typeless_pictures latest_post]
sqls = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, p| sqls << p[:sql] unless p[:name] == "SCHEMA" }
rec = ->(r) { Array(r).map { |x| "#{x.class.name}##{x.id}" }.sort }
run = lambda do |label, &blk|
  sqls.clear; WARN.clear; $calls.clear
  out = begin
    blk.()
  rescue => e
    "#{e.class}: #{e.message[0, 200]}"
  end
  puts "#{label}: #{out.inspect}"
  sqls.each { puts "  sql #{_1}" }
  WARN.uniq.each { puts "  warn #{_1}" }
  puts "  calls #{$calls.sort.to_h}" unless $calls.empty?
end
[u, a].each do |owner|
  assocs.each do |name|
    run.("#{owner.class}.#{name} load") { owner.association(name).reset; rec.(owner.public_send(name)) }
    run.("#{owner.class}.#{name} to_sql") { owner.association(name).reset; r = owner.public_send(name); r.respond_to?(:to_sql) ? r.to_sql : rec.(r) }
    run.("#{owner.class}.#{name} where") { r = owner.public_send(name); r.respond_to?(:where) ? rec.(r.where.not(id: 0)) : nil }
  end
end
assocs.each do |name|
  run.("preload #{name}") { User.where(id: [u.id, a.id]).preload(name).map { |x| rec.(x.public_send(name)) } }
  run.("includes #{name}") { User.where(id: [u.id, a.id]).includes(name).map { |x| rec.(x.public_send(name)) } }
  run.("eager_load #{name}") { User.where(id: [u.id, a.id]).eager_load(name).order(:id).map { |x| rec.(x.public_send(name)) } }
  run.("joins #{name}") { User.joins(name).order(:id).distinct.pluck(:id) }
  run.("left_joins #{name}") { User.left_joins(name).order(:id).distinct.pluck(:id) }
  run.("where.associated #{name}") { User.where.associated(name).order(:id).distinct.pluck(:id) }
end
run.("belongs_to") { Comment.first.association(:post).reset; rec.(Comment.first.post) }
run.("belongs_to polymorphic") { Picture.first.association(:imageable).reset; rec.(Picture.first.imageable) }
run.("Post.joins(:user, :tags)") { Post.joins(:user, :tags).order(:id).pluck(:id) }
run.("Admin.joins(:posts)") { Admin.joins(:posts).pluck(:id) }
run.("SpecialPost.joins(:user)") { SpecialPost.joins(:user).order(:id).pluck(:id) }
run.("build") { u.posts.build(title: "n").attributes.slice("user_id", "title") }
run.("create") { u.posts.create!(title: "n2").user_id }
run.("delete_all") { u.all_posts.where(title: "n2").delete_all }
run.("count") { [u.posts.count, u.all_posts.count, u.messages.count, u.typeless_pictures.count] }
