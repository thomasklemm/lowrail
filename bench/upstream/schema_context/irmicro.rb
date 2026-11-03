# frozen_string_literal: true

# Per-call instruction counts for micro.rb cases under Callgrind (TZA passed through).
#   ruby irmicro.rb [--yjit] CASES ITERS NAME=DIR...
# Runs every case x variant in parallel (one process each) and prints Ir/call.
yjit = ARGV.delete("--yjit")
cases = ARGV.shift.split(",")
iters = Integer(ARGV.shift)
variants = ARGV.map { _1.split("=", 2) }
micro = File.expand_path("micro.rb", __dir__)
jobs = cases.product(variants).map do |c, (name, dir)|
  out = "/tmp/at/irmicro-#{c}-#{name}-#{yjit ? 'y' : 'i'}-#{ENV["TZA"]}#{ENV["ENUM"]}.log"
  pid = spawn({ "IR" => "1", "WARMUP" => (yjit ? "3000" : "1000"), "TZA" => ENV["TZA"], "ENUM" => ENV["ENUM"] },
    "/tmp/vg/bin/valgrind", "--tool=callgrind", "--collect-atstart=no", "--toggle-collect=rb_ary_cycle",
    *("--smc-check=all" if yjit), "--callgrind-out-file=/dev/null",
    "ruby", *("--yjit" if yjit), micro, dir, c, iters.to_s, out: out, err: [:child, :out])
  [c, name, pid, out]
end
res = jobs.map do |c, name, pid, out|
  Process.wait(pid)
  ir = File.read(out)[/Collected : (\d+)/, 1] or abort "no Ir: #{out}"
  [c, name, Integer(ir) / iters.to_f]
end
puts "#{yjit ? 'YJIT' : 'interpreter'}: instructions per call (#{iters} calls, GC off)"
res.group_by(&:first).each do |c, rows|
  base = rows.first[2]
  puts "#{c}: " + rows.map { |_, n, v| n == rows.first[1] ? format("%s %.0f", n, v) : format("%s %.0f (%+.1f%%)", n, v, 100 * (v - base) / base) }.join(" | ")
end
