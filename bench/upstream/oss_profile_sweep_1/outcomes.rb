# outcomes.rb LOG [RUN]: per-test outcomes from a minitest -v or rspec documentation log.
# With RUN, takes the part of a lowrail-profile log after "run RUN of".
log = File.read(ARGV[0], mode: "rb").force_encoding("UTF-8").scrub
if ARGV[1]
  parts = log.split(/^lowrail-profile: run (\d+) of \d+:.*$/)
  i = parts.index(ARGV[1]) or abort "no run #{ARGV[1]}"
  log = parts[i + 1]
end
log = log.gsub(/\e\[[\d;]*m/, "")
# Ruby warnings written mid-line (stderr into the same log) split a minitest result line.
log = log.gsub(%r{(?:/\S+:\d+: warning: [^\n]*\n)+}, "")
log = log.split(/^(Pending:|Failures:|Finished in )/).first if log.match?(/^\d+ examples?, /)
lines = log.lines.filter_map do |l|
  l = l.chomp
  if (m = l.match(/^(\S+#\S+) = [\d.]+ s = (\S)$/)) then "#{m[1]} #{m[2]}"   # minitest -v
  elsif l.match?(/^\s+\S.*/) && !l.match?(/^\s+(#|Failure|\d+\)|expected|got|Got|Diff|On line|# )/) then l.sub(/ \(FAILED - \d+\)/, " FAILED").rstrip  # rspec doc
  end
end
puts(lines.any? { _1.match?(/\A\S+#\S+ \S\z/) } ? lines.sort : lines)
