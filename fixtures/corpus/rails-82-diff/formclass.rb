# usage: ruby formclass.rb A.tsv B.tsv   classifies view/form differences by the options that explain them
ARGV2 = ARGV.dup
src = File.read(File.join(__dir__, "harness2.rb")).split(/^# ---- Load Rails -/).first
ARGV.replace(["/dev/null"]); eval(src, binding, "harness2.rb")
a = File.foreach(ARGV2[0], ).to_h { |l| k, v = l.scrub.chomp.split("\t", 2); [k, v] }
b = File.foreach(ARGV2[1], ).to_h { |l| k, v = l.scrub.chomp.split("\t", 2); [k, v] }
known = ->(h) {
  r = []
  h.each do |k, v|
    r << :nested_hash if v.is_a?(Hash) && !%i[data aria].include?(k)
    r << :hidden_value if k == :hidden && (v.is_a?(String) || (v.is_a?(Array) && %i[sym safe].include?(v[0])))
    r << :new_boolean if %i[open].include?(k)
    r << :blank_key if k.to_s.strip.empty?
  end
  r
}
why = Hash.new(0); un = []
a.each_key do |k|
  next unless k.start_with?("view/form/") && !k.end_with?("~norm") && a[k] != b[k]
  i = k.split("/").last.to_i; c = FORM_CASES[i]
  r = known.(c[:opts]) | known.(c[:html])
  r.empty? ? un << k : r.each { why[_1] += 1 }
end
p why: why, unexplained: un.size
un.group_by { _1.split("/")[2] }.each { |f, ks| puts "#{f}: #{ks.size}"; ks.first(2).each { |k| i = k.split("/").last.to_i; puts "  #{k} opts=#{FORM_CASES[i][:opts].inspect[0,150]} html=#{FORM_CASES[i][:html].inspect[0,150]}\n   81:   #{a[k][0,400]}\n   main: #{b[k][0,400]}" } }
