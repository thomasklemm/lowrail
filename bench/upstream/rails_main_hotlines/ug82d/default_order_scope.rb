# Does `scope :default_order` still define on Rails at RAILS_PATH? (Rails main adds a public default_order query method.)
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
begin
  class Post < ActiveRecord::Base
    scope :default_order, -> { order(:position) }
  end
  Post.create!(title: "b", position: 2); Post.create!(title: "a", position: 1)
  p Post.default_order.pluck(:title)
  p Post.where(title: %w[a b]).default_order.to_sql
rescue => e
  puts "#{e.class}: #{e.message}"
end
