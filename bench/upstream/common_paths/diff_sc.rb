require "bundler/setup"
require "active_record"

out = []
log = ->(*a) { out << a.map(&:inspect).join(" ") }

[true, false].each do |prepared|
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", prepared_statements: prepared)
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define do
    create_table(:authors, force: true) { |t| t.string :name }
    create_table(:posts, force: true) { |t| t.references :author; t.string :title }
    create_table(:cpk_books, primary_key: [:shop_id, :number], force: true) { |t| t.integer :shop_id; t.integer :number; t.string :title }
  end
  Object.send(:remove_const, :Author) if defined?(Author)
  Object.send(:remove_const, :Post) if defined?(Post)
  Object.send(:remove_const, :CpkBook) if defined?(CpkBook)
  Object.const_set(:Author, Class.new(ActiveRecord::Base) { self.table_name = "authors"; has_many :posts, class_name: "Post" })
  Object.const_set(:Post, Class.new(ActiveRecord::Base) { self.table_name = "posts"; belongs_to :author, class_name: "Author" })
  Object.const_set(:CpkBook, Class.new(ActiveRecord::Base) { self.table_name = "cpk_books" })
  a = Author.create!(name: "a")
  Post.create!(author: a, title: "t1")
  Post.create!(author: a, title: "t2")
  CpkBook.create!(shop_id: 1, number: 2, title: "b")

  sqls = []
  sub = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    s = payload[:sql]
    sqls << [s, s.class, s.frozen?, s.encoding.to_s] if payload[:name] =~ /Load/
  end

  run = ->(label, &blk) do
    sqls.clear
    r = begin
      v = blk.call
      v.respond_to?(:to_a) && !v.is_a?(ActiveRecord::Base) ? v.to_a.map(&:attributes) : (v.respond_to?(:attributes) ? v.attributes : v)
    rescue => e
      [e.class, e.message]
    end
    log.(prepared, label, r, sqls.map { |s, *rest| [s.dup, *rest] })
    sqls.map(&:first)
  end

  run.("find", &-> { Post.find(Post.first.id) })
  run.("find missing", &-> { Post.find(999) })
  run.("find out of range", &-> { Post.find(2**70) })
  run.("find string id", &-> { Post.find(Post.first.id.to_s) })
  run.("find_by", &-> { Post.find_by(title: "t2") })
  run.("find_by nil", &-> { Post.find_by(title: nil) })
  run.("cpk find", &-> { CpkBook.find([1, 2]) })
  run.("cpk find_by", &-> { CpkBook.find_by(shop_id: 1, number: 2) })
  run.("belongs_to", &-> { p = Post.first; p.association(:author).reset; p.author })
  run.("has_many", &-> { a.association(:posts).reset; a.posts })
  run.("query cache", &-> { ActiveRecord::Base.cache { [Post.find(Post.first.id), Post.find(Post.first.id)].map(&:attributes) } })
  first = run.("repeat 1", &-> { Post.find_by(title: "t1") })
  second = run.("repeat 2", &-> { Post.find_by(title: "t1") })
  log.(prepared, "same sql object across executions", first.zip(second).map { |x, y| x.equal?(y) })

  ActiveSupport::Notifications.unsubscribe(sub)

  mut = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
    payload[:sql] << " -- x" if payload[:name] =~ /Load/
  end
  run.("subscriber appends to sql", &-> { Post.find_by(title: "t1") })
  ActiveSupport::Notifications.unsubscribe(mut)
  ActiveRecord::Base.remove_connection
end
puts out
