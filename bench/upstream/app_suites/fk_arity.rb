# Usage: RAILS=/path/to/rails ruby fk_arity.rb
# A has_many whose foreign_key lists two columns while the owner has a one-column primary key
# (Discourse's chat plugin: has_many :category_channels, foreign_key: %i[chatable_id chatable_type]).
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "activerecord", path: ENV.fetch("RAILS")
  gem "activesupport", path: ENV.fetch("RAILS")
  gem "activemodel", path: ENV.fetch("RAILS")
  gem "sqlite3"
end
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  suppress_messages do
    create_table(:categories)
    create_table(:channels) { |t| t.integer :chatable_id; t.string :chatable_type }
  end
end

class Channel < ActiveRecord::Base
  belongs_to :chatable, polymorphic: true
end

class Category < ActiveRecord::Base
  has_many :channels, foreign_key: %i[chatable_id chatable_type], inverse_of: :chatable
end

category = Category.create!
Channel.create!(chatable: category)
puts "Rails #{ActiveRecord.version}"
r = Category.reflect_on_association(:channels)
puts "active_record_primary_key: #{r.active_record_primary_key.inspect}"
[
  ["category.channels.to_sql", -> { category.channels.to_sql }],
  ["category.channels.exists?", -> { category.channels.exists? }],
  ["category.channels.to_a.size", -> { category.channels.to_a.size }],
  ["Category.joins(:channels).count", -> { Category.joins(:channels).count }],
  ["Category.includes(:channels).first.channels.size", -> { Category.includes(:channels).first.channels.size }],
  ["category.channels.build.attributes", -> { category.channels.build.attributes.slice("chatable_id", "chatable_type") }],
].each do |label, call|
  result = begin
    call.call.inspect
  rescue => e
    "#{e.class}: #{e.message.lines.first.strip}"
  end
  puts "#{label}: #{result}"
end
