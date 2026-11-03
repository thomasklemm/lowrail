# Census 7 behavior control for C7-1 (order arguments) and C7-2 (single-predicate WHERE).
# Prints, per shape: references_values, eager_loading?, the SQL, the loaded ids, or the error raised.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.timestamps }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Author < ActiveRecord::Base; has_many :posts; end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; end
class Comment < ActiveRecord::Base; belongs_to :post; end
a = Author.create!(name: "a")
3.times { |i| a.posts.create!(title: "t#{2 - i}").comments.create!(body: "b#{i}") }
ToAry = Struct.new(:items) { def to_ary = items }
c = Comment.arel_table
SHAPES = {
  "order sym" => -> { Post.order(:id) },
  "order hash" => -> { Post.order(created_at: :desc, id: :asc) },
  "order string" => -> { Post.order("posts.title DESC") },
  "order other table string" => -> { Post.includes(:comments).order("comments.body") },
  "order nested hash" => -> { Post.includes(:comments).order(comments: { body: :desc }) },
  "order string key hash" => -> { Post.includes(:comments).order("comments.body" => :asc) },
  "order arel attribute" => -> { Post.includes(:comments).order(c[:body]) },
  "order arel ordering" => -> { Post.includes(:comments).order(c[:body].desc) },
  "order arel sql" => -> { Post.order(Arel.sql("length(title)")) },
  "order array" => -> { Post.order([:title, "id"]) },
  "order array with binds" => -> { Post.order([Arel.sql("REPLACE(title, ?, ?)"), "t", "x"]) },
  "order to_ary object" => -> { Post.order(ToAry.new([:title])) },
  "order raw sql" => -> { Post.order("REPLACE(title, 't', 'x')") },
  "order raw sql in array" => -> { Post.order(:id, [["title", "REPLACE(title, 't', 'x')"]]) },
  "order raw sql in hash" => -> { Post.order(:id, [{ "REPLACE(title, 't', 'x')" => :asc }]) },
  "order bad direction" => -> { Post.order(title: :sideways) },
  "reorder" => -> { Post.order(:id).reorder(title: :desc) },
  "in_order_of" => -> { Post.in_order_of(:title, %w[t1 t0 t2]) },
  "pluck strings" => -> { Post.order(:id).pluck(:id, "title") },
  "where one" => -> { Post.where(id: 1) },
  "where two" => -> { Post.where(id: 1, title: "t2") },
  "where string" => -> { Post.where("title = 't1'") },
  "where empty string" => -> { Post.where("") },
  "where not" => -> { Post.where.not(id: 1) },
  "where or" => -> { Post.where(id: 1).or(Post.where(id: 2)) },
  "where arel" => -> { Post.where(Post.arel_table[:id].gt(1)) },
  "association" => -> { a.posts.where(title: "t0") },
}
puts RUBY_DESCRIPTION.sub(/ \(.*/, "")
SHAPES.each do |label, fn|
  begin
    r = fn.()
    if r.is_a?(Array)
      puts "#{label}: #{r.inspect}"
    else
      puts "#{label}: refs=#{r.references_values.inspect} eager=#{r.eager_loading?} sql=#{r.to_sql}"
      puts "  ids=#{r.map(&:id).inspect}"
    end
  rescue => e
    puts "#{label}: #{e.class}: #{e.message[0, 120]}"
  end
end
