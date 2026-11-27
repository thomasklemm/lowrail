# frozen_string_literal: true

# Differences between two detail runs' aggregates (dump.rb output):
#   ruby diff.rb BASE.dump.json HEAD.dump.json [SNAPSHOT=boot] [SECTION=by_owner_type] [N=25]
# Prints the keys whose bytes changed most, HEAD minus BASE.
require "json"

base, head, snap, section, n = ARGV
snap ||= "boot"
section ||= "by_owner_type"
n = Integer(n || 25)
read = ->(path) { JSON.parse(File.read(path)).dig("snapshots", snap, section).to_h { [_1["key"], _1] } }
a = read.(base)
b = read.(head)
rows = (a.keys | b.keys).map do |k|
  [k, b.dig(k, "bytes").to_i - a.dig(k, "bytes").to_i, b.dig(k, "count").to_i - a.dig(k, "count").to_i, a.dig(k, "bytes").to_i]
end
total = rows.sum { _2 }
puts format("%-70s %12s %9s %12s", "#{section} (#{snap})", "Δ bytes", "Δ count", "base bytes")
rows.sort_by { -_2.abs }.first(n).each { |k, d, c, base_bytes| puts format("%-70s %+12d %+9d %12d", k[0, 70], d, c, base_bytes) }
puts format("%-70s %+12d (listed keys only: top %d of each side)", "sum", total, a.size)
