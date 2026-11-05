# with_advisory_lock 7.6.0, transaction: true, on PostgreSQL: is the lock held until COMMIT?
# RAILS_PATH=/path/to/rails ruby advisory_xact_try_lock.rb   (needs a PostgreSQL; PGHOST/PGPORT/PGUSER)
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "pg"
  gem "with_advisory_lock", "7.6.0"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres", pool: 5)
class Thing < ActiveRecord::Base; self.table_name = "pg_class"; end

held = Queue.new
release = Queue.new
first = Thread.new do
  Thing.transaction do
    Thing.with_advisory_lock("demo", transaction: true) { held << true; release.pop }
  end
end
held.pop
second = Thread.new { Thing.transaction { Thing.with_advisory_lock("demo", transaction: true, timeout_seconds: 0) { :got_it } } }
puts "Rails #{ActiveRecord.version}: second writer while first holds the lock -> #{second.value.inspect} (expected false)"
release << true
first.join
