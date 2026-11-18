require "json"
rows = Hash.new { |h, k| h[k] = { tests: nil, rel: [], dbg: [] } }
total_exec = 0; runs = 0; missing = []
Dir["out/{rel,dbg,rel-main,dbg-main}/*/"].sort.each do |d|
  build = d[%r{out/(rel|dbg)}, 1]; suite = File.basename(d)
  Dir["#{d}*.log"].sort.each do |log|
    mode = File.basename(log, ".log")
    js = log.sub(/\.log\z/, ".json")
    n = if File.exist?(js)
      (JSON.parse(File.read(js))["tests"].size rescue nil)
    else
      s = File.read(log, encoding: "binary").scrub
      (s.scan(/^(\d+) tests, \d+ assertions/).last || s.scan(/^\d+ files?, (\d+) examples/).last || s.scan(/PASS all (\d+) tests/).last || s.scan(/^FAIL \d+\/(\d+) tests/).last)&.first&.to_i ||
        (suite == "ruby-test-bundled-gems" ? s.scan(/Testing the (\S+) gem/).uniq.size : nil)
    end
    if n.nil? then missing << log; next end
    runs += 1; total_exec += n
    rows[suite][:tests] ||= n if mode == "interp-0"
    rows[suite][build.to_sym] << mode
  end
end
rows.each { |s, r| puts "#{s}: tests=#{r[:tests]} rel=#{r[:rel].size} dbg=#{r[:dbg].size}" }
puts "runs=#{runs} executions=#{total_exec}"
puts "missing: #{missing}" unless missing.empty?
