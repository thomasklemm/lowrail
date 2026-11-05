# Byte-compare two raw dumps; report differences that remain after blanking
# the random-by-design fields, and whether each blanked field kept its length.
a, b = ARGV
PATS = {
  "authenticity_token" => /(name="authenticity_token" (?:autocomplete="off" )?value=")([^"]+)/,
  "csrf-token meta" => /(name="csrf-token" content=")([^"]+)/,
  "ETag" => /^(ETag: )(.*)$/,
  "Set-Cookie" => /^(Set-Cookie: lobster_trap=)([^;]+)/,
  "X-Request-Id" => /^(X-Request-Id: )(.*)$/,
  "X-Runtime" => /^(X-Runtime: )(.*)$/,
}
seen = Hash.new(0); lens = Hash.new { |h, k| h[k] = [] }; rest = []
Dir[File.join(a, "*")].sort.each do |fa|
  x, y = File.binread(fa), File.binread(File.join(b, File.basename(fa)))
  PATS.each do |name, re|
    xs, ys = x.scan(re).map(&:last), y.scan(re).map(&:last)
    seen[name] += xs.zip(ys).count { _1 != _2 }
    lens[name] << (xs.map(&:bytesize) == ys.map(&:bytesize))
    x = x.gsub(re) { "#{$1}X" }; y = y.gsub(re) { "#{$1}X" }
  end
  rest << [File.basename(fa), x.lines.first.chomp, (x.lines - y.lines).first(2)] unless x == y
end
PATS.each_key { puts format("%-20s differs %4d times, same length everywhere: %s", _1, seen[_1], lens[_1].all?) }
puts "files still differing after blanking: #{rest.size}"
rest.first(10).each { p _1 }
