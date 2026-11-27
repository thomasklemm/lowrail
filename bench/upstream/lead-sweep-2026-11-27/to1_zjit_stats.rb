# frozen_string_literal: true
# TO1: ZJIT stats for f.text_field alone (ARGV[0] = Rails tree), counters after warm-up only.
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord actionview actionpack].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
UpstreamBench = Module.new { def self.report(name, &b) = (@cases ||= {})[name] = b; def self.cases = @cases }
load File.expand_path("to1_zjit.rb", __dir__)
c = UpstreamBench.cases.fetch(ENV.fetch("CASE", "f.text_field"))
20_000.times { c.call }
RubyVM::ZJIT.reset_stats!
20_000.times { c.call }
s = RubyVM::ZJIT.stats
s.sort.each { |k, v| puts "#{k} #{v}" if v.is_a?(Integer) && v != 0 }
