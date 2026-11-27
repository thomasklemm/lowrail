# A model's own `def self.default_order` class method, called on a relation, before and after Rails main's default_order.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"])
    %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" }
  else
    gem "activerecord", ENV.fetch("AR_VERSION", "8.1.4.1")
  end
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :position } }
puts "Active Record #{ActiveRecord.version}"
class Post < ActiveRecord::Base
  def self.default_order = order(:position)
end
Post.create!(title: "b", position: 2); Post.create!(title: "a", position: 1); Post.create!(title: "c", position: 3)
[-> { Post.default_order.pluck(:title) }, -> { Post.where(title: %w[a b c]).default_order.pluck(:title) },
 -> { Post.all.default_order.to_sql }].each do |call|
  p call.()
rescue => e
  puts "#{e.class}: #{e.message}"
end
