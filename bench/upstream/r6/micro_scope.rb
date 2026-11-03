# Per-call objects for named scope calls; usage: ruby micro_scope.rb RAILS_DIR
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { |f| File.join(ARGV[0], f, "lib") })
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.boolean :published; t.integer :n } }
class Post < ActiveRecord::Base
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(id: :desc) } do
    def tag = :ext
  end
  scope :min_n, ->(n) { where("n >= ?", n) }
  scope :plain_proc, proc { where(n: 1) }
end
rel = Post.where(n: 1)
def objs(n = 2000); n.times { yield }; a = GC.stat(:total_allocated_objects); n.times { yield }; (GC.stat(:total_allocated_objects) - a) / n.to_f; end
{ "Post.published" => -> { Post.published }, "relation.published" => -> { rel.published },
  "Post.recent (extension)" => -> { Post.recent }, "Post.min_n(1)" => -> { Post.min_n(1) },
  "Post.plain_proc" => -> { Post.plain_proc } }.each { |k, l| printf "%-26s %6.2f objects\n", k, objs(&l) }
# controls
p Post.published.to_sql, rel.published.to_sql, Post.recent.tag, Post.min_n(3).to_sql, Post.plain_proc(9).to_sql
[-> { Post.published(1) }, -> { Post.published(a: 1) }, -> { rel.published(1) }, -> { Post.recent(2) }].each do |l|
  l.call; p :no_error
rescue ArgumentError => e
  p [e.class, e.message]
end
p Post.method(:published).arity, Post.method(:published).parameters, Ractor.shareable?(Post.method(:published).to_proc) rescue p $!
