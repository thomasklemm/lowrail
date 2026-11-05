# irtable.rb LOG409 LOGMASTER -> markdown table of per-iteration windows, % vs main
def win(f, sfx)
  h = Hash.new { |x, k| x[k] = {} }
  File.readlines(f).each { |l| next unless l =~ /^\w+-([\w-]+?)-interpreter-(.+)-(1|4): ([\d,]+)/; h[[$1, $2.delete_suffix(sfx)]][$3] = $4.delete(",").to_i }
  h.transform_values { |v| v["4"] && v["1"] ? (v["4"] - v["1"]) / 3.0 : nil }
end
a, b = win(ARGV[0], ""), win(ARGV[1], "-r41")
puts "| bench | Ruby | main Ir/iter | A/A (m2) | A | B |", "| --- | --- | ---: | ---: | ---: | ---: |"
%w[railsbench shipit lobsters erubi-rails].each do |bn|
  [["4.0.9", a], ["master", b]].each do |r, w|
    base = w[[bn, "m"]] or next
    pc = ->(v) { x = w[[bn, v]]; x ? format("%+.3f%%", (x / base - 1) * 100) : "–" }
    puts "| #{bn} | #{r} | #{format('%.4e', base)} | #{pc.("m2")} | #{pc.("qi")} | #{pc.("tg")} |"
  end
end
