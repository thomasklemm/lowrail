# Usage: ruby shareable_probe.rb MODE ; evaluates hash-literal shapes under the given shareable_constant_value mode
require "zlib"
mode = ARGV[0]
cases = {
  pairs: "{ a: v(1), b: v(2) }",
  pair_splat: "{ a: v(1), **h(2) }",
  splat_pair: "{ **h(1), a: v(2) }",
  pair_splat_pair: "{ a: v(1), **h(2), b: v(3) }",
  splat_splat_pair: "{ **h(1), **h(2), c: v(3) }",
  splat_pair_splat: "{ **h(1), a: v(2), **h(3) }",
  dup_key: "{ **h(1), k1: v(2) }",
  nil_splat: "{ **nil, a: v(1) }",
  empty_splat: "{ **{}, a: v(1) }",
  nested: "{ **h(1), a: { **h(2), b: v(3) } }",
  big: "{ " + (0...130).map { "k#{_1}: v(#{_1})" }.join(", ") + " }",
  big_splat: "{ **h(0), " + (1...131).map { "k#{_1}: v(#{_1})" }.join(", ") + " }",
  literal_val: "{ **h(1), a: 1, b: [2], c: 's' }",
  const_splat: "{ **H, a: 1 }",
  string_val: "{ **h(1), s: 'str' }",
}
cases.each do |name, expr|
  src = "# shareable_constant_value: #{mode}\n$log = []\ndef v(i) = ($log << i; \"v\#{i}\")\ndef h(i) = ($log << -i; { \"k\#{i}\".to_sym => i })\nH = { b: 2 }\nX = #{expr}\n[X, $log, Ractor.shareable?(X), X.frozen?, X.to_a]"
  r = begin
    x = eval(src, TOPLEVEL_BINDING.dup, "c_#{name}.rb")
    x = [x[0].size > 5 ? Zlib.crc32(x[0].inspect) : x[0], x[1].size > 10 ? Zlib.crc32(x[1].inspect) : x[1], x[2], x[3], x[4].size > 5 ? Zlib.crc32(x[4].inspect) : nil]
    x.inspect
  rescue Exception => e
    "#{e.class}: #{e.message[0, 70]}"
  end
  Object.send(:remove_const, :X) if defined?(X)
  Object.send(:remove_const, :H) if defined?(H)
  puts "#{mode} #{name}: #{r}"
end
