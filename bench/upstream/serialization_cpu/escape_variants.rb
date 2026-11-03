require "json"
U2028 = -"\u2028".b; U2029 = -"\u2029".b
ESC = { U2028 => -'\u2028'.b, U2029 => -'\u2029'.b, ">".b => -'\u003e'.b, "<".b => -'\u003c'.b, "&".b => -'\u0026'.b }.freeze
FULLRE = Regexp.union(*ESC.keys).freeze
HTMLRE = Regexp.union(*(ESC.keys - [U2028, U2029])).freeze
LT = -"<".b; GT = -">".b; AMP = -"&".b
ELT = -'\u003c'.b; EGT = -'\u003e'.b; EAMP = -'\u0026'.b; E28 = -'\u2028'.b; E29 = -'\u2029'.b
def cur_html(j) = (j.force_encoding(Encoding::BINARY); j.gsub!(HTMLRE, ESC); j.force_encoding(Encoding::UTF_8))
def cur_full(j) = (j.force_encoding(Encoding::BINARY); j.gsub!(FULLRE, ESC); j.force_encoding(Encoding::UTF_8))
def html!(j)
  j.gsub!(LT) { ELT } if j.include?(LT)
  j.gsub!(GT) { EGT } if j.include?(GT)
  j.gsub!(AMP) { EAMP } if j.include?(AMP)
end
def seps!(j)
  j.gsub!(U2028) { E28 } if j.include?(U2028)
  j.gsub!(U2029) { E29 } if j.include?(U2029)
end
def un_html(j) = (j.force_encoding(Encoding::BINARY); html!(j); j.force_encoding(Encoding::UTF_8))
def un_full(j) = (j.force_encoding(Encoding::BINARY); html!(j); seps!(j); j.force_encoding(Encoding::UTF_8))
def un_html_utf(j) = (html!(j); j)
html = JSON.generate(Array.new(20) { |i| { "id" => i, "title" => "Post #{i} about Ruby & Rails \u2028\u2029", "body" => "Body <b>#{i}</b> é " * 8, "created_at" => "2026-01-01T00:00:00.000Z" } })
some = JSON.generate(Array.new(20) { |i| { "id" => i, "title" => "Post #{i} about Ruby & Rails", "body" => "Body bold #{i} é “quoted” " * 8, "created_at" => "2026-01-01T00:00:00.000Z" } })
plain = JSON.generate(Array.new(20) { |i| { "id" => i, "title" => "Post #{i} about Ruby and Rails", "body" => "Body bold #{i} é " * 8, "created_at" => "2026-01-01T00:00:00.000Z" } })
small = JSON.generate({ "id" => 1, "ok" => true })
tiny = JSON.generate("x")
[["html", html], ["some&", some], ["plain", plain], ["small", small], ["tiny", tiny]].each do |name, s|
  [%i[cur_html un_html un_html_utf], %i[cur_full un_full]].each do |ms|
    ref = send(ms.first, s.dup)
    ms.each { |m| r = send(m, s.dup); warn "#{m} differs" unless r.b == ref.b && r.encoding == ref.encoding }
    ms.each do |m|
      GC.start; n = 50000; t = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
      n.times { send(m, s.dup) }
      print format("%-6s %-12s %8.3f us  ", name, m, (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - t) * 1e6 / n)
    end
    puts
  end
end
