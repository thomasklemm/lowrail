# differential: backtrace strings for many file/method encodings; prints one line per case
encs = %w[UTF-8 BINARY Shift_JIS EUC-JP ISO-8859-1 US-ASCII Windows-1252 UTF-16LE]
raw = ["plain", "\xC3\xA9", "\x82\xa0", "\xa4\xa2", "\xff\xfe", "\xe9", "a b%s%d"]
files = encs.product(raw).map { |e, r| r.b.force_encoding(e) } + ["ü.rb", "x" * 300]
meths = encs.product(raw).filter_map { |e, r| (r.b.force_encoding(e).to_sym rescue nil) }
out = []
files.each do |f|
  meths.each do |m|
    k = Class.new
    k.define_method(m) { [caller(0, 1)[0], caller_locations(0, 1)[0].to_s, caller_locations(0, 1)[0].inspect, (raise "x" rescue $!.backtrace[0])] }
    begin
      r = eval("k.new.__send__(m)", binding, f)
      out << [f.encoding, f.b, m.encoding, m.to_s.b, r.map { [_1.b, _1.encoding.to_s, _1.valid_encoding?, _1.ascii_only?] }].inspect
    rescue Exception => e
      out << [f.encoding, f.b, m.encoding, m.to_s.b, e.class, e.message.b].inspect
    end
  end
end
# cfunc frames and full_message
out << [1].map { caller(0, 2)[1] }.inspect
out << (begin; raise "y"; rescue => e; e.full_message(highlight: false).b; end).inspect
puts out
