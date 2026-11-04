require "bundler/setup"
require "active_support"; require "active_support/core_ext/time"
CASE, N = ARGV[0], Integer(ARGV[1])
Z = ARGV[2] == "tz" ? TZInfo::Timezone.get("Europe/Berlin") : ActiveSupport::TimeZone["Europe/Berlin"]
S = Rational(1234567, 1000000)
UT = Time.utc(2026, 1, 15, 12, 0, S)
SH = UT - 3600
ZT = SH.getlocal(Z)
CASES = {
  "utc" => -> { ::Time.utc(2026, 1, 15, 12, 0, S) },
  "minus" => -> { UT - 3600 },
  "getlocal" => -> { SH.getlocal(Z) },
  "new_zone" => -> { ::Time.new(2026, 1, 15, 12, 0, S, Z) },
  "new_int" => -> { ::Time.new(2026, 1, 15, 12, 0, S, 3600) },
  "utc_offset" => -> { ZT.utc_offset },
  "at_in" => -> { ::Time.at(SH, in: Z) },
}
f = CASES.fetch(CASE)
3000.times { f.() }
GC.start; GC.disable
[0].cycle(1) { N.times { f.() } }
