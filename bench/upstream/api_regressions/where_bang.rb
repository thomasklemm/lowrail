require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :url; t.integer :n; t.datetime :at }
end
class Post < ActiveRecord::Base; end
Post.create!(url: "a/x", n: 1, at: Time.utc(2026, 1, 1))
Post.create!(url: "b", n: 2, at: Time.utc(2026, 6, 1))

def probe(label)
  r = yield
  puts "#{label}: #{r.to_sql} => #{r.pluck(:id).inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message.lines.first.strip[0, 120]}"
end

probe("where! ? one bind") { Post.all.where!("n = ?", 2) }
probe("where! ? two binds") { Post.all.where!("n = ? OR n = ?", 1, 2) }
probe("where! named bind") { Post.all.where!("url LIKE :u", u: "%x%") }
probe("where! time bind") { Post.all.where!("at >= ?", Time.utc(2026, 3, 1)) }
probe("where! array bind") { Post.all.where!("n IN (?)", [1, 2]) }
probe("where! array form") { Post.all.where!(["n = ?", 1]) }
probe("where! hash") { Post.all.where!(n: 1) }
probe("where! string") { Post.all.where!("n = 1") }
probe("having! ? bind") { Post.select(:n).group(:n).having!("n > ?", 1) }
probe("having! two binds") { Post.select(:n).group(:n).having!("n > ? AND n < ?", 0, 3) }
probe("where ? bind") { Post.where("n = ?", 2) }
probe("where named") { Post.where("url LIKE :u", u: "%x%") }
probe("having ? bind") { Post.select(:n).group(:n).having("n > ?", 1) }
probe("merge where") { Post.where(n: 1).merge(Post.where("url LIKE ?", "%x%")) }
probe("merge string cond") { Post.all.merge(where: ["n = ?", 2]) }
seen = []
ActiveRecord::Relation.prepend(Module.new { define_method(:where!) { |opts, *rest| seen << [opts, rest]; super(opts, *rest) } })
Post.where("n = ?", 2).to_a
Post.where(n: 1).to_a
puts "override sees: #{seen.inspect}"
