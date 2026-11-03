# frozen_string_literal: true

# Self Ir per function, B minus A, from two Callgrind dumps (callgrind_annotate
# output). Machine code without a symbol (JIT code) is summed as "<JIT code>".
#   ruby SCRIPT A.callgrind B.callgrind [DIVISOR] [LIMIT]
# DIVISOR turns totals into per-iteration numbers (the dump's iteration count).
a_path, b_path, divisor, limit = ARGV
divisor = Float(divisor || 1)
limit = Integer(limit || 30)

def self_ir(path)
  out = IO.popen(["callgrind_annotate", "--threshold=100", "--auto=no", path], &:read)
  out.each_line.with_object(Hash.new(0)) do |line, h|
    next unless (m = line.match(/\A\s*([\d,]+) \([ \d.]+%\)\s+(.+?)\s*\z/))
    name = m[2]
    next if name.include?("PROGRAM TOTALS")
    name = name.start_with?("???:0x") ? "<JIT code>" : name.sub(/ \[.*\]\z/, "").sub(%r{\A.*/}, "").sub(/'\d+\z/, "")
    h[name] += m[1].delete(",").to_i
  end
end

a, b = self_ir(a_path), self_ir(b_path)
rows = (a.keys | b.keys).map { |k| [k, a[k] / divisor, b[k] / divisor] }
total_a, total_b = a.values.sum / divisor, b.values.sum / divisor
printf("%-60s %14s %14s %14s\n", "function", "A", "B", "B - A")
printf("%-60s %14.0f %14.0f %+14.0f\n", "TOTAL", total_a, total_b, total_b - total_a)
rows.sort_by { |_, x, y| -(y - x).abs }.first(limit).each do |name, x, y|
  printf("%-60s %14.0f %14.0f %+14.0f\n", name[0, 60], x, y, y - x)
end
