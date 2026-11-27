# frozen_string_literal: true
# Census-10 A2: what the second AliasTracker in ThroughAssociation#target_scope costs per through load on main.
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
require "benchmark/ips"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Author < ActiveRecord::Base; has_many :posts; has_many :comments, through: :posts; end
class Post < ActiveRecord::Base; has_many :comments; end
class Comment < ActiveRecord::Base; end
a = Author.create!(name: "a"); a.posts.create!.comments.create!(body: "b")
rel = Post.all
Benchmark.ips(quiet: true) do |x|
  x.config(time: 2, warmup: 1)
  x.report("Relation#alias_tracker") { rel.alias_tracker }
  x.report("author.comments.to_a") { Author.find(a.id).comments.to_a }
end.entries.each { |e| puts format("%-24s %9.0f ns", e.label, 1e9 / e.ips) }
b = GC.stat(:total_allocated_objects); 1000.times { rel.alias_tracker }
puts "alias_tracker objects #{(GC.stat(:total_allocated_objects) - b) / 1000.0}"
