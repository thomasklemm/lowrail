# Usage: RAILS=/path/to/rails ruby pg_send_query.rb  (needs a local PostgreSQL with a "postgres" database)
# Which PG::Connection methods Active Record calls for a non-prepared query, as seen by an app that wraps
# exec/async_exec/exec_params (Discourse's MethodProfiler and Migration::SafeMigrate do).
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "activerecord", path: ENV.fetch("RAILS")
  gem "activesupport", path: ENV.fetch("RAILS")
  gem "activemodel", path: ENV.fetch("RAILS")
  gem "pg"
end
require "active_record"

CALLS = Hash.new(0)
PG::Connection.prepend(Module.new do
  %i[exec async_exec sync_exec exec_params async_exec_params exec_prepared send_query send_query_params
     send_query_prepared query].each do |name|
    define_method(name) { |*args, &blk| CALLS[name] += 1; super(*args, &blk) }
  end
end)

ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres", prepared_statements: false)
conn = ActiveRecord::Base.lease_connection
conn.execute("SELECT 1")
CALLS.clear
conn.execute("SELECT 1")
conn.select_all("SELECT $1::int AS n", "q", [ActiveRecord::Relation::QueryAttribute.new("n", 1, ActiveRecord::Type::Integer.new)])
puts "Rails #{ActiveRecord.version}: #{CALLS.sort.to_h}"
