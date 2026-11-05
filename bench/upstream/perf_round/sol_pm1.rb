# Sol's dup/freeze repro: a completed async intent with lock_wait = 17
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "active_record"; require "objspace"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
QI = ActiveRecord::ConnectionAdapters::QueryIntent
c = ActiveRecord::Base.lease_connection
sess = ActiveRecord::AsynchronousQueriesTracker::Session.new
mk = -> { i = QI.new(adapter: c, raw_sql: "SELECT 1"); i.instance_variable_set(:@raw_result_available, true)
  if i.instance_variable_defined?(:@async) then i.instance_variable_set(:@async, QI::AsyncState.new(sess, Mutex.new)) else i.instance_variable_set(:@session, sess); i.instance_variable_set(:@mutex, Mutex.new) end
  if i.instance_variable_get(:@async).respond_to?(:lock_wait=) then i.instance_variable_get(:@async).lock_wait = 17 else i.instance_variable_set(:@lock_wait, 17) end; i }
o = mk.(); d = o.dup; d.send(:execute_or_wait); puts "dup: original lock_wait=#{o.lock_wait.inspect} copy=#{d.lock_wait.inspect}"
f = mk.().freeze; puts "frozen: #{(f.send(:execute_or_wait).inspect rescue $!.class)}"
i = QI.new(adapter: c, raw_sql: "SELECT 1"); puts "ivars=#{i.instance_variables.size} memsize=#{ObjectSpace.memsize_of(i)} #{RUBY_VERSION}"
