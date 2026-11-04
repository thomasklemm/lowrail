# frozen_string_literal: true

# ruby eco-locks.rb LOCK_81 LOCK_MAIN: gems whose locked version differs between the two locks, Rails components
# excluded (they come from the two checkouts). Prints "same" when only Rails differs.
require "bundler"
RAILS = %w[rails railties activesupport activemodel activerecord actionpack actionview actionmailer activejob
  actioncable activestorage actionmailbox actiontext].freeze
specs = ->(path) { Bundler::LockfileParser.new(File.read(path)).specs.to_h { [_1.name, _1.version.to_s] }.reject { RAILS.include?(_1) } }
a, b = ARGV.map(&specs)
diff = (a.keys | b.keys).sort.filter_map { |n| "#{n}: #{a[n] || "-"} -> #{b[n] || "-"}" if a[n] != b[n] }
puts diff.empty? ? "same" : diff
