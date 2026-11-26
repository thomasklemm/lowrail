# ruby split_runs.rb LOG...: per-test outcomes like M4's outcomes.rb, but a capture's log is split at
# lowrail-profile's "run N of M" lines, so each run gets its own NAME.runN.outcomes (plain logs: NAME.outcomes).
def outcomes(lines)
  # A parallel worker's warning can split "Class#test = " from its "0.12 s = ." on the next line.
  lines = lines.each_with_index.map { |l, i| l.match?(/\A\S+#\S+ = (?![\d.]+ s = )/) && lines[i + 1].to_s.match?(/\A[\d.]+ s = [.SEF]\z/) ? l.sub(/ = .*/, " = #{lines[i + 1]}") : l }
  tests = lines.grep(/\A\S+#\S+ = [\d.]+ s = [.SEF]\z/).map { _1.sub(/ = [\d.]+ s = /, " = ") }
  mask = ->(l) { l.gsub(/TimeWithZone [^>]*>/, "TimeWithZone T>").gsub(/(short_id|token): "[^"]*"/, '\\1: "X"') }
  tests = lines.select { _1.match?(/\A {2,}\S/) && !_1.match?(/\A\s+(#|Finished|Failures|\d+\))/) }.map { mask.(_1.strip) } if tests.empty?
  tests.sort.uniq
end

ARGV.each do |log|
  lines = File.readlines(log, chomp: true, invalid: :replace)
  name = log.sub(/\.log\z/, "")
  parts = lines.slice_before { _1.match?(/\Alowrail-profile: run \d+ of \d+:/) }.to_a
  parts.shift unless parts.first&.first&.match?(/\Alowrail-profile: run/)
  parts = [lines] if parts.empty?
  parts.each_with_index do |part, i|
    file = parts.size > 1 || part.first.to_s.start_with?("lowrail-profile: run") ? "#{name}.run#{i + 1}.outcomes" : "#{name}.outcomes"
    t = outcomes(part)
    File.write(file, t.join("\n") + "\n")
    puts "#{File.basename(file)}: #{t.size} outcomes; #{part.grep(/(runs|examples), /).last}"
  end
end
