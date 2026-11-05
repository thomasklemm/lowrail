# RAILS=path ruby fixture_unpin_rollback.rb -> pins the pool as a fixture setup does, inserts a row, unpins;
# prints the rows left. 8-1: pin_connection! opens a transaction and unpin_connection! rolls it back (0 rows).
# main: TestFixtures opens and rolls back the transaction itself, so a teardown that only unpins keeps the row (1).
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  %w[activerecord activesupport activemodel].each { gem _1, path: "#{ENV.fetch("RAILS")}/#{_1}" }
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) }
class Post < ActiveRecord::Base; end
pool = Post.connection_pool
pool.pin_connection!(true)
Post.create!
pool.unpin_connection!
puts "#{ActiveRecord.version}: #{Post.count} row(s) after unpin_connection!"
exit(Post.count.zero? ? 0 : 1)
