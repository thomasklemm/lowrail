# Plain Ruby, no Rails: Date#<=> raises for a NaN instead of returning nil.
# Expected (as for Integer, Rational and Time): nil from <=>, false from ==.
require "date"
require "bigdecimal"
d = Date.new(2026, 11, 4)
[Float::NAN, BigDecimal("NaN")].each do |nan|
  [[:<=>, nil], [:==, false]].each do |op, expected|
    got = begin
      d.public_send(op, nan).inspect
    rescue => e
      "#{e.class}: #{e.message}"
    end
    puts "Date #{op} #{nan.class} NaN: #{got} (expected #{expected.inspect}; 1 #{op} it gives #{(1.public_send(op, nan)).inspect})"
  end
end
