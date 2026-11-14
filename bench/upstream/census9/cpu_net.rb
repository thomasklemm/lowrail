# frozen_string_literal: true

# cpu_net.rb DIR BASE HEAD [--by file|method|line] [--limit N]
#
# Net view of two script/cpu-census labels (interpreter, JIT-flat workloads in
# BASE, HEAD and HEAD2): per app, the median change of whole-workload
# instructions per op with HEAD's A/A next to it; then Rails keys by net self
# instructions summed over all workloads (as % of all BASE instructions), so
# code that moved between methods or files nets out. cpu_regress.rb lists
# per-cell movers; this answers "where did the total go".
require "json"

dir, base, head = ARGV.first(3)
by = ARGV.include?("--by") ? ARGV[ARGV.index("--by") + 1] : "file"
limit = ARGV.include?("--limit") ? Integer(ARGV[ARGV.index("--limit") + 1]) : 30

def load(dir, label, by)
  keys = Hash.new(0.0)
  totals = {}
  Dir[File.join(dir, label, "*-interpreter.json")].each do |path|
    run = JSON.parse(File.read(path))
    app = run["app"].sub(/-(mysql|nops)\z/, "")
    run["workloads"].each do |w|
      next unless w.fetch("jit_flat", true)
      totals[[app, w["workload"]]] = w["ir_per_op"]
      list = by == "line" ? w["sites"] : w["methods"]
      list.each do |m|
        file = m["file"]
        key = case by
        when "line" then "#{file}:#{m["line"]}"
        when "method" then "#{file} #{m["method"]}"
        else file.start_with?("RAILS/") ? file : (file[/gems\/([^\/]+?)-\d/, 1] || file[/\A\w+/] || file)
        end
        keys[[key, app, w["workload"]]] += m.fetch("self_ir_per_op") { m["ir_per_op"] }
      end
    end
  end
  [keys, totals]
end

(bk, bt), (hk, ht), (_, h2t) = [base, head, "#{head}2"].map { load(dir, _1, by) }
wls = bt.keys & ht.keys & h2t.keys
med = ->(a) { s = a.sort; s.empty? ? 0 : (s[(s.size - 1) / 2] + s[s.size / 2]) / 2.0 }
puts "# #{base} -> #{head}: #{wls.size} workloads; per app: median whole-workload change, median |A/A| (#{head} vs #{head}2)"
wls.group_by(&:first).sort.each do |app, list|
  d = list.map { (ht[_1] - bt[_1]) / bt[_1] * 100 }
  aa = list.map { ((ht[_1] - h2t[_1]) / h2t[_1] * 100).abs }
  printf("%-20s %3d wl  median %+6.2f%%  min %+6.2f%%  max %+6.2f%%  A/A %.2f%%\n", app, list.size, med.(d), d.min, d.max, med.(aa))
end
all = wls.map { (ht[_1] - bt[_1]) / bt[_1] * 100 }
printf("ALL %d workloads: median %+.2f%%, slower %d, faster %d (beyond 1%%)\n", wls.size, med.(all), all.count { _1 > 1 }, all.count { _1 < -1 })
base_total = wls.sum { bt[_1] }
net = Hash.new(0.0)
apps = Hash.new { |h, k| h[k] = {} }
wset = wls.to_h { [_1, true] }
(bk.keys | hk.keys).each do |k|
  key, app, wl = k
  next unless wset[[app, wl]]
  d = hk[k] - bk[k]
  net[key] += d
  apps[key][app] = true if d > 1000
end
puts "\n# net self Ir by #{by}, % of all #{base} instructions (grew)"
net.sort_by { -_2 }.first(limit).each { |k, v| printf("%+7.3f%% %d apps  %s\n", v / base_total * 100, apps[k].size, k) }
puts "\n# net self Ir by #{by} (shrank)"
net.sort_by { _2 }.first(limit).each { |k, v| printf("%+7.3f%%  %s\n", v / base_total * 100, k) }
