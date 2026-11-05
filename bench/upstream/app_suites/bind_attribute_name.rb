# RAILS=path ruby bind_attribute_name.rb -> exit 1 if build_bind_attribute rejects a column name
# Mastodon's Status::SafeReblogInsert passes `arel_table[name].name`; main expects the Arel attribute.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title } }
class Post < ActiveRecord::Base; end
attr = Post.arel_table[:title]
results = { "column name" => attr.name, "Arel attribute" => attr }.map do |label, arg|
  bind = Post.predicate_builder.build_bind_attribute(arg, "hi")
  "#{label}: name is a #{bind.name.class}"
rescue => e
  "#{label}: #{e.class}: #{e.message[0, 60]}"
end
puts "#{ActiveRecord.version}: #{results.join("; ")}"
exit(results.first.include?("Error") ? 1 : 0)
