# Compares extract_header on main and on the branch for many env key shapes.
# ruby th_diff.rb OLD_FILE NEW_FILE
old_src, new_src = ARGV.map { File.read(_1) }
impls = { old: old_src, new: new_src }.to_h do |name, src|
  src = src.sub("module TracingHeaders", "module TracingHeaders_#{name}").sub(/private_constant :TracingHeaders/, "")
  eval(src, TOPLEVEL_BINDING)
  [name, PostHog::Rails.const_get("TracingHeaders_#{name}")]
end

headers = ["X-POSTHOG-SESSION-ID", "X-POSTHOG-DISTINCT-ID", "User-Agent", "X-Forwarded-For"]
bases = headers + headers.map(&:downcase) + ["HTTP_#{headers[0].tr('-', '_')}"]
variants = bases.flat_map do |b|
  [b, b.downcase, b.upcase, b.swapcase, b.tr("-", "_"), b.tr("_", "-"), "HTTP_#{b}", "http_#{b.downcase}", "HTTP-#{b}",
   "#{b}X", b[0..-2], " #{b}", b.sub("S", "ſ"), b.sub("I", "ı"), b.sub("i", "ı"), b.sub(/st/i, "ﬆ"), b.sub(/ff/i, "ﬀ"),
   b.downcase.sub("st", "ﬆ"), b.sub("SS", "ß"), b.b, b.encode("UTF-16LE"), b.dup.force_encoding("ISO-8859-1"),
   b.sub("-", "\u00ad"), b.sub("A", "\u00e0"), b.to_sym, b.dup.freeze]
end
others = [1, nil, :foo, "", "ß", "ﬆ", "\xff".b, Object.new, %w[a b]]
keys = variants + others
values = ["v", " v\n", "", "\u0000", nil, 1]

mismatch = 0
cases = 0
envs = keys.flat_map { |k| values.map { |v| { "REQUEST_METHOD" => "GET", k => v } } }
envs += keys.each_slice(7).map { |slice| slice.each_with_index.to_h { |k, i| [k, "v#{i}"] } }
envs.each do |env|
  headers.each do |h|
    cases += 1
    results = impls.transform_values do |impl|
      impl.extract_header(env, h)
    rescue => e
      [e.class]
    end
    next if results[:old] == results[:new]
    mismatch += 1
    warn "MISMATCH #{h} #{env.keys.inspect}: #{results.inspect}" if mismatch < 20
  end
end
puts "#{cases} cases, #{mismatch} mismatches"
