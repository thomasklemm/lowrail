# cg_report.rb ROOT: per ruby-bench Callgrind run in ROOT/<build>-<mode>/<bench>-<name>.*, M Ir per iteration
# (measured window minus the empty window, divided by itrs), the Hash functions' share, GCs and the JIT-flat gate.
require "json"

HASH_FN = /\A(rb_hash_|ar_|st_|any_hash|rb_any_|obj_any_hash|hash_|tbl_update|rb_ident_hash|key_stringify|rb_hash\z|find_table_|rebuild_table|get_power2|rb_st_)/

def self_ir(path)
  out = IO.popen(["callgrind_annotate", "--threshold=100", "--auto=no", "--inclusive=no", path], &:read)
  out.each_line.with_object(Hash.new(0)) do |line, h|
    next unless (m = line.match(/\A\s*([\d,]+) \([ \d.]+%\)\s+(.+?)\s*\z/))
    name = m[2]
    next if name.include?("PROGRAM TOTALS")
    name = name.start_with?("???:0x") ? "<JIT code>" : name.sub(/ \[.*\]\z/, "").sub(/\A.*:/, "").sub(/'\d+\z/, "").sub(/\.(isra|part|constprop)\.\d+.*\z/, "")
    h[name] += m[1].delete(",").to_i
  end
end

def total(path) = Integer(File.foreach(path).find { _1.start_with?("totals: ") }.split[1])

root = ARGV.fetch(0)
rows = []
Dir[File.join(root, "*", "*.json")].sort.each do |json|
  meta = JSON.parse(File.read(json))
  base = json.delete_suffix(".json")
  dumps = Dir["#{base}.cg.*.*"].sort_by { _1[/\.(\d+)\z/, 1].to_i }
  next unless dumps.size >= 2
  itrs = meta["itrs"].to_f
  empty, window = dumps.first(2)
  fns = self_ir(window)
  hash_ir = fns.select { |k, _| k.match?(HASH_FN) }.values.sum
  brk = File.read("#{base}.log").include?("brk segment overflow")
  rows << { run: "#{File.basename(File.dirname(json))}/#{File.basename(base)}", m_ir: (total(window) - total(empty)) / itrs / 1e6,
            hash_m_ir: hash_ir / itrs / 1e6, gcs: meta.dig("gc", "count"), gate: meta.dig("jit_flat", "gate"), brk: }
end
rows.each { |r| puts format("%-34s %10.2f M Ir/itr  hash fns %7.2f M  GCs %.2f  gate %-4s %s", r[:run], r[:m_ir], r[:hash_m_ir], r[:gcs], r[:gate], r[:brk] ? "BRK OVERFLOW" : "") }
File.write(File.join(root, "summary.json"), JSON.pretty_generate(rows))
