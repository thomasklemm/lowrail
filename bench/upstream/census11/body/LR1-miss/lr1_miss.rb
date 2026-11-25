# frozen_string_literal: true

# LR1 adverse control (script/upstream-bench): every call is a fresh execution context, so the new
# lock-free lookup always misses before the locked lookup creates the lease.
require "active_support/all"
require "active_record"

ActiveSupport::IsolatedExecutionState.isolation_level = :fiber
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Base.lease_connection.select_value("SELECT 1")

leases = ActiveRecord::Base.connection_pool.instance_variable_get(:@leases)

UpstreamBench.report("fresh fiber with_connection") { Fiber.new { ActiveRecord::Base.with_connection { } }.resume }
UpstreamBench.report("fresh fiber") { Fiber.new { }.resume }
UpstreamBench.report("registry miss, new key") { leases.lease(Object.new) }
