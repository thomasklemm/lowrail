# Mirrors railties/Rakefile's per-file CI step: load tools/strict_warnings, then load the test file.
# Run from railties/ with: RAILS_STRICT_WARNINGS=1 bundle exec ruby -w -Ilib -Itest strict_ci.rb FILE [minitest args]
file = ARGV.shift
require "../tools/strict_warnings"
load file
