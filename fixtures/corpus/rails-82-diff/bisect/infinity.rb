require "active_support/all"
puts ActiveSupport::NumberHelper.number_to_delimited(Float::INFINITY) == "Infinity" ? "NEW" : "OLD"
