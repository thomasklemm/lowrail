# per.rb TAG "scen:n1:n2 ..." -> per-iteration Ir from cachegrind summaries
tag = ARGV[0]
ARGV[1..].each do |x|
  s, a, b = x.split(":")
  ir = ->(n) { File.read("/tmp/cg/#{tag}.#{s}.#{n}.out")[/^summary: (\d+)/, 1].to_i }
  printf "%-14s %16s\n", s, ((ir.(b) - ir.(a)) / (b.to_i - a.to_i)).to_s.reverse.scan(/\d{1,3}/).join(",").reverse
end
