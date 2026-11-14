# cg_summary.rb : Ir per iteration (measured window minus the empty window, / itrs) for each ~/w/zl3/cg-*.log,
# with the JIT-flat gate, GCs per iteration and the compile counters at the end of the window.
require "json"
dir = File.expand_path("~/w/zl3")
rows = Dir["#{dir}/cg-*.log"].sort.filter_map do |log|
  text = File.read(log)
  next unless text =~ /(\S+) (\S+) (\S+) exit (\d+)/
  label, bench, name = $1, $2, $3
  totals = text.scan(/\.cg\.\d+\.(\d) (\d+)/).to_h { |i, n| [i.to_i, n.to_i] }
  json = JSON.parse(File.read("#{dir}/cg/#{label}/#{bench}-#{name}.json"))
  itrs = json.fetch("itrs")
  ir = (totals.fetch(2) - totals.fetch(1)).fdiv(itrs)
  { label:, bench:, name:, ir:, gate: json.dig("jit_flat", "gate"), gc: json.dig("gc", "count"),
    after: json.dig("jit_flat", "measured_after"), brk: text.include?("BRK") }
end
rows.group_by { _1[:bench] }.each do |bench, rs|
  puts "== #{bench}"
  base = rs.select { _1[:label] == "base" }.map { _1[:ir] }
  ref = base.empty? ? nil : base.sum / base.size
  rs.sort_by { [_1[:label], _1[:name]] }.each do |r|
    delta = ref ? format("%+.2f%%", (r[:ir] / ref - 1) * 100) : ""
    printf("%-10s %s %10.1fM Ir/itr %8s gate=%s gc/itr=%.1f brk=%s %s\n", r[:label], r[:name], r[:ir] / 1e6, delta, r[:gate], r[:gc], r[:brk], r[:after])
  end
end
