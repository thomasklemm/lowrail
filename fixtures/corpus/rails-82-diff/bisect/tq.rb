require "active_support/all"
puts({ q: [[]], a: 1 }.to_query == "&a=1" ? "NEW" : "OLD")
