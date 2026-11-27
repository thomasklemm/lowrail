require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"]) then %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" } else gem "activerecord", "8.1.4.1" end
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :position } }
class Post < ActiveRecord::Base
  def self.default_order(*args) = order(position: :desc)
  def self.fwd = [name, current_scope&.where_values_hash]
end
Post.create!(title: "a", position: 2); Post.create!(title: "z", position: 1)
puts ActiveRecord.version
p [:name, ActiveRecord::Base.respond_to?(:name, true), Object.respond_to?(:name, true), Post.send(:dangerous_class_method?, :name)]
p [:inspect, Post.send(:dangerous_class_method?, :inspect)]
q = Post.where(title: %w[a z]); q.fwd; p [:fwd_twice, q.class.method_defined?(:fwd), q.fwd]
p [:table_name_owner, q.method(:table_name).owner]
["CC BY-SA", :position].each { |a| p [a, (q.default_order(a).pluck(:title) rescue "#{$!.class}")] }
