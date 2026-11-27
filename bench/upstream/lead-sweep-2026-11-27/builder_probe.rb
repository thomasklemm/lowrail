# frozen_string_literal: true
# Per-row attributes_builder after #59141 and #59530: what does one read cost, and how many per 10-row load.
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
require "benchmark/ips"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.text :body; t.integer :n; t.datetime :at } }
class Post < ActiveRecord::Base; end
10.times { |i| Post.create!(title: "t#{i}", body: "b", n: i, at: Time.now) }
Post.all.to_a
reads = 0
mod = Module.new { define_method(:attributes_builder) { reads += 1; super() } }
Post.singleton_class.prepend(mod) if ENV["COUNT"]
Post.all.to_a; reads = 0; Post.all.to_a
puts "attributes_builder reads per 10-row load: #{reads}" if ENV["COUNT"]
exit if ENV["COUNT"]
Benchmark.ips(quiet: true) do |x|
  x.config(time: 2, warmup: 1)
  x.report("attributes_builder") { Post.attributes_builder }
  x.report("Post.all.to_a (10 rows)") { Post.all.to_a }
  x.compare!
end.entries.each { |e| puts format("%-28s %10.1f ns", e.label, 1e9 / e.ips) }
