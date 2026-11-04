require "bundler/setup"
$LOAD_PATH.unshift File.join(ENV["RAILS"], "activesupport", "lib")
require "active_support"; require "active_support/core_ext/time"
class CountingZone
  attr_reader :calls
  def initialize(z) = (@z = z; @calls = Hash.new(0))
  def utc_to_local(t) = (@calls[:u2l] += 1; @z.utc_to_local(t))
  def local_to_utc(t) = (@calls[:l2u] += 1; @z.local_to_utc(t))
  def abbr(t) = (@calls[:abbr] += 1; @z.abbr(t))
  def dst?(t) = (@calls[:dst] += 1; @z.dst?(t))
end
c = CountingZone.new(TZInfo::Timezone.get("Europe/Berlin"))
t = Time.utc(2026, 1, 15, 12).getlocal(c)
[{ nsec: 5 }, { month: 7 }, { month: 10, day: 25, hour: 2 }].each do |o|
  c.calls.clear; r = t.change(o); puts "#{o} -> #{r} #{c.calls.sort.to_h}"
end
p TZInfo::DataSource.get.class
