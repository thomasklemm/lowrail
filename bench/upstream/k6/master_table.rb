# master_table.rb DIR: medians over DIR, DIR/rep1 and DIR/rep2 (sweep.sh output on Ruby master) per tree and mode,
# with the A/A (main2 vs main), K6 vs main, objects, and jit and invalidation ns summed over every window.
dir = ARGV[0]
runs = [dir, "#{dir}/rep1", "#{dir}/rep2"].select { Dir.exist?(_1) }
read = ->(d, tree, mode) do
  f = File.join(d, "#{tree}-#{mode}.txt")
  File.exist?(f) ? File.readlines(f).to_h { |l| c, ir, obj, jit, _n, inv = l.split; [c, { ir: Float(ir), obj: Float(obj), jit: Integer(jit), inv: inv.to_i }] } : {}
end
med = ->(a) { s = a.sort; s[s.size / 2] }
fmt = ->(x) { x.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
pct = ->(a, b) { format("%+.2f%%", (a / b - 1) * 100).sub("-", "−") }
%w[zjit interp].each do |mode|
  data = %w[main main2 k6].to_h { |t| [t, runs.map { read.(_1, t, mode) }] }
  puts "## #{mode} (#{runs.size} runs)"
  data["main"].first.each_key do |c|
    v = data.transform_values { |rs| rs.map { _1[c] }.compact }
    next if v.values.any?(&:empty?)
    m, m2, k = %w[main main2 k6].map { |t| med.(v[t].map { _1[:ir] }) }
    jit = v.values.flatten.sum { _1[:jit] }; inv = v.values.flatten.sum { _1[:inv] }
    spread = v.transform_values { |a| a.map { _1[:ir] }.minmax.map(&:round).join("–") }
    puts format("%-18s main %s A/A %s K6 %s (%s) obj %s→%s jit %d inval %d | %s", c, fmt.(m), pct.(m2, m), fmt.(k), pct.(k, m),
                v["main"][0][:obj], v["k6"][0][:obj], jit, inv, spread.map { "#{_1} #{_2}" }.join(", "))
  end
end
