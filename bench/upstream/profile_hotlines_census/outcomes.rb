# ruby outcomes.rb LOG...: per-test outcomes of a verbose Minitest or RSpec documentation log (as in
# profile_release/2026-11-25/scripts/outcomes.rb: no times, RSpec timestamps and tokens masked), written to
# LOG.outcomes as "COUNT\tOUTCOME", sorted. A profiled log holds every run (2 unless --runs), so each outcome
# counts once per run there. Then, per profiled log, whether it is plain's outcomes exactly once per run.
counts = {}
ARGV.each do |log|
  lines = File.readlines(log, chomp: true).map(&:scrub)
  tests = lines.grep(/\A\S+#\S+ = [\d.]+ s = [.SEF]\z/).map { _1.sub(/ = [\d.]+ s = /, " = ") }
  mask = ->(l) { l.gsub(/TimeWithZone [^>]*>/, "TimeWithZone T>").gsub(/(short_id|token): "[^"]*"/, '\\1: "X"').gsub(/\(FAILED - \d+\)/, "(FAILED)").gsub(/\d+/, "N") }
  tests = lines.select { _1.match?(/\A {2,}\S/) && !_1.match?(/\A\s+(#|Finished|Failures|\d+\)|Failure\/Error|expected|got|Diff|\+|-|@@|\.\/|\/)/) }.map { mask.(_1.strip) } if tests.empty?
  tally = tests.tally.sort.to_h
  counts[log] = tally
  File.write(log.sub(/\.log\z/, ".outcomes"), tally.map { "#{_2}\t#{_1}" }.join("\n") + "\n")
  totals = lines.grep(/\A\d+ (runs|examples), /)
  puts "#{File.basename(log)}: #{tally.size} distinct outcomes, #{tests.size} lines; #{totals.join(' | ')}"
end
plain = counts.find { File.basename(_1[0]) == "plain.log" }&.last
counts.each do |log, tally|
  next unless File.basename(log).start_with?("profiled") && plain
  runs = [(tally.values.sum.fdiv([plain.values.sum, 1].max)).round, 1].max
  doubled = plain.transform_values { _1 * runs }
  if tally == doubled
    puts "#{File.basename(log)}: identical to plain (each of #{plain.size} outcomes in all #{runs} runs)"
  else
    diff = (doubled.keys | tally.keys).filter_map { |k| [k, doubled[k].to_i.fdiv(runs), tally[k].to_i.fdiv(runs)] unless doubled[k] == tally[k] }
    puts "#{File.basename(log)}: DIFFERS from plain in #{diff.size} outcomes (plain count, profiled per run):"
    diff.first(15).each { |k, a, b| puts "  #{a} #{b} #{k}" }
  end
end
