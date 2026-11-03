# ruby escape_fuzz_custom.rb BASE_RAILS HEAD_RAILS: compare escape results (bytes, encoding, class,
# html_safe?) across the default encoder and custom JSONGemEncoders whose stringify returns a String subclass,
# a SafeBuffer, or a plain String with singleton methods (include?, instance_of?, equal?, to_s/equal?/class, gsub!).
# Prints the differing cases per encoder.
outs = ARGV.first(2).map do |dir|
  r, w = IO.pipe
  pid = fork do
    r.close
    $LOAD_PATH.unshift(File.join(dir, "activesupport/lib"))
    require "active_support"; require "active_support/json"; require "active_support/core_ext/string/output_safety"
    sub = Class.new(String) { def include?(*) = false }
    encoders = {
      "default" => ActiveSupport::JSON::Encoding.json_encoder,
      "gem" => ActiveSupport::JSON::Encoding::JSONGemEncoder,
      "subclass" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { define_method(:stringify) { |j| sub.new(super(j)) } },
      "safe_buffer" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.html_safe },
      "singleton_include" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.include?(*) = false } },
      "singleton_instance_of" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.instance_of?(*) = false } },
      "singleton_include_raises" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.include?(*) = raise("include?") } },
      "singleton_gsub_passthrough" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.gsub!(*a, **k, &b) = super } },
      "singleton_to_s_equal_class" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.to_s = "x"; def s.equal?(*) = false; def s.class = Integer } },
      "safe_buffer_lying" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.html_safe.tap { |s| def s.to_s = self; def s.equal?(*) = true; def s.instance_of?(*) = true } },
      "singleton_equal_true_include_false" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.equal?(*) = true; def s.include?(*) = false } },
      "subclass_equal_true_include_false" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = Class.new(String) { def equal?(*) = true; def include?(*) = false; def to_s = self }.new(super) },
      "singleton_equal_raises" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.equal?(*) = raise("equal?") } },
      "singleton_gsub_noop" => Class.new(ActiveSupport::JSON::Encoding::JSONGemEncoder) { def stringify(j) = super.tap { |s| def s.gsub!(*) = nil } },
    }
    rng = Random.new(7)
    alpha = ["<", ">", "&", "\u2028", "\u2029", "a", "é", "\"", "\\", " ", "\u2027", "<b>", "x"]
    bad = ["\xE2\x80".b, "\xA8".b, "\xFF".b]
    res = []
    encoders.each do |ename, enc|
      ActiveSupport::JSON::Encoding.json_encoder = enc
      1000.times do |i|
        pool = i.even? ? alpha : alpha + bad
        s = Array.new(rng.rand(0..40)) { pool.sample(random: rng) }.map(&:b).join.force_encoding("UTF-8")
        [true, false].product([true, false]).each do |html, seps|
          ActiveSupport.escape_html_entities_in_json = html
          ActiveSupport.escape_js_separators_in_json = seps
          v = begin
            frag = s.valid_encoding? ? s : JSON::Fragment.new(%("#{s.b.delete("\"\\".b)}".b.force_encoding("UTF-8")))
            outs2 = [ActiveSupport::JSON.encode(s.valid_encoding? ? { "k#{s}" => frag, "n" => [s, 1] } : { "x" => frag })]
            outs2 << ActiveSupport::JSON.encode({ "x" => frag }, escape_html_entities: !html) if s.valid_encoding?
            outs2.flat_map { |o| [o.b, o.encoding.to_s, o.class.name || "anon", o.respond_to?(:html_safe?) && o.html_safe?] }
          rescue => e
            [e.class.to_s]
          end
          res << [ename, v]
        end
      end
    end
    # Trace: both flags read before the first String operation on the generated JSON.
    ActiveSupport::JSON::Encoding.json_encoder = encoders["default"]
    log = []
    enc = ActiveSupport::JSON::Encoding
    %i[escape_html_entities_in_json escape_js_separators_in_json].each do |m|
      enc.singleton_class.prepend(Module.new { define_method(m) { log << m; super() } })
    end
    tp = TracePoint.new(:c_call) { |t| log << t.method_id if %i[gsub! include? tr!].include?(t.method_id) }
    ActiveSupport.escape_html_entities_in_json = true; ActiveSupport.escape_js_separators_in_json = true
    tp.enable { ActiveSupport::JSON.encode({ "a" => "<\u2028" }) }
    first_op = log.index { !%i[escape_html_entities_in_json escape_js_separators_in_json].include?(_1) } || log.size
    res << ["trace", log.first(first_op).uniq.sort]
    w.write(Marshal.dump(res)); w.close
  end
  w.close; d = Marshal.load(r.read); Process.wait(pid); d
end
diff = outs[0].zip(outs[1]).select { _1 != _2 }
puts "cases #{outs[0].size}, differing #{diff.size}"
outs[0][0...-1].group_by(&:first).each { |e, rows| puts "#{e}: #{rows.size} cases, invalid-encoding outputs #{rows.count { |_, v| v.size > 1 && !v[0].dup.force_encoding('UTF-8').valid_encoding? }}, html_safe true #{rows.count { |_, v| v.each_slice(4).any? { _1[3] == true } }}, errors #{rows.count { |_, v| v.size == 1 }}" }
puts "trace base: #{outs[0].last.inspect}  head: #{outs[1].last.inspect}"
puts "differing by encoder: #{diff.map { _1[0][0] }.tally}"
