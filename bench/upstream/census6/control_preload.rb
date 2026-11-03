# Prints, for each preload shape, every SQL statement in order and the loaded graph.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.string :type }
  create_table(:comments) { |t| t.integer :post_id; t.integer :author_id; t.string :commentable_type; t.integer :commentable_id }
  create_table(:tags) { |t| t.integer :post_id; t.string :name }
  create_table(:photos) { |t| t.integer :author_id }
end
class Author < ActiveRecord::Base
  has_many :posts; has_many :comments, through: :posts; has_many :tags, through: :posts; has_many :photos
  has_many :recent_posts, ->(author) { where("posts.id > ?", author.id) }, class_name: "Post"
end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; has_many :tags; has_many :commenters, through: :comments, source: :author; end
class SpecialPost < Post; end
class Comment < ActiveRecord::Base; belongs_to :post; belongs_to :author; belongs_to :commentable, polymorphic: true; end
class Tag < ActiveRecord::Base; belongs_to :post; end
class Photo < ActiveRecord::Base; belongs_to :author; has_many :comments, as: :commentable; end
as = 3.times.map { |i| Author.create!(name: "a#{i}") }
as.each_with_index do |a, i|
  2.times do |j|
    p = (j.odd? ? SpecialPost : Post).create!(author: a, title: "t#{i}#{j}")
    2.times { |k| Comment.create!(post: p, author: as[(i + k) % 3], commentable: (k.zero? ? p : Photo.create!(author: a))) }
    p.tags.create!(name: "n#{j}")
  end
end
sqls = []
ActiveSupport::Notifications.subscribe("sql.active_record") { |*, payload| sqls << payload[:sql] unless payload[:name] == "SCHEMA" }
dump = ->(r) { r.map { |x| x.attributes.slice("id").merge(x.class.reflect_on_all_associations.select { x.association(_1.name).loaded? }.to_h { |as| v = x.association(as.name).target; [as.name, v.is_a?(Array) ? v.map(&:id) : v&.id] }) } }
{
  "nested" => -> { Author.preload(posts: [:tags, { comments: :author }]).to_a },
  "through" => -> { Author.preload(:comments, :tags).to_a },
  "through nested" => -> { Post.preload(commenters: :photos).to_a },
  "polymorphic" => -> { Comment.preload(:commentable, :post).to_a },
  "polymorphic nested" => -> { Comment.preload(commentable: :author).to_a },
  "instance dependent" => -> { Author.preload(:recent_posts).to_a },
  "includes + references" => -> { Author.includes(:posts).where(posts: { title: "t00" }).to_a },
  "sti" => -> { SpecialPost.preload(:author, :comments).to_a },
  "already loaded" => -> { a = Author.preload(:posts).to_a; ActiveRecord::Associations::Preloader.new(records: a, associations: { posts: :tags }).call; a },
}.each do |label, fn|
  sqls.clear
  result = fn.()
  puts "== #{label}"
  sqls.each { puts "  sql: #{_1}" }
  dump.(result).each { puts "  #{_1}" }
end
