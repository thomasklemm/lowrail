# frozen_string_literal: true

# What plain Mash.new costs under ZJIT after a quiet subclass ran the same methods first, and after it ran alone.
# Usage: ruby --zjit --zjit-stats -I HASHIE/lib zjit_mixed.rb [quiet-first|plain-only|plain-first]
require 'hashie'
require 'json'
require 'logger'

Hashie.logger = Logger.new(nil)

class QuietMash < Hashie::Mash
  disable_warnings
end

REPO = JSON.parse(File.read(File.expand_path('../fixtures/github-org-repos.json', __dir__))).first
order = ARGV.fetch(0)
3000.times { QuietMash.new(REPO) } if order == 'quiet-first'
3000.times { Hashie::Mash.new(REPO) }
3000.times { QuietMash.new(REPO) } if order == 'plain-first'
3000.times { Hashie::Mash.new(REPO) }

GC.start
GC.disable
before = RubyVM::ZJIT.stats
t = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID)
2000.times { Hashie::Mash.new(REPO) }
elapsed = Process.clock_gettime(Process::CLOCK_THREAD_CPUTIME_ID) - t
after = RubyVM::ZJIT.stats
puts format('%s: Mash.new %.1f us', order, elapsed * 1e6 / 2000)
after.each do |key, value|
  delta = value.is_a?(Numeric) ? value - before[key].to_i : 0
  next unless delta.positive? && key.to_s.match?(/fallback|side_exit|dynamic_send|^send_count|optimized_send_count$|not_inlined|exit_/)

  puts format('  %-52s %10.1f per call', key, delta / 2000.0)
end
