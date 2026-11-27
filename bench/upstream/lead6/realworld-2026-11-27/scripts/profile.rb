# frozen_string_literal: true

# stackprof (cpu, 20µs) of one case: share of samples in which selected methods are
# on the stack (inclusive) and on top (self).
require "stackprof"
require_relative "setup_model"

name = ENV.fetch("CASE", "update")
call = l6_cases.fetch(name)
3000.times { call.call }
prof = StackProf.run(mode: :cpu, interval: 20, raw: true) { 20_000.times { call.call } }
frames = prof[:frames]
total = prof[:samples]
raw = prof[:raw]
incl = Hash.new(0)
selfc = Hash.new(0)
i = 0
while i < raw.size
  len = raw[i]
  stack = raw[i + 1, len]
  n = raw[i + 1 + len]
  stack.map { frames[_1][:name] }.uniq.each { incl[_1] += n }
  selfc[frames[stack.last][:name]] += n
  i += len + 2
end
pat = Regexp.new(ENV.fetch("PAT", "AttributeSet|AttributeMutationTracker|Dirty|forgetting|Attribute#|Attribute::|changes_applied|materialize|IndexedRow"))
puts "# #{name}, COLS=#{COLS}, #{RUBY_DESCRIPTION}, #{total} samples"
puts "## inclusive (top 40 matching)"
incl.select { |k, _| k =~ pat }.sort_by { -_2 }.first(40).each { |k, v| puts format("%6.2f%%  %s", 100.0 * v / total, k) }
puts "## self (top 25 overall)"
selfc.sort_by { -_2 }.first(25).each { |k, v| puts format("%6.2f%%  %s", 100.0 * v / total, k) }
