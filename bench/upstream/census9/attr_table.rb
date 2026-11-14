# frozen_string_literal: true

# attr_table.rb DIR MODE [--markdown]: attr_sweep.sh results as one table per
# width: 8-1-stable (s81, A/A s81b), main before #59141 (pre141), the #59141
# merge (m141) and main (A/A main2). A delta counts when it exceeds twice the
# larger A/A of the two A/A pairs for that case; otherwise it prints as "~".
# Rows whose YJIT window compiled anything (jit column > 0 in any tree) are
# marked "not flat" and their deltas are not claimed.
dir, mode = ARGV
md = ARGV.include?("--markdown")
TREES = %w[s81 s81b pre141 m141 main main2].freeze

def load(dir, tree, mode, w)
  path = File.join(dir, "#{tree}-#{mode}-w#{w}.txt")
  return {} unless File.exist?(path)
  File.readlines(path).to_h { |l| n, ir, ob, jit = l.split; [n, [ir.to_f, ob.to_f, jit.to_i]] }
end

def pct(a, b) = (b - a) / a * 100

widths = Dir[File.join(dir, "main-#{mode}-w*.txt")].map { _1[/w(\d+)\.txt\z/, 1].to_i }.sort
widths.each do |w|
  d = TREES.to_h { [_1, load(dir, _1, mode, w)] }
  # The 8.1 twin is skipped at the widest width; main's A/A is the control there.
  d["s81b"] = d["s81"] if d["s81b"].empty?
  next if d.values.any?(&:empty?)
  puts md ? "\n**#{mode}, #{w == 5 ? 6 : w} columns** (Ir per call; objects per call)\n\n" : "\n== #{mode} width #{w}"
  puts md ? "| Case | 8.1 | before #59141 | #59141 | main | #59141 effect | main vs 8.1 | A/A max | Objects 8.1 → main |\n| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |" :
    format("%-28s %10s %10s %10s %10s %9s %9s %7s %s", "case", "8.1", "pre141", "m141", "main", "#59141", "main/8.1", "A/A", "obj 8.1->main")
  d["main"].each_key do |c|
    s81, s81b, pre, m141, main, main2 = TREES.map { d[_1][c] }
    next unless [s81, s81b, pre, m141, main, main2].all?
    aa = [pct(s81[0], s81b[0]).abs, pct(main[0], main2[0]).abs].max
    floor = [2 * aa, 0.5].max
    flat = [s81, s81b, pre, m141, main, main2].all? { _1[2].zero? }
    s = (s81[0] + s81b[0]) / 2
    m = (main[0] + main2[0]) / 2
    fmt = ->(v) { !flat ? "not flat" : v.abs < floor ? "~" : format("%+.1f%%", v) }
    eff = fmt.(pct(pre[0], m141[0]))
    tot = fmt.(pct(s, m))
    objs = format("%g → %g", s81[1], main[1])
    if md
      puts "| `#{c}` | #{s.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse} | #{pre[0].round} | #{m141[0].round} | #{m.round} | #{eff} | #{tot} | #{format("%.2f%%", aa)} | #{objs} |"
    else
      puts format("%-28s %10.0f %10.0f %10.0f %10.0f %9s %9s %6.2f%% %s", c, s, pre[0], m141[0], m, eff, tot, aa, objs)
    end
  end
end
