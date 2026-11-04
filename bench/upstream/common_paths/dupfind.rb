require_relative "app"
hits = Hash.new(0)
mod = Module.new do
  define_method(:to_sql_and_binds) do |arel_or_sql, *rest|
    if String === arel_or_sql && !arel_or_sql.frozen? && !(Arel.arel_node?(arel_or_sql))
      loc = caller_locations(1, 12).map { |l| "#{l.path.sub(%r{.*/work/rails/}, '')}:#{l.lineno}" }.reject { |l| l.include?("database_statements.rb") || l.include?("query_cache.rb") }.first(3)
      hits[[$op, loc]] += 1
    end
    super(arel_or_sql, *rest)
  end
end
ActiveRecord::ConnectionAdapters::AbstractAdapter.prepend(mod)
post = Post.first
ops = {
  "create" => -> { Post.create!(title: "n", author: Author.first) },
  "update" => -> { post.update!(title: "x#{rand}") },
  "destroy" => -> { Post.create!(title: "d", author: Author.first).destroy },
  "transaction" => -> { Post.transaction { Post.first } },
  "nested txn" => -> { Post.transaction { Post.transaction(requires_new: true) { Post.first } } },
  "touch" => -> { post.touch },
  "increment!" => -> { post.increment!(:status) rescue nil },
  "lock!" => -> { Post.transaction { post.lock! } },
  "exists?" => -> { Post.exists?(title: "x") },
  "pluck" => -> { Post.where(status: :live).pluck(:id) },
  "count" => -> { Post.where(status: :live).count },
  "includes" => -> { Post.includes(:comments).to_a },
  "insert_all" => -> { Post.insert_all([{ title: "i", author_id: 1 }]) },
  "upsert_all" => -> { Post.upsert_all([{ id: post.id, title: "u" }]) },
  "find_each" => -> { Post.find_each { } },
  "update_all" => -> { Post.where(id: 0).update_all(title: "z") },
  "delete_all" => -> { Post.where(id: 0).delete_all },
  "find_by_sql str" => -> { Post.find_by_sql("SELECT * FROM posts LIMIT 1") },
  "find_by_sql arr" => -> { Post.find_by_sql(["SELECT * FROM posts WHERE id = ?", 1]) },
  "where string" => -> { Post.where("title = ?", "x").to_a },
  "comments.count" => -> { post.comments.count },
  "comments.size" => -> { post.comments.reset; post.comments.size },
  "validates uniqueness" => -> { Comment.first.valid? },
}
ops.each { |n, op| $op = n; 3.times { op.() } }
hits.each { |(op, loc), c| puts "#{op}: #{c} #{loc.inspect}" }
