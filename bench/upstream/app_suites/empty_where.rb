# RAILS=path ruby empty_where.rb  -> prints the SQL for where("", {}) after another where; exit 1 if "(())"
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  gem "activerecord", path: "#{ENV.fetch("RAILS")}/activerecord"
  gem "activesupport", path: "#{ENV.fetch("RAILS")}/activesupport"
  gem "activemodel", path: "#{ENV.fetch("RAILS")}/activemodel"
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.integer :account_id } }
class Post < ActiveRecord::Base; end
sql = Post.where(account_id: 1).where("", {}).to_sql
puts sql
exit(sql.include?("(())") ? 1 : 0)
