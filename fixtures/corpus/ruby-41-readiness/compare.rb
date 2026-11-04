# Compares Rails (or gem) suite logs across labels: totals, failing test
# identities, and warning lines, each normalized so paths match across Rubies.
# usage: ruby compare.rb DIR_PATTERN... (e.g. r409 master zjit) [--gems]
gems = ARGV.delete("--gems")
labels = ARGV
base = File.expand_path("~/src/runs")

def norm(line)
  line.gsub(%r{/home/user/src/(?:bundle|gems-bundle)/ruby/[^/]+/(?:bundler/)?gems/}, "GEMS/")
      .gsub(%r{/home/user/(?:\.local/share/mise/installs/ruby/[^/]+|rubies/master)/lib/ruby/(?:gems/)?[^/]+/(?:gems/)?}, "RUBYLIB/")
      .gsub(%r{/home/user/src/(rails-main|gems)/}, "")
      .gsub(/0x\h+/, "0xX").gsub(%r{/tmp/[\w.-]+}, "/tmp/X").gsub(/\d+\.\d+s\b/, "Ns").strip
end

def parse(path)
  text = File.binread(path).force_encoding("UTF-8").scrub
  lines = text.lines
  totals = lines.grep(/^\d+ (runs|examples|tests)/).map(&:strip)
  totals += lines.grep(/^\d+ examples?, \d+ failures?/).map(&:strip)
  fails = []
  lines.each_with_index do |l, i|
    if l =~ /^\s*(?:\d+\) )?(Failure|Error):\s*$/
      id = lines[i + 1].to_s.strip.sub(/ \[.*\]:?\z/, "").sub(/:\z/, "")
      msg = lines[i + 2].to_s.strip
      fails << "#{$1}: #{id} -- #{norm(msg)[0, 160]}"
    elsif l =~ /^rspec \.\/(\S+)/
      fails << "rspec: #{$1} #{l.split('#', 2)[1].to_s.strip[0, 120]}"
    end
  end
  warns = lines.grep(/warning:/).map { |l| norm(l) }.tally
  bugs = lines.grep(/\[BUG\]/).map { |l| norm(l) }
  { totals: totals.uniq, fails: fails.uniq.sort, warns: warns, bugs: bugs.uniq }
end

files = if gems
  Dir["#{base}/gems/*-#{labels.first}.log"].map { |f| File.basename(f).sub(/-#{labels.first}\.log\z/, "") }.sort
else
  Dir["#{base}/#{labels.first}/*.log"].map { |f| File.basename(f, ".log") }.sort
end
files.each do |comp|
  res = labels.to_h do |lab|
    path = gems ? "#{base}/gems/#{comp}-#{lab}.log" : "#{base}/#{lab}/#{comp}.log"
    [lab, File.exist?(path) ? parse(path) : nil]
  end
  puts "## #{comp}"
  res.each { |lab, r| puts "  #{lab}: #{r ? r[:totals].join(' | ') : 'missing'}" }
  ref = res[labels.first]
  next unless ref
  res.each do |lab, r|
    next if r.nil? || lab == labels.first
    (r[:fails] - ref[:fails]).each { |f| puts "  only #{lab}: #{f}" }
    (ref[:fails] - r[:fails]).each { |f| puts "  only #{labels.first} (vs #{lab}): #{f}" }
    (r[:warns].keys - ref[:warns].keys).each { |w| puts "  new warning #{lab} (x#{r[:warns][w]}): #{w[0, 220]}" }
    r[:bugs].each { |b| puts "  BUG #{lab}: #{b[0, 200]}" }
  end
  ref[:fails].each { |f| puts "  in #{labels.first}: #{f}" } if ENV["SHOW_BASE"]
end
