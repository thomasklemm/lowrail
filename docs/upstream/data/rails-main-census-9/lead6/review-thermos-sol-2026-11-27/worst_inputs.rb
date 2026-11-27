# frozen_string_literal: true

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :score }
end
class Post < ActiveRecord::Base; end
Post.create!(title: "asymmetric", score: 7)
loaded = Post.first.instance_variable_get(:@attributes)
loaded["title"]
partial = Post.select(:id).first.instance_variable_get(:@attributes)
partial.keys
empty = Post.attributes_builder.build_from_row([].freeze, {}.freeze)
UpstreamBench.report("unknown String name") { loaded["missing"] }
UpstreamBench.report("nil name") { loaded[nil] }
UpstreamBench.report("cached String name") { loaded["title"] }
UpstreamBench.report("partial select missing slot") { partial["title"] }
UpstreamBench.report("empty keys") { empty.keys }
