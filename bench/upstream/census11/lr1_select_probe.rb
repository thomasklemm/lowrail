# Counts LeaseRegistry#lease calls during SELECTs on an already-leased adapter.
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(ENV.fetch("RAILS"), c, "lib")) }
require "active_support/all"
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
conn = ActiveRecord::Base.lease_connection
calls = 0
tp = TracePoint.new(:call) { |t| calls += 1 if t.method_id == :lease && t.defined_class == ActiveRecord::ConnectionAdapters::ConnectionPool::LeaseRegistry }
tp.enable { p 10.times.map { |i| conn.select_value("SELECT #{i}") } }
puts "lease calls: #{calls}"
