# RAILS=path ruby pluck_new_owner.rb -> prints what pluck returns on a has_many of an unsaved owner with a built record
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts)
  create_table(:comments) { |t| t.references :post; t.string :body }
end
class Post < ActiveRecord::Base; has_many :comments; end
class Comment < ActiveRecord::Base; belongs_to :post; end

post = Post.new
post.comments.build(body: "built")
result = { pluck: post.comments.pluck(:body), ids: post.comments.ids, count: post.comments.count, size: post.comments.size, exists: post.comments.exists?(body: "built") }
puts result.inspect
exit(result[:pluck] == [] ? 0 : 1)
