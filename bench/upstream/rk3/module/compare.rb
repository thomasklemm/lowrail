# ruby compare.rb base.txt head.txt: counts differing lines and classifies them.
a = File.readlines(ARGV[0]); b = File.readlines(ARGV[1])
abort "line count differs #{a.size} #{b.size}" unless a.size == b.size
kinds = Hash.new(0); other = []
a.zip(b).each do |x, y|
  next if x == y
  bx = x.sub(/, "(BINARY|ASCII-8BIT)"\]$/, ', "UTF-8"]')
  if bx == y && x.include?(":err") && x.start_with?("Utils.unescape ", "include Utils #unescape ", "parse_cookies_header ")
    kinds[x[/^\S+( \S+)?/]] += 1
  else
    other << [x, y]
  end
end
puts "#{a.size} lines, #{a.zip(b).count { |x, y| x != y }} differ"
puts "message encoding BINARY -> UTF-8 only (Utils.unescape paths): #{kinds}"
puts "other differences: #{other.size}"
other.first(Integer(ENV.fetch("SHOW", "5"))).each { |x, y| puts "- #{x}+ #{y}" }
