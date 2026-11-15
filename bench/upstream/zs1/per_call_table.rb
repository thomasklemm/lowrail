# per_call_table.rb DIR: Ir per call from per_call.rb runs (PREFIX-CASE-N.cg, two N per case), master (rm) against
# the branch (rp), with the empty loop subtracted.
t = Hash.new { |h, k| h[k] = {} }
Dir["#{ARGV[0]}/*.cg"].each do |f|
  prefix, name, n = File.basename(f, ".cg").match(/\A(rm|rp)-(.+)-(\d+)\z/).captures
  t[[prefix, name]][n.to_i] = File.read(f)[/^(?:totals|summary): (\d+)/, 1].to_i
end
per = t.transform_values { |h| lo, hi = h.keys.minmax; (h[hi] - h[lo]).fdiv(hi - lo) }
%w[iseq_symbol iseq_literal map_symbol map_literal sum_symbol sum_literal].each do |name|
  a = per[["rm", name]] - per[["rm", "empty"]]
  b = per[["rp", name]] - per[["rp", "empty"]]
  printf("%-14s master %7.1f  branch %7.1f  %+7.1f  %+.1f%%\n", name, a, b, b - a, (b / a - 1) * 100)
end
