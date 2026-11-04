# ruby cmpx.rb out/TAG [--show N]: compares the four reads (reader-from-writer) of one run.
#   cross: a tree reads the other tree's data differently from its own data (the rolling-deploy question)
#   decode: the two trees read their own data differently (a single-version behaviour change)
#   wire: the written form differs (informative; only for deterministic writes)
dir = ARGV[0]
show = (ARGV[ARGV.index("--show") + 1] if ARGV.include?("--show")).to_i
show = 2 if show.zero?
load = ->(name) { File.foreach("#{dir}/#{name}.tsv").to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] } }
aa, ma, mm, am = %w[81-from-81 main-from-81 main-from-main 81-from-main].map(&load)
groups = Hash.new { |h, k| h[k] = [] }
aa.each_key do |k|
  g = k.sub(%r{/\d+\z}, "")
  if k.include?("-wire/") || k.end_with?("/writes")
    groups[["wire", g]] << [k, aa[k], am[k]] if aa[k] != am[k]
    next
  end
  groups[["cross 8.1 writes, main reads", g]] << [k, ma[k], mm[k], aa[k]] if ma[k] != mm[k] && ma[k] != aa[k]
  groups[["cross main writes, 8.1 reads", g]] << [k, am[k], aa[k], mm[k]] if am[k] != aa[k] && am[k] != mm[k]
  groups[["decode", g]] << [k, aa[k], mm[k]] if aa[k] != mm[k]
end
puts "keys: #{aa.size}"
groups.sort.each do |(kind, g), rows|
  puts "#{kind}\t#{g}\t#{rows.size}"
  rows.first(show).each do |k, x, y, *|
    x = x.to_s; y = y.to_s
    i = (0...[x.size, y.size].min).find { x[_1] != y[_1] } || [x.size, y.size].min
    from = [i - 80, 0].max
    puts "    #{k} @#{i}\n      #{x[from, 220]}\n      #{y[from, 220]}"
  end
end
