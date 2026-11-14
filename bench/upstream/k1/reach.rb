# frozen_string_literal: true

# K1 reach: which common record paths call LazyIndexedAttributeSet#keys and #materialize, and from where.
#   BUNDLE_GEMFILE=<suite for main> ruby bench/upstream/k1/reach.rb
require "bundler/setup"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :score; t.string :type; t.timestamps }
end
class Post < ActiveRecord::Base; end
class Special < Post; attribute :extra, :string; end
Post.create!(title: "a", score: 1)
Special.create!(title: "b", score: 2)

PATHS = {
  "load" => -> { Post.where(type: nil).first },
  "reader" => -> { Post.where(type: nil).first.title },
  "#attributes" => -> { Post.where(type: nil).first.attributes },
  "#attribute_names" => -> { Post.where(type: nil).first.attribute_names },
  "assign" => -> { Post.where(type: nil).first.title = "x" },
  "changed?" => -> { Post.where(type: nil).first.changed? },
  "changes" => -> { p = Post.where(type: nil).first; p.title = "x"; p.changes },
  "save (no change)" => -> { Post.where(type: nil).first.save! },
  "update" => -> { Post.where(type: nil).first.update!(score: rand(100)) },
  "create" => -> { Post.create!(title: "c") },
  "new" => -> { Post.new(title: "n") },
  "dup" => -> { Post.where(type: nil).first.dup },
  "serializable_hash" => -> { Post.where(type: nil).first.serializable_hash },
  "as_json" => -> { Post.where(type: nil).first.as_json },
  "inspect" => -> { Post.where(type: nil).first.inspect },
  "partial select" => -> { Post.select(:id, :title).first.attributes },
  "STI load" => -> { Post.where(type: "Special").first.attributes },
  "reload" => -> { Post.where(type: nil).first.reload },
  "destroy" => -> { Post.create!(title: "d").destroy },
}

calls = Hash.new { |h, k| h[k] = Hash.new(0) }
current = nil
tp = TracePoint.new(:call) do |t|
  next unless current && t.defined_class == ActiveModel::LazyIndexedAttributeSet && %i[keys materialize].include?(t.method_id)
  site = caller_locations(2, 8).find { |l| !l.path.end_with?("attribute_set.rb") }
  calls[current]["#{t.method_id} <- #{site.path.sub(%r{.*/(active\w+/lib/)}, '\1')}:#{site.lineno} #{site.label}"] += 1
end
PATHS.each do |name, fn|
  fn.call
  current = name
  tp.enable { fn.call }
  current = nil
end
PATHS.each_key do |name|
  puts "#{name}: #{calls[name].empty? ? 'none' : ''}"
  calls[name].each { |site, n| puts "  #{n}x #{site}" }
end
