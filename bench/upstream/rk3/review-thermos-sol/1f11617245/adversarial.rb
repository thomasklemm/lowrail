require "json"
require "rack/utils"
if ENV["SAFE"]
  require "active_support"
  require "active_support/core_ext/string/output_safety"
  require "erb"
end

Tagged = Class.new(String)
Hooks = {}
[:to_s, :b, :dup, :gsub, :gsub!, :force_encoding, :encoding].each do |hook|
  klass = Class.new(String)
  klass.define_method(hook) do |*args, &block|
    $events << hook.to_s
    case hook
    when :to_s, :b, :dup, :gsub then "hooked"
    when :gsub! then replace("hooked")
    when :encoding then Encoding::BINARY
    else super(*args, &block)
    end
  end
  Hooks[hook] = klass
end

def rendered(v)
  ERB::Util.html_escape(v).bytes
rescue StandardError => e
  [e.class.name, e.message.gsub(/0x\h+/, "0x")]
end

def value(v)
  if String === v
    {
      class: v.class.name || "anonymous",
      bytes: String.instance_method(:bytes).bind(v).call,
      encoding: String.instance_method(:encoding).bind(v).call.name,
      frozen: v.frozen?, valid: v.valid_encoding?,
      ivars: v.instance_variables.sort.map { |k| [k, v.instance_variable_get(k)] },
      safe: v.respond_to?(:html_safe?) ? v.html_safe? : nil,
      rendered: ENV["SAFE"] ? rendered(v) : nil
    }
  elsif Hash === v
    v.map { |k, x| [value(k), value(x)] }
  elsif Array === v
    v.map { |x| value(x) }
  else
    v
  end
end

def outcome(factory)
  input = factory.call
  $events = []
  begin
    result = yield(input)
    {result: value(result), input: value(input), events: $events}
  rescue StandardError => e
    {error: [e.class.name, e.message.gsub(/0x\h+/, "0x")], input: value(input), events: $events}
  end
end

rows = {}
methods = {
  escape: ->(s) { Rack::Utils.escape(s) },
  unescape: ->(s) { Rack::Utils.unescape(s) },
  query_unescape: ->(s) { Rack::Utils.default_query_parser.send(:unescape, s) },
  build_query: ->(s) { Rack::Utils.build_query("x" => s) },
  build_nested_query: ->(s) { Rack::Utils.build_nested_query("x" => s) },
  cookie: ->(s) { Rack::Utils.set_cookie_header("x", value: s, path: "/") }
}
raws = ["", "a", "~", "*", "a+%2B", "%", "%FF", "<img src=x onerror=alert(1)>", "\xFF".b, "a b"]
raws.each_with_index do |raw, i|
  [Encoding::UTF_8, Encoding::BINARY, Encoding::UTF_16LE].each do |enc|
    [false, true].each do |frozen|
      factories = {
        plain: -> { raw.dup.force_encoding(enc) },
        ivar: -> { raw.dup.force_encoding(enc).tap { |s| s.instance_variable_set(:@tag, "tag") } },
        tagged: -> { Tagged.new(raw).force_encoding(enc).tap { |s| s.instance_variable_set(:@tag, "tag") } }
      }
      Hooks.each do |hook, klass|
        factories["subclass_#{hook}"] = -> { klass.new(raw).tap { |s| String.instance_method(:force_encoding).bind(s).call(enc) } }
      end
      [:to_s, :b, :dup, :encoding, :gsub].each do |hook|
        factories["singleton_#{hook}"] = -> {
          raw.dup.force_encoding(enc).tap do |s|
            s.define_singleton_method(hook) { |*| $events << hook.to_s; hook == :encoding ? Encoding::BINARY : "hooked" }
          end
        }
      end
      if ENV["SAFE"] && enc.ascii_compatible? && raw.dup.force_encoding(enc).valid_encoding?
        [:safe, :unsafe, :safe_dup, :unsafe_dup].each do |kind|
          factories[kind] = -> {
            s = raw.dup.force_encoding(enc).html_safe
            s.gsub!("x", "x") if kind.to_s.start_with?("unsafe")
            kind.to_s.end_with?("dup") ? s.dup : s
          }
        end
      end
      factories.each do |kind, original|
        factory = -> { s = original.call; frozen ? s.freeze : s }
        methods.each do |name, call|
          rows["#{kind}/#{i}/#{enc}/#{frozen}/#{name}"] = outcome(factory, &call)
        end
      end
    end
  end
end

[:plain, :tagged, :safe, :unsafe, :unsafe_dup].each do |kind|
  next if [:safe, :unsafe, :unsafe_dup].include?(kind) && !ENV["SAFE"]
  ["a=b&x=%2B", "a=%", "a=%FF", "a=b; x=%2B"].each do |raw|
    factory = -> {
      s = kind == :tagged ? Tagged.new(raw) : raw.dup
      if [:safe, :unsafe, :unsafe_dup].include?(kind)
        s = s.html_safe
        s.gsub!("a", "a") if kind != :safe
        s = s.dup if kind == :unsafe_dup
      end
      s
    }
    {parse_query: ->(s) { Rack::Utils.parse_query(s) }, parse_nested_query: ->(s) { Rack::Utils.parse_nested_query(s) },
      parse_cookie: ->(s) { Rack::Utils.parse_cookies_header(s) }}.each do |name, call|
      rows["caller_#{kind}/#{raw}/#{name}"] = outcome(factory, &call)
    end
  end
end
puts JSON.generate(rows)
