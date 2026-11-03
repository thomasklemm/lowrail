# frozen_string_literal: true

# Per-call instruction counts for micro.rb cases under Callgrind, one process
# per case x variant, in parallel (at most JOBS at once).
#   ruby irmicro.rb [--yjit] CASES ITERS NAME...
# Variant NAME runs with BUNDLE_GEMFILE=Gemfile.v-NAME next to this file.
yjit = ARGV.delete("--yjit")
cases = ARGV.shift.split(",")
iters = Integer(ARGV.shift)
variants = ARGV
dir = __dir__
micro = File.join(dir, "micro.rb")
jobs = Integer(ENV.fetch("JOBS", "8"))
work = cases.product(variants)
res = []
running = {}
until work.empty? && running.empty?
  while running.size < jobs && (c, name = work.shift)
    out = "/tmp/irmicro-#{c}-#{name}-#{yjit ? 'y' : 'i'}#{"-p" if ENV["PLAIN"]}#{"-l" if ENV["LEGACY"]}.log"
    env = { "PLAIN" => ENV["PLAIN"], "LEGACY" => ENV["LEGACY"], "IR" => "1", "WARMUP" => (yjit ? "600" : "200"), "BUNDLE_GEMFILE" => File.join(dir, "Gemfile.v-#{name}") }
    pid = spawn(env, "/tmp/vg/bin/valgrind", "--tool=callgrind", "--collect-atstart=no", "--toggle-collect=rb_ary_cycle",
      *("--smc-check=all" if yjit), "--callgrind-out-file=/dev/null",
      "ruby", *("--yjit" if yjit), "-rbundler/setup", micro, c, iters.to_s, out: out, err: [:child, :out])
    running[pid] = [c, name, out]
  end
  pid = Process.wait
  c, name, out = running.delete(pid)
  ir = File.read(out)[/Collected : (\d+)/, 1] or abort "no Ir: #{out}"
  res << [c, name, Integer(ir) / iters.to_f]
end
puts "#{yjit ? 'YJIT' : 'interpreter'}: instructions per call (#{iters} calls, GC off)"
res.group_by(&:first).sort_by { cases.index(_1) }.each do |c, rows|
  rows = rows.sort_by { variants.index(_2) }
  base = rows.first[2]
  puts "#{c}: " + rows.map { |_, n, v| n == rows.first[1] ? format("%s %.0f", n, v) : format("%s %.0f (%+.2f%%)", n, v, 100 * (v - base) / base) }.join(" | ")
end
