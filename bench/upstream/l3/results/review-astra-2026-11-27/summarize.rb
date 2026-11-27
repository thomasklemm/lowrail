require "json"

%w[body-ips sizes large].each do |file|
  groups = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = {} } }
  group = tree = nil
  File.foreach(File.join(__dir__, "#{file}.txt")) do |line|
    if line =~ /^=== (body|large) (\w+) round \d+ ===/
      group, tree = $1, $2
    elsif line =~ /^=== (interp|yjit) (\d+) (\w+) ===/
      group, tree = "#{$1} width=#{$2}", $3
    elsif line =~ /^\s*(.+?)\s+([\d.]+)([kM]?) \(.*i\/s/
      name = $1
      ips = $2.to_f * { "" => 1, "k" => 1_000, "M" => 1_000_000 }.fetch($3)
      row = groups[group][name]
      row[tree] = [row.fetch(tree, 0), ips].max
    end
  end
  groups.each do |group_name, rows|
    rows.each do |name, row|
      puts JSON.generate(group: group_name, operation: name, ips: row,
        head_percent: ((row.fetch("head") / row.fetch("main") - 1) * 100).round(2),
        aa_percent: ((row.fetch("main2") / row.fetch("main") - 1) * 100).round(2))
    end
  end
end
