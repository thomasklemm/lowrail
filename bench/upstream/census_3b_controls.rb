# frozen_string_literal: true

# Behavior snapshots for the census-3b candidates; run against clean and
# changed Rails checkouts and diff the output. ruby census_3b_controls.rb RAILS_ROOT
root = ARGV.fetch(0)
%w[activesupport activemodel activerecord actionview].each { $LOAD_PATH.unshift File.join(root, _1, "lib") }
require "active_record"
require "action_view"
require "active_support/hash_with_indifferent_access"
out = []
snap = ->(label, &blk) { out << "#{label}: #{(begin; blk.call; rescue => e; [e.class, e.message]; end).inspect}" }

# tag_string parameter order: generated, self-closing and method_missing tags.
v = ActionView::Base.empty
snap.("span") { v.tag.span("x", class: "a") }
snap.("span block") { v.tag.span(class: "a") { "<b>" } }
snap.("span content+block") { v.tag.span("x") { "y" } }
snap.("span nil") { v.tag.span }
snap.("span escape false") { v.tag.span("<i>", escape: false) }
snap.("img void") { v.tag.img(src: "a.png") }
snap.("svg path self-closing") { v.tag.path(d: "M0") }
snap.("svg path content") { v.tag.path("x", d: "M0") }
snap.("custom tag") { v.tag.my_widget("x", data: { a: "1" }) }
snap.("custom tag no args") { v.tag.my_widget }
snap.("custom tag block") { v.tag.my_widget(id: 1) { "z" } }
snap.("custom tag two args") { v.tag.my_widget("a", "b") }
snap.("span two args") { v.tag.span("a", "b") }
snap.("content_tag") { v.content_tag(:div, "x", class: "c") }

# HashWithIndifferentAccess#fetch.
h = ActiveSupport::HashWithIndifferentAccess.new(a: 1, "b" => nil)
[[:a], ["a"], [:b], [:z], [:z, 0], [:z, nil], [:a, 0], [1], [:a, 1, 2]].each do |args|
  snap.("fetch #{args.inspect}") { h.fetch(*args) }
end
snap.("fetch block") { h.fetch(:z) { |k| "blk:#{k}" } }
snap.("fetch default+block") { h.fetch(:z, 0) { |k| "blk:#{k}" } }
snap.("fetch key error") { h.fetch(:z) rescue [$!.key, $!.receiver.equal?(h)] }

# Relation loading binds/joins and join chains.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.integer :status }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
  create_table(:taggings) { |t| t.integer :comment_id; t.integer :tag_id }
  create_table(:tags) { |t| t.string :name }
end
class Author < ActiveRecord::Base; has_many :posts; has_many :comments, through: :posts; has_many :tags, through: :comments; end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; enum :status, { draft: 0, live: 1 }; end
class Comment < ActiveRecord::Base; belongs_to :post; has_many :taggings; has_many :tags, through: :taggings; end
class Tagging < ActiveRecord::Base; belongs_to :comment; belongs_to :tag; end
class Tag < ActiveRecord::Base; end
a = Author.create!(name: "a"); p1 = Post.create!(author: a, status: :live); c = Comment.create!(post: p1, body: "b")
Tagging.create!(comment: c, tag: Tag.create!(name: "t"))
snap.("joins tags sql") { Author.joins(:tags).to_sql }
snap.("joins tags") { Author.joins(:tags).pluck(:name) }
snap.("left joins nested") { Author.left_joins(comments: :taggings).distinct.count }
snap.("eager tags") { Author.eager_load(:tags).map { _1.tags.map(&:name) } }
snap.("through reader") { a.reload.tags.map(&:name) }
snap.("enum where") { Post.where(status: "live").count }
snap.("enum serialize") { Post.type_for_attribute(:status).serialize("live") }
payloads = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, pl| payloads << pl[:binds] }
Post.where(author_id: a.id).load
Post.all.load
Author.find_by_sql("SELECT * FROM authors")
snap.("payload binds") { payloads.map { [_1.class, _1.size] } }
puts out
