# frozen_string_literal: true

# Per-site ZJIT fallback and side-exit sample deltas between two traced census
# --stats runs (jit_parity_fxt.rb TSV, --depth 2), Rails main against the
# reverted tree. Sites are normalised to method names and file basenames, since
# the trees live in different bundle directories and the PRs move line numbers.
#   ruby trace_diff.rb WITH.tsv WITHOUT.tsv [MIN_SAMPLES]
with, without, min = ARGV
min = Integer(min || 200)
norm = ->(s) { s.gsub(/ \([^)]*?([^\/()]+?\.rb):\d+\)/, ' (\1)').gsub(/ \(<[^>]+>:\d+\)/, "") }
load = lambda do |f|
  h = Hash.new(0)
  File.foreach(f) do |x|
    cat, reason, site, n = x.chomp.split("\t")
    next unless n&.match?(/\A\d+\z/)
    h[[cat, reason.gsub(/0x\h+/, "0x…"), norm.(site)]] += n.to_i
  end
  h
end
w, o = load.(with), load.(without)
(w.keys | o.keys).map { [_1, w[_1] - o[_1]] }.select { _2.abs >= min }.sort_by { -_2 }.each do |k, d|
  puts format("%+7d  %6d -> %6d  %s", d, o[k], w[k], k.join(" | "))
end
