# ruby outcomes.rb LOG...: per-test outcomes of a verbose Minitest or RSpec documentation log, sorted,
# without times (Minitest: "Class#test = 0.12 s = ."; RSpec: the example lines, with the failure markers).
ARGV.each do |log|
  lines = File.readlines(log, chomp: true)
  tests = lines.grep(/\A\S+#\S+ = [\d.]+ s = [.SEF]\z/).map { _1.sub(/ = [\d.]+ s = /, " = ") }
  # RSpec: timestamps, random tokens and short ids masked (they differ between any two runs).
  mask = ->(l) { l.gsub(/TimeWithZone [^>]*>/, "TimeWithZone T>").gsub(/(short_id|token): "[^"]*"/, '\\1: "X"') }
  tests = lines.select { _1.match?(/\A {2,}\S/) && !_1.match?(/\A\s+(#|Finished|Failures|\d+\))/) }.map { mask.(_1.strip) } if tests.empty?
  File.write(log.sub(/\.log\z/, ".outcomes"), tests.sort.uniq.join("\n") + "\n")
  puts "#{log}: #{tests.sort.uniq.size} outcomes; #{lines.grep(/(runs|examples), /).last}"
end
