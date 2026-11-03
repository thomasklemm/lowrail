d = "/tmp/w/r7o/ir"
ir = ->(c, v, m, n) { File.read("#{d}/#{c}-#{v}-#{m}-#{n}.out")[/Collected : (\d+)/, 1].to_i }
per = ->(c, v, m) { (ir.(c, v, m, 5000) - ir.(c, v, m, 0)) / 5000.0 }
%w[hash_as_json to_json_except render_json_hash].each do |c|
  %w[i49 y49 i41 z41].each do |m|
    a, b, x = per.(c, "main", m), per.(c, "aa", m), per.(c, "cand", m)
    printf("| %s | %s | %s | %+.2f%% | %s | %+d | %+.2f%% |\n", c, m, a.round, (b / a - 1) * 100, x.round, (x - a).round, (x / a - 1) * 100)
  end
end
