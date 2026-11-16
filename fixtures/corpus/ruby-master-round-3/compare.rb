# Compares `rails test -v` logs of one app across labels, per test by name, plus warning lines.
# usage: ruby compare.rb NAME [BASE=r409] [OTHER...=master zjit]   (logs in $R3/runs/LABEL/NAME.log)
# Prints totals, every test whose result differs from BASE, the failure message for each, and warning lines
# that appear in OTHER but not in BASE. A master-only failure is one that passes (".") on BASE.
r3 = ENV.fetch("R3", File.expand_path("~/Code/lowrail-bench/r3"))
name, base, *others = ARGV
base ||= "r409"
others = %w[master zjit] if others.empty?

def norm(line)
  line.gsub(%r{/Users/[^\s:]*/(?:bundle/ruby/[^/]+/(?:bundler/)?gems|lib/ruby/(?:gems/)?[\d.]+(?:/gems)?)/}, "GEMS/")
      .gsub(%r{/Users/[^\s:]*/\.corpus/[^/]+/}, "APP/")
      .gsub(/0x\h+/, "0xX").gsub(%r{/(?:var/folders|tmp)/[\w./-]+}, "/TMP").gsub(/\d+\.\d+ s\b/, "N s").gsub(/\bPID \d+/, "PID N")
      .gsub(/#<(\w+(?:::\w+)*):0xX[^>]*>/, '#<\1>').strip
end

def parse(path)
  text = File.binread(path).force_encoding("UTF-8").scrub
  lines = text.lines
  results = {}
  # A warning printed by a worker can land between a test's name and its result, so match across lines.
  text.scan(/^(\S+#\S+) = (?:[^\n]*\n)*?[^\n]*?[\d.]+ s = ([.FES])[ \t]*$/) { |t, r| results[t] = r }
  msgs = {}
  lines.each_with_index do |l, i|
    next unless l =~ /^\s*(?:\d+\) )?(Failure|Error):\s*$/
    id = lines[i + 1].to_s.strip.sub(/ \[.*\]:?\z/, "").sub(/:\z/, "")
    msgs[id] ||= norm(lines[i + 2].to_s)[0, 240]
  end
  warns = lines.grep(/warning:|DEPRECATION/i).map { |w| norm(w) }.tally
  bugs = lines.grep(/\[BUG\]|Segmentation fault|panicked/).map { |b| norm(b) }.uniq
  total = lines.grep(/^\d+ (?:runs|examples?), /).last.to_s.strip
  json = path.sub(/\.log\z/, ".json")
  if File.exist?(json)
    require "json"
    JSON.parse(File.read(json))["examples"].each do |e|
      id = "#{e["file_path"]} #{e["full_description"]}"
      results[id] = { "passed" => ".", "failed" => "F", "pending" => "S" }.fetch(e["status"])
      msgs[id] = norm("#{e.dig("exception", "class")}: #{e.dig("exception", "message")}")[0, 240] if e["exception"]
    end
  end
  { results:, msgs:, warns:, bugs:, total: }
end

runs = ([base] + others).to_h do |lab|
  path = "#{r3}/runs/#{lab}/#{name}.log"
  [lab, File.exist?(path) ? parse(path) : nil]
end
puts "## #{name}"
runs.each { |lab, r| puts "  #{lab}: #{r ? "#{r[:total]} (#{r[:results].size} named)" : "missing"}" }
ref = runs[base] or exit
others.each do |lab|
  r = runs[lab] or next
  (ref[:results].keys | r[:results].keys).sort.each do |t|
    a, b = ref[:results][t], r[:results][t]
    next if a == b
    tag = a == "." && %w[F E].include?(b) ? "MASTER-ONLY" : "differs"
    puts "  #{tag} #{lab}: #{t} #{base}=#{a.inspect} #{lab}=#{b.inspect}"
    puts "      #{lab}: #{r[:msgs][t]}" if r[:msgs][t]
    puts "      #{base}: #{ref[:msgs][t]}" if ref[:msgs][t]
  end
  (r[:warns].keys - ref[:warns].keys).each { |w| puts "  new warning #{lab} (x#{r[:warns][w]}): #{w[0, 260]}" }
  r[:bugs].each { |b| puts "  BUG #{lab}: #{b[0, 200]}" }
end
if ENV["SHOW_BASE"]
  ref[:results].select { |_, v| v != "." }.each { |t, v| puts "  #{base} #{v}: #{t} #{ref[:msgs][t]}" }
end
