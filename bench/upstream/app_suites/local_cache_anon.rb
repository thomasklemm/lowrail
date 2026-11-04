require "active_support"
require "active_support/cache"
store = Class.new(ActiveSupport::Cache::MemoryStore).new
store.write("k", 1)
p read: store.read("k")
store.with_local_cache { store.write("j", 2); p local: store.read("j") }
p ok: ActiveSupport.version.to_s
