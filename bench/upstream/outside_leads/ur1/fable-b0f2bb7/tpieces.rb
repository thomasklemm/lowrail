# Which step of cgi/escape's Ruby CGI.unescape costs what, per call, on this Ruby (best of 7 windows).
require "cgi/escape"
S = "hello"
TBL = {}; 256.times { |i| TBL[-("%%%02X" % i)] = -i.chr }; TBL["+"] = " "; TBL.freeze
steps = {
  "tr" => -> { S.tr("+", " ") },
  "b" => -> { S.b },
  "gsub! block, no match" => -> { s = S.b; s.gsub!(/((?:%[0-9a-fA-F]{2})+)/) { |m| [m.delete("%")].pack("H*") }; s },
  "force_encoding + valid_encoding?" => -> { s = S.b; s.force_encoding(Encoding::UTF_8); s.valid_encoding? ? s : s.force_encoding(S.encoding) },
  "CGI.unescape(S.b, BINARY)" => -> { CGI.unescape(S.b, Encoding::BINARY) },
  "S.b.gsub(regexp, hash)" => -> { S.b.gsub(/\+|%\h\h/, TBL) },
}
now = -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
steps.each do |name, fn|
  t = now.(); n = 0
  while now.() - t < 4; 100.times { $sink = fn.call }; n += 100; end
  iters = (n / 4 * 0.3).to_i; best = Float::INFINITY
  7.times { t0 = now.(); i = 0; while i < iters; $sink = fn.call; i += 1; end; d = (now.() - t0) / iters; best = d if d < best }
  puts "#{name}\t#{(best * 1e9).round(1)} ns"
end
