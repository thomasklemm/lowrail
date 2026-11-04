require "active_support"
require "active_support/core_ext/enumerable"
class Tens < Array
  def each(&) = super { |x| yield x * 10 }
end
p ActiveSupport.version.to_s, Tens[1, 2].index_with { _1 }, Tens[1, 2].index_with(0), Tens[1, 2].index_with.to_a rescue p $!
