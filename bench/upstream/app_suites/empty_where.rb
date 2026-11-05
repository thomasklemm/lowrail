# RAILS=path ruby empty_where.rb -> runs where("", values) after another where; exit 1 if the query fails
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.integer :account_id } }
class Post < ActiveRecord::Base; end
Post.create!(account_id: 1)
Post.create!(account_id: 2)
failed = false
[{}, { account_id: 1 }, 1].each do |values|
  [Post.where(account_id: 1).where("", values), Post.where(account_id: 1).where(["", values])].each do |relation|
    puts "#{relation.to_sql} => #{relation.to_a.size} row(s)"
  rescue ActiveRecord::StatementInvalid => error
    failed = true
    puts "#{relation.to_sql} => #{error.class}: #{error.message.lines.first.strip}"
  end
end
exit(failed ? 1 : 0)
