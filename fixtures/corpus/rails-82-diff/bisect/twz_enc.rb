require "active_support/all"
puts Time.at(0).in_time_zone("UTC").to_s.encoding == Encoding::US_ASCII ? "NEW" : "OLD"
