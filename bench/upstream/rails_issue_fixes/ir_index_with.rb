require "active_support"; require "active_support/core_ext/enumerable"
a = %w[id title body]
GC.disable
n = Integer(ARGV[0]); i = 0
while i < n; a.index_with(nil); i += 1; end
