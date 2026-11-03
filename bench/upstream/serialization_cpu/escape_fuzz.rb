# ruby fuzz.rb OLD_RAILS NEW_RAILS: compare ActiveSupport::JSON.encode output across encoders.
outs = ARGV.first(2).map do |dir|
  r, w = IO.pipe
  pid = fork do
    r.close
    $LOAD_PATH.unshift(File.join(dir, "activesupport/lib"))
    require "active_support"; require "active_support/json"
    rng = Random.new(7)
    alpha = ["<", ">", "&", "\u2028", "\u2029", "a", "é", "\"", "\\", " ", "\u2027", "<b>", "x"]
    i_bad = ["\xE2\x80".b, "\xA8".b, "\xFF".b]
    alpha += i_bad
    res = []
    4000.times do |i|
      pool = i.even? ? alpha - i_bad : alpha
      s = Array.new(rng.rand(0..40)) { pool.sample(random: rng) }.map(&:b).join.force_encoding("UTF-8")
      [true, false].product([true, false]).each do |html, seps|
        ActiveSupport.escape_html_entities_in_json = html
        ActiveSupport.escape_js_separators_in_json = seps
        v = begin
          frag = s.valid_encoding? ? s : JSON::Fragment.new(%("#{s.b.delete("\"\\".b)}".b.force_encoding("UTF-8")))
          o = ActiveSupport::JSON.encode(s.valid_encoding? ? { "k#{s}" => frag, "n" => [s, 1] } : { "x" => frag })
          o2 = s.valid_encoding? ? ActiveSupport::JSON.encode({ "x" => frag }, escape_html_entities: !html) : o
          [o.b, o.encoding.to_s, o2.b, o2.encoding.to_s]
        rescue => e
          [e.class.to_s + ": " + e.message[0, 60]]
        end
        res << v
      end
    end
    w.write(Marshal.dump(res)); w.close
  end
  w.close; d = Marshal.load(r.read); Process.wait(pid); d
end
diff = outs[0].zip(outs[1]).count { _1 != _2 }
puts outs[0].select { _1.size == 1 }.tally.first(5).inspect
puts "cases #{outs[0].size}, differing #{diff}, invalid-encoding outputs #{outs[0].count { _1.size > 1 && !_1[0].dup.force_encoding('UTF-8').valid_encoding? }}, errors #{outs[0].count { _1.size == 1 }}"
