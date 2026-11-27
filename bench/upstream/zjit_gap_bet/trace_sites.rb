# frozen_string_literal: true

# Top call sites per fallback or exit reason from jit_parity_fxt.rb summaries (bench/upstream/zjit_gap_bet/HANDOFF.md).
#   ruby trace_sites.rb SUMMARY.tsv [--reason REGEX] [--top N] [--scale F] [--reasons]
# --scale multiplies samples (sample rate / iterations traced) to events per iteration. --reasons lists totals only.
rows = File.readlines(ARGV.fetch(0), chomp: true).drop(1).map { _1.split("\t") }
arg = ->(name, default) { ARGV.include?(name) ? ARGV[ARGV.index(name) + 1] : default }
reason = Regexp.new(arg.("--reason", "."), Regexp::IGNORECASE)
top = Integer(arg.("--top", "8"))
scale = Float(arg.("--scale", "1"))
short = ->(site) { site.gsub(%r{/home/user/[\w./-]*?/(?=(?:rails-main|gems|lib/ruby|benchmarks)/)}, "").gsub(%r{rails-main/|gems/|lib/ruby/[\d.+]+/|bundler/gems/}, "") }
fmt = ->(n) { v = n * scale; v >= 10_000 ? "#{(v / 1000).round}k" : v >= 1000 ? "#{(v / 1000).round(1)}k" : v.round.to_s }
by = rows.group_by { [_1[0], _1[1]] }.transform_values { |rs| rs.sum { _1[3].to_i } }
if ARGV.include?("--reasons")
  by.sort_by { -_2 }.each { |(cat, r), n| puts "#{fmt.(n)}\t#{cat}\t#{r}" if "#{cat} #{r}".match?(reason) }
  exit
end
by.sort_by { -_2 }.each do |(cat, r), n|
  next unless "#{cat} #{r}".match?(reason)
  puts "## #{cat}: #{r} (#{fmt.(n)})"
  rows.select { _1[0] == cat && _1[1] == r }.max_by(top) { _1[3].to_i }.each { puts "  #{fmt.(_1[3].to_i)}\t#{short.(_1[2])}" }
end
