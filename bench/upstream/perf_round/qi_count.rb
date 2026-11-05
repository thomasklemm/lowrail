# Ivars and memsize per QueryIntent, per query shape. RAILS_PATH=tree ruby qi_count.rb
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "active_record"
require "objspace"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :n; t.timestamps } }
class Post < ActiveRecord::Base; end
$intents = []
ActiveRecord::ConnectionAdapters::QueryIntent.prepend(Module.new { def initialize(...) = (super; $intents << self) })
Post.create!(title: "a", n: 1)
shapes = {
  "find" => -> { Post.find(1) },
  "find_by" => -> { Post.find_by(title: "a") },
  "where.to_a" => -> { Post.where(n: 1).to_a },
  "first" => -> { Post.first },
  "count" => -> { Post.count },
  "pluck" => -> { Post.where(n: 1).pluck(:id) },
  "exists?" => -> { Post.exists?(1) },
  "create" => -> { Post.create!(title: "b", n: 2) },
  "update" => -> { Post.find(1).update!(n: rand(1000)) },
  "update_all" => -> { Post.where(n: 1).update_all(n: 1) },
  "delete" => -> { Post.where(n: -1).delete_all },
  "exec_query" => -> { Post.connection.exec_query("SELECT 1") },
  "select_all" => -> { Post.connection.select_all("SELECT * FROM posts") },
  "execute" => -> { Post.connection.execute("SELECT 1") },
  "transaction" => -> { Post.transaction { Post.find(1) } },
  "load_async" => -> { Post.where(n: 1).load_async.to_a },
}
shapes.each do |name, blk|
  3.times { blk.call }
  $intents.clear
  blk.call
  desc = $intents.map { |i| "#{i.instance_variables.size}iv/#{ObjectSpace.memsize_of(i)}B" }
  printf("%-12s %s\n", name, desc.join(" "))
end
puts RUBY_DESCRIPTION
if ENV["ASYNC"]
  ActiveRecord.async_query_executor = :global_thread_pool
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "/tmp/qi_async.sqlite3")
  ActiveRecord::Schema.define { create_table(:posts, force: true) { |t| t.string :title; t.integer :n; t.timestamps } }
  Post.reset_column_information
  Post.create!(title: "a", n: 1)
  $intents.clear
  ActiveRecord::Base.asynchronous_queries_tracker.start_session
  r = Post.where(n: 1).load_async; sleep 0.2; r.to_a
  puts "async: " + $intents.map { |i| "#{i.instance_variables.size}iv/#{ObjectSpace.memsize_of(i)}B" }.join(" ")
  $intents.clear; Post.find(1)
  puts "find after async: " + $intents.map { |i| "#{i.instance_variables.size}iv/#{ObjectSpace.memsize_of(i)}B" }.join(" ")
end
