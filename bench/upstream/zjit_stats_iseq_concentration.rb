# Usage: ruby bench/upstream/zjit_stats_iseq_concentration.rb .lowrail/private/zjit-poly/rbjit/railsbench.tsv ...
# Per-ISEQ concentration of ZJIT fallbacks from probe TSVs (reason, site, iseq label, kind, recv, shape, count)
groups = { "getivar" => /^getivar_fallback/, "send poly/mega" => /^Send: (polymorphic|megamorphic)/, "invokeblock" => /^InvokeBlock/ }
ARGV.each do |f|
  rows = File.readlines(f, chomp: true).map { _1.split("\t") }.reject { |r| r[0].end_with?("/cme") }
  puts "== #{File.basename(File.dirname(f))}/#{File.basename(f)}"
  groups.each do |g, re|
    by_iseq = Hash.new(0); by_site = Hash.new(0)
    rows.each { |r| next unless r[0] =~ re; by_iseq[r[2]] += r[-1].to_i; by_site[r[1]] += r[-1].to_i }
    tot = by_iseq.values.sum
    next if tot.zero?
    s = by_iseq.values.sort.reverse
    cov = ->(n) { (100.0 * s.first(n).sum / tot).round }
    printf "  %-15s total %9d  iseqs %4d sites %4d  top1 %3d%% top10 %3d%% top50 %3d%%  #1 %s\n", g, tot, s.size, by_site.size, cov[1], cov[10], cov[50], by_iseq.max_by { _2 }[0].sub(%r{/home/user/w/rm/lib/ruby/gems/[^/]+/gems/}, "")
  end
end
