# Differential harness for C3 (through stale_state): run in main and candidate, diff.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title }
  create_table(:comments) { |t| t.integer :post_id; t.string :post_ref; t.boolean :flag_id }
  create_table(:shops, primary_key: [:region, :code]) { |t| t.string :region; t.string :code; t.integer :author_id }
  create_table(:orders) { |t| t.string :shop_region; t.string :shop_code }
end
LOG = []
module LogRead
  def read_attr(name) = super.tap { |v| LOG << "read_attr(#{name.inspect}) => #{v.inspect}" }
end
class Author < ActiveRecord::Base; end
class Post < ActiveRecord::Base; belongs_to :author; end
class Shop < ActiveRecord::Base; belongs_to :author; end
class Comment < ActiveRecord::Base
  prepend LogRead
  belongs_to :post
  belongs_to :post_by_sym, class_name: "Post", foreign_key: :post_id
  belongs_to :flagged_post, class_name: "Post", foreign_key: "flag_id"
  has_one :post_author, through: :post, source: :author
  has_one :sym_author, through: :post_by_sym, source: :author
  has_one :flag_author, through: :flagged_post, source: :author
  has_many :post_author_posts, through: :post_author, source: :author
end
class Order < ActiveRecord::Base
  prepend LogRead
  belongs_to :shop, foreign_key: [:shop_region, :shop_code]
  has_one :shop_author, through: :shop, source: :author
end

a = Author.create!(name: "a"); b = Author.create!(name: "b")
p1 = Post.create!(author: a); p2 = Post.create!(author: b)
Shop.create!(region: "eu", code: "1", author: a); Shop.create!(region: "eu", code: "2", author: b)
c = Comment.create!(post: p1)
o = Order.create!(shop_region: "eu", shop_code: "1")

def show(label, rec, assoc)
  LOG.clear
  proxy = rec.association(assoc)
  r = begin
    target = rec.public_send(assoc)
    "state=#{proxy.send(:stale_state).inspect} stale=#{proxy.stale_target?} target=#{target&.name.inspect}"
  rescue => e
    "#{e.class}: #{e.message}"
  end
  puts "#{label} | #{assoc} | #{r} | #{LOG.join(", ")}"
end

%i[post_author sym_author flag_author].each { |as| show("loaded", c, as) }
c.post_id = p2.id; %i[post_author sym_author].each { |as| show("fk changed", c, as) }
c.post_id = nil; show("fk nil", c, :post_author)
c.flag_id = false; show("fk false", c, :flag_author)
c.flag_id = true; show("fk true", c, :flag_author)
show("composite", o, :shop_author)
o.shop_code = "2"; show("composite changed", o, :shop_author)
o.shop_code = nil; show("composite partial nil", o, :shop_author)
c2 = Comment.new; show("new record", c2, :post_author)
c3 = Comment.find(c.id); c3.post_id = p1.id; show("found", c3, :post_author)
c3.post_id = "#{p2.id}"; show("string assigned", c3, :post_author)
