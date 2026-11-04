src = File.read(File.join(__dir__, "harness.rb")).split("# ---- Load Rails").first
ARGV2 = ARGV.dup; ARGV.clear
eval(src.sub(/^OUT = ARGV.shift\n/, "").sub(/^ONLY = ARGV\n/, "ONLY = []\n"), binding, "harness.rb")
a = File.foreach(ARGV2[0]).to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
b = File.foreach(ARGV2[1]).to_h { |l| k, v = l.chomp.split("\t", 2); [k, v] }
idx = (a.keys | b.keys).select { |k| k =~ %r{\Aescape/(tag_builder|content_tag|content_tag_noesc|tag_open|tag_attributes|tag_options|link_attrs|form_tags|class_names)/} && a[k] != b[k] }.map { _1.split("/").last.to_i }.uniq
why = Hash.new(0); unexplained = []
idx.each do |i|
  at = TAG_INPUTS[i][:attrs]
  r = []
  r << :nested_hash if at.any? { |k, v| v.is_a?(Hash) && !%w[data aria].include?(k) }
  r << :hidden_string if at.key?("hidden") && (at["hidden"].is_a?(String) || (at["hidden"].is_a?(Array) && at["hidden"][0] == :sym))
  r << :blank_key if at.keys.any? { _1.strip.empty? }
  r << :bool_new if (at.keys & %w[open]).any?
  r.empty? ? unexplained << i : r.each { why[_1] += 1 }
end
p total: idx.size, why: why, unexplained: unexplained.first(10), n_unexplained: unexplained.size
unexplained.first(4).each { |i| puts TAG_INPUTS[i].inspect; %w[tag_options tag_builder].each { |f| k = "escape/#{f}/#{i}"; puts "  81  : #{a[k]}\n  main: #{b[k]}" } }
