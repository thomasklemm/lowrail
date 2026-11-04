# Times fetch_multi with five misses on MemCacheStore; run with Dalli 4.3.3 (binary protocol) against 8.1 and main.
require "active_support"; require "active_support/cache"; require "dalli"
s = ActiveSupport::Cache::MemCacheStore.new("localhost:11290", namespace: "fm-#{rand(1e9)}")
a = Process.clock_gettime(Process::CLOCK_MONOTONIC)
r = s.fetch_multi(*Array.new(5) { "k#{_1}" }) { |k| k.upcase }
b = Process.clock_gettime(Process::CLOCK_MONOTONIC)
puts format("fetch_multi 5 misses %.2fs %p; reread %p", b - a, r.values, s.read_multi("k0", "k4"))
