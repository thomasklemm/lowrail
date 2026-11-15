require "active_support/ordered_options"
base = ActiveSupport::OrderedOptions.new
base.asset_host = "x"
mid = ActiveSupport::InheritableOptions.new(base)
leaf = ActiveSupport::InheritableOptions.new(mid)
n = Integer(ENV.fetch("N"))
i = 0
while i < n
  leaf[:asset_host]
  i += 1
end
p leaf[:asset_host]
