require "active_support/all"
puts ActiveSupport::NumberHelper.number_to_rounded(1.5).encoding == Encoding::UTF_8 ? "NEW" : "OLD"
