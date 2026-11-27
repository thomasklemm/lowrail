# frozen_string_literal: true

# Writes a stackprof raw profile as gzipped folded stacks ("frame;frame;... weight", root first, identical
# stacks summed), the archive form kept in Git for docs/upstream/test-overhead-2.md: method names only, and the
# leaf's file reduced to its gem, Rails test helper or Ruby library ("@gem/name", "@testing", "@ruby", "@app") as a last element, which is what
# rank.rb's rules read. Folded stacks also feed flame graph tools.
#   ruby fold.rb RUN.PID.stackprof OUT.folded.gz
require "zlib"

# Rails' own test helpers, kept apart from the rest of their gem (rank.rb's test framework rule).
TESTING = %r{/active_support/testing/|/active_record/test_fixtures|/action_dispatch/testing/|/action_controller/test_case|/active_job/test_helper|/rails/test_unit/}

data = Marshal.load(File.binread(ARGV.fetch(0)))
frames, raw = data.fetch(:frames), data.fetch(:raw)
label = Hash.new { |h, id| h[id] = frames[id][:name].to_s.tr(";", ",") }
where = Hash.new do |h, id|
  file = frames[id][:file].to_s
  h[id] = if file.empty? || file.start_with?("<") then nil
  elsif file.match?(TESTING) then "@testing"
  elsif (m = file.match(%r{/(?:bundler/)?gems/([^/]+?)-(?:\d[^/]*|\h{12})/(?:([a-z]+)/lib/)?})) then "@gem/#{m[2] || m[1]}"
  elsif file.match?(%r{/lib/ruby/\d}) then "@ruby"
  else "@app"
  end
end
folded = Hash.new(0)
i = 0
while (len = raw[i])
  stack = raw[i + 1, len]
  leaf = stack.reverse_each.lazy.map { where[_1] }.find(&:itself) || "@none"
  folded[(stack.map { label[_1] } << leaf).join(";")] += raw[i + 1 + len]
  i += len + 2
end
Zlib::GzipWriter.open(ARGV.fetch(1), Zlib::BEST_COMPRESSION, mtime: 0) do |gz|
  folded.sort.each { |stack, w| gz.puts "#{stack} #{w}" }
end
