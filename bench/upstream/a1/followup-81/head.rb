rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
adapter = ENV.fetch("ADAPTER", "sqlite3")
ActiveRecord::Base.establish_connection(adapter: adapter, database: adapter == "sqlite3" ? ":memory:" : ENV.fetch("DATABASE"))
ActiveRecord::Schema.verbose = false
def keep(flag) = (ActiveRecord.association_scope_keeps_owner_conditions = flag if ActiveRecord.respond_to?(:association_scope_keeps_owner_conditions=))
