# Compares TimezoneTransition#== / eql? / hash on the loaded tzinfo with the
# expression on tzinfo master, over every transition up to 2100 of every zone of
# the active data source.
require "bundler/setup"
require "tzinfo"
require "digest"

OLD = ->(a, b) { b.kind_of?(TZInfo::TimezoneTransition) && a.offset == b.offset && a.previous_offset == b.previous_offset && a.timestamp_value == b.timestamp_value }

src = TZInfo::DataSource.get
digest = Digest::SHA256.new
n = mism = 0
others = [nil, 1, "x", Object.new, TZInfo::TimezoneOffset.new(0, 0, "UTC")]
to = TZInfo::Timestamp.create(2100, 1, 1, 0, 0, 0, 0, :utc)
src.timezone_identifiers.each do |id|
  a = src.get_timezone_info(id)
  next unless a.respond_to?(:transitions_up_to)
  ta = a.transitions_up_to(to)
  tb = ta.map { |t| TZInfo::TimezoneTransition.new(t.offset, t.previous_offset, t.timestamp_value) } # equal, not identical
  tc = ta.map { |t| TZInfo::TimezoneTransition.new(TZInfo::TimezoneOffset.new(t.offset.base_utc_offset, t.offset.std_offset, t.offset.abbreviation.dup), t.previous_offset, t.timestamp_value) }
  ta.each_with_index do |t, i|
    cands = [t, tb[i], tc[i], ta[i - 1], ta[i + 1], tb[i + 1], *others].compact
    cands.each do |u|
      old = OLD.(t, u); new = (t == u); e = t.eql?(u)
      n += 1
      mism += 1 if old != new || new != e || (new && t.hash != u.hash)
      digest << "#{id} #{i} #{new}\n"
    end
  end
  # periods as Active Support sees them: distinct objects sharing transitions
  [2026, 2027].each do |y|
    p1 = a.periods_for_local(TZInfo::Timestamp.create(y, 7, 1, 12)).first
    p2 = a.periods_for_local(TZInfo::Timestamp.create(y, 7, 1, 13)).first
    next unless p1 && p2
    digest << "#{id} #{y} #{p1 == p2} #{p1.eql?(p2)} #{p1.hash == p2.hash}\n"
  end
end
puts "#{src.class} zones=#{src.timezone_identifiers.size} comparisons=#{n} mismatches=#{mism} sha=#{digest.hexdigest[0, 16]}"
