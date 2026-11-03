# frozen_string_literal: true

# Interleaved per-call micro across Rails worktrees, separate processes.
# ruby ab.rb [--yjit] --cases a,b --rounds 6 --iters 3000 NAME=DIR NAME=DIR ...
# Prints per case: median ns of per-process medians, delta vs the first variant, objects/call.
require "optparse"
opts = { rounds: 6, iters: 3000, yjit: false, env: {} }
OptionParser.new do |o|
  o.on("--cases LIST") { opts[:cases] = _1 }
  o.on("--rounds N", Integer) { opts[:rounds] = _1 }
  o.on("--iters N", Integer) { opts[:iters] = _1 }
  o.on("--yjit") { opts[:yjit] = true }
  o.on("--env K=V") { k, v = _1.split("=", 2); opts[:env][k] = v }
end.parse!
variants = ARGV.map { _1.split("=", 2) }
micro = File.expand_path("micro.rb", __dir__)
res = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = [] } }
objs = Hash.new { |h, k| h[k] = {} }
opts[:rounds].times do |r|
  variants.rotate(r % variants.size).each do |name, dir|
    cmd = ["ruby", *("--yjit" if opts[:yjit]), micro, dir, opts[:cases], opts[:iters].to_s, "3"]
    IO.popen(opts[:env], cmd, err: File::NULL) do |io|
      io.each_line do |line|
        c, ns, *rest = line.split
        res[c][name] << Float(ns)
        objs[c][name] = line[/([\d.]+) obj/, 1]
      end
    end
  end
end
med = ->(a) { s = a.sort; s[s.size / 2] }
puts "#{opts[:yjit] ? 'YJIT' : 'interpreter'}, #{opts[:rounds]} interleaved processes x 3 rounds x #{opts[:iters]} calls"
res.each do |c, by|
  base = med.(by[variants.first[0]])
  cells = variants.map do |name, _|
    m = med.(by[name])
    d = name == variants.first[0] ? "" : format(" (%+.1f%%)", 100.0 * (m - base) / base)
    format("%s %.1f µs%s, %s obj", name, m / 1000, d, objs[c][name])
  end
  puts "#{c}: #{cells.join(' | ')}"
end
