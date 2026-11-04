# Differential harness, round 3: Strong Parameters and core extensions.
#   BUNDLE_GEMFILE=.../Gemfile bundle exec ruby sp.rb OUT [params|core]
# Inputs come from a fixed seed with core Ruby only, before Rails loads, so both trees see the same inputs.
require "bigdecimal"
require "date"
SEED = Integer(ENV.fetch("SEED", "20261104"))
N = Integer(ENV.fetch("N", "3000"))
OUT = ARGV.shift
ONLY = ARGV
R = Random.new(SEED)
def pick(a) = a[R.rand(a.size)]
KEYS = %w[a b c id name tags user user_attributes items 0 1 x_id x(1i) x(2i) x(3i) _destroy email].freeze
ALPHA = (("a".."z").to_a + ["A", "Z", "0", "9", " ", "_", "-", ".", "é", "ß", "日", "<", "&", "\u00a0", "İ", "ı"]).freeze
def rstr(max = 8) = Array.new(R.rand(max + 1)) { pick(ALPHA) }.join

# Raw params as they arrive from Rack: strings, arrays, hashes, nil, uploaded-file stand-ins.
def rparam(depth = 0)
  case depth > 3 ? R.rand(3) : R.rand(9)
  when 0 then pick([nil, "", "1", "0", "true", rstr, " x "])
  when 1 then rstr
  when 2 then pick([1, 1.5, true, false, :sym, BigDecimal("1.1"), Date.new(2026, 11, 4)])
  when 3, 4 then Array.new(R.rand(4)) { rparam(depth + 1) }
  when 5 then Array.new(R.rand(3)) { rhash(depth + 1) }
  when 6 then { "0" => rhash(depth + 1), "1" => rhash(depth + 1) }.first(R.rand(1..2)).to_h
  else rhash(depth + 1)
  end
end
def rhash(depth = 0) = Array.new(R.rand(5)).to_h { [pick(KEYS), rparam(depth)] }

# Filters as an app would write them.
def rfilter(depth = 0)
  case depth > 2 ? R.rand(2) : R.rand(7)
  when 0 then pick(KEYS).to_sym
  when 1 then pick(KEYS)
  when 2 then { pick(KEYS).to_sym => [] }
  when 3 then { pick(KEYS).to_sym => Array.new(1 + R.rand(3)) { rfilter(depth + 1) } }
  when 4 then { pick(KEYS).to_sym => {} }
  when 5 then { pick(KEYS).to_sym => [Array.new(1 + R.rand(2)) { rfilter(depth + 1) }] }
  else { pick(KEYS) => Array.new(1 + R.rand(2)) { rfilter(depth + 1) } }
  end
end
def rfilters = Array.new(1 + R.rand(4)) { rfilter }

PARAM_CASES = Array.new(N) do
  root = pick(%w[user post items a])
  raw = { root => pick([rhash, rhash, rparam, Array.new(R.rand(3)) { rhash }]) }.merge(rhash)
  raw.delete(root) if R.rand(10).zero?
  [raw, rfilters, root, pick([nil, nil, :raise, :log])]
end

INFL_WORDS = %w[person Person octopus status news axis matrix child man woman cow mouse ox Haus Kind Buch Maus
  Straße straße Ärger öl İstanbul ıslak IŞIK işık Ünlü çocuk kitap sheep fish data datum alias bus quiz] +
  Array.new(N / 3) { rstr(10) }
LOCALES = %i[en de tr fr].freeze
DURATIONS = Array.new(N) { Array.new(1 + R.rand(4)) { u = pick(%i[seconds minutes hours days weeks months years]); [u, pick(%i[months years].include?(u) ? [0, 1, -1, 2, 12, 13, -25] : [0, 1, -1, 2, 7, 12, 30, 59, 61, 365, 1.5, 0.25, -2.5])] } }
DUR_OPS = Array.new(N) { pick(%i[+ - * / % -@ abs in_parts round]) }
NESTED = Array.new(N) do
  build = ->(d) {
    case d > 3 ? R.rand(5) : R.rand(9)
    when 0 then pick([nil, true, false, 0, -1, 2**64, 1.5, -0.0, 1e20, 1e-7, Float::INFINITY, Float::NAN])
    when 1 then rstr
    when 2 then [:bd, pick(["1.10", "0", "-0", "1e40", "NaN", "Infinity", "123.4567890123456789"])]
    when 3 then [:time, R.rand(-2_000_000_000..4_000_000_000), R.rand(1_000_000), pick(["UTC", "Asia/Kolkata", "America/New_York"])]
    when 4 then pick([:sym, :"a b", [:date, R.rand(2_400_000..2_500_000)], [:dur, R.rand(-100_000..100_000)], [:range, 1, 5], [:set, 1, 2], [:struct], [:obj], [:regexp]])
    when 5, 6 then Array.new(R.rand(4)) { build.(d + 1) }
    else Array.new(R.rand(4)).to_h { [pick([rstr(4), rstr(3).to_sym, R.rand(5), nil, 1.5]), build.(d + 1)] }
    end
  }
  build.(0)
end
NUM_STRS = ["", " ", "0", "1", "-1", "1.5", "1e3", "0x1A", "0b11", "1_000", "١٢", " 12 ", "12abc", "abc", "1.", ".5",
  "-0", "+3", "1,5", "Infinity", "NaN", "9" * 30, "1/3", "2026-11-04", "10:20", "true"] + Array.new(N / 3) { Array.new(R.rand(1..8)) { pick(%w[0 1 2 9 . - e _ + x]) }.join }
NUMS = [0, 1, -1, 0.1, -0.0, 1.5, 2.675, 1e15, 1e16, 1e-7, 2**64, -(2**70), Float::INFINITY, Float::NAN, Rational(1, 3)] + Array.new(N / 3) { pick([R.rand(-10**12..10**12), R.rand * 10**R.rand(-8..12), R.rand(-10**6..10**6) / 100.0]) }

require "action_controller"
require "active_support/all"
require "set"

$out = File.open(OUT, "w")
def rep(v, d = 0)
  return "…" if d > 8
  s = case v
      when ActionController::Parameters then "P(#{v.permitted?})" + rep(v.to_unsafe_h, d + 1)
      when ActiveSupport::HashWithIndifferentAccess then "HWIA{" + v.map { |k, x| "#{rep(k, d + 1)}=>#{rep(x, d + 1)}" }.join(", ") + "}"
      when Hash then "{" + v.map { |k, x| "#{rep(k, d + 1)}=>#{rep(x, d + 1)}" }.join(", ") + "}"
      when Array then "[" + v.map { rep(_1, d + 1) }.join(", ") + "]"
      when ActiveSupport::SafeBuffer then "SB(#{v.html_safe?})#{v.to_str.inspect}"
      when String then (v.frozen? ? "F:" : "") + (v.encoding == Encoding::UTF_8 ? v.inspect : "#{v.encoding}:#{v.b.inspect}")
      when ActiveSupport::Duration then "D #{v.inspect} #{v.parts.sort_by { |k, _| k.to_s }.inspect} #{v.value.inspect} #{v.value.class}"
      when ActiveSupport::TimeWithZone then "TWZ #{v.utc.strftime("%F %T.%N")} #{v.time_zone.name}"
      when Float, Integer, Rational, BigDecimal then "#{v.class}:#{v.inspect}"
      else "#{v.class}:#{v.inspect}"
      end
  s = s.gsub(/0x\h{6,}/, "0x")
  s.size > 3000 ? s[0, 3000] + "…" : s
end
def run(key)
  r = begin
    rep(yield)
  rescue Exception => e
    raise if e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
    "!#{e.class}: #{e.message.to_s.gsub("\n", "\\n").gsub(/0x\h{6,}/, "0x").gsub(/#<[A-Z][\w:]*:0x>/, "#<obj>")[0, 400]}"
  end
  $out.puts "#{key}\t#{r}"
end
def section(name) = (ONLY.empty? || ONLY.include?(name)) && yield

section("params") do
  logged = []
  ActiveSupport::Notifications.subscribe("unpermitted_parameters.action_controller") { |*, payload| logged << payload[:keys] }
  PARAM_CASES.each_with_index do |(raw, filters, root, unpermitted), i|
    ActionController::Parameters.action_on_unpermitted_parameters = unpermitted
    ActionController::Parameters.permit_all_parameters = false
    mk = -> { ActionController::Parameters.new(raw) }
    logged.clear
    run("params/permit/#{i}") { [mk.().permit(*filters), logged.dup] }
    run("params/require/#{i}") { v = mk.().require(root); v.is_a?(ActionController::Parameters) ? v.permit(*filters) : v }
    run("params/require_many/#{i}") { mk.().require([root, raw.keys.first].uniq) }
    run("params/expect/#{i}") { mk.().expect(root => filters) }
    run("params/expect_array/#{i}") { mk.().expect(root => [filters]) }
    run("params/expect_bare/#{i}") { mk.().expect(*filters) }
    run("params/expect_bang/#{i}") { mk.().expect!(root => filters) }
    run("params/fetch/#{i}") { [mk.().fetch(root, nil), mk.().dig(root, 0), mk.().slice(*raw.keys.first(2)).keys, mk.().except(root).keys] }
    run("params/to_h/#{i}") { p = mk.().permit(*filters); [p.to_h, p.to_hash, p.to_query, p.keys, p.empty?, p.include?(root)] }
    run("params/unsafe/#{i}") { p = mk.(); [p.to_unsafe_h, p.deep_dup.to_unsafe_h == p.to_unsafe_h, p.transform_keys(&:upcase).keys, p.deep_transform_keys(&:to_s).to_unsafe_h, p.reject { |k, _| k == root }.keys, p.select { |k, _| k == root }.keys] }
    run("params/merge/#{i}") { mk.().merge(root => "x").merge!("z" => [1]).permit(root, z: []) }
    run("params/inspect/#{i}") { mk.().permit(*filters).inspect }
    run("params/eq/#{i}") { [mk.() == mk.(), mk.().permit(*filters) == mk.().permit(*filters), mk.().permit(*filters).hash == mk.().permit(*filters).hash] }
    run("params/extract/#{i}") { mk.().extract_value(root) rescue $!.class }
  end
  ActionController::Parameters.action_on_unpermitted_parameters = nil
end

def bd(s) = BigDecimal(s)
def nval(v)
  case v
  when Array
    case v.first
    when :bd then BigDecimal(v[1])
    when :time then Time.at(v[1], v[2]).in_time_zone(v[3])
    when :date then Date.jd(v[1])
    when :dur then ActiveSupport::Duration.build(v[1])
    when :range then v[1]..v[2]
    when :set then Set[v[1], v[2]]
    when :struct then Struct.new(:a, :b).new(1, "x")
    when :obj then Object.new.tap { _1.instance_variable_set(:@a, 1) }
    when :regexp then /a+b/i
    else v.map { nval(_1) }
    end
  when Hash then v.to_h { |k, x| [k, nval(x)] }
  else v
  end
end

section("core") do
  I18n.available_locales = LOCALES
  ActiveSupport::Inflector.inflections(:de) do |inflect|
    inflect.plural(/\z/, "e"); inflect.plural(/(h|k)aus\z/i, '\1äuser'); inflect.irregular("Kind", "Kinder"); inflect.uncountable("Geld")
  end
  ActiveSupport::Inflector.inflections(:tr) { |inflect| inflect.plural(/\z/, "ler"); inflect.acronym("İSTANBUL") }
  I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { "ä" => "ae", "ö" => "oe", "ü" => "ue", "ß" => "ss" } } })
  I18n.backend.store_translations(:tr, i18n: { transliterate: { rule: { "ı" => "i", "İ" => "I", "ş" => "s", "ç" => "c", "ğ" => "g" } } })
  INFL_WORDS.each_with_index do |w, i|
    LOCALES.each do |l|
      run("core/infl/#{l}/#{i}") { [w.pluralize(l), w.singularize(l), w.pluralize(2, l), w.camelize, w.underscore, w.titleize, w.humanize, w.classify, w.tableize] }
      run("core/param/#{l}/#{i}") { [w.parameterize(locale: l), w.parameterize(separator: "_", preserve_case: true, locale: l), ActiveSupport::Inflector.transliterate(w, locale: l), ActiveSupport::Inflector.transliterate(w, "*", locale: l)] }
      run("core/i18n_infl/#{l}/#{i}") { I18n.with_locale(l) { [w.pluralize, w.parameterize, w.titleize, w.humanize, [w, "x"].to_sentence] } }
    end
  end
  DURATIONS.each_with_index do |spec, i|
    d = spec.sum(0.seconds) { |u, n| n.public_send(u) }
    o = DURATIONS[(i + 1) % N].sum(0.seconds) { |u, n| n.public_send(u) }
    run("core/dur/#{i}") { [d, d.parts, d.in_seconds, d.in_minutes, d.in_hours, d.in_days, d.in_weeks, d.in_months, d.in_years, d.to_i, d.iso8601, d.inspect, d.as_json, d.to_json] }
    run("core/dur_op/#{i}") do
      case DUR_OPS[i]
      when :+ then [d + o, d + 1, 1 + d, d + 1.5]
      when :- then [d - o, d - 1, 10 - d]
      when :* then [d * 2, d * 1.5, d * o.to_i.clamp(-3, 3), 3 * d]
      when :/ then [d / 2, d / 1.5, (d / o rescue $!), (d / 0 rescue $!)]
      when :% then [d % 7.days, d % 2, (d % o rescue $!)]
      when :-@ then [-d, +d]
      when :abs then [d.abs, d.abs.parts, (d <=> o), d == o, d.eql?(d.dup), d.hash == d.dup.hash]
      when :in_parts then [ActiveSupport::Duration.build(d.to_i), ActiveSupport::Duration.build(d.to_i).parts, ActiveSupport::Duration.parse(d.iso8601)]
      else [d.round(1), (d.to_f.round(3) rescue $!)]
      end
    end
    run("core/dur_time/#{i}") { t = Time.utc(2026, 1, 31, 12, 30); [t + d, t - d, d.since(t), d.ago(t), d.from_now.class, Date.new(2024, 2, 29) + d, t.in_time_zone("America/New_York") + d] }
  end
  NESTED.each_with_index do |raw, i|
    v = nval(raw)
    run("core/as_json/#{i}") { v.as_json }
    run("core/to_json/#{i}") { v.to_json }
    run("core/as_json_opts/#{i}") { [v.as_json(only: "a"), v.as_json(except: [:a]), (v.is_a?(Hash) ? v.as_json(only: v.keys.first(1)) : nil)] }
    run("core/json_encode/#{i}") { ActiveSupport::JSON.encode(v) }
    run("core/json_roundtrip/#{i}") { ActiveSupport::JSON.decode(ActiveSupport::JSON.encode(v)) }
  end
  NUM_STRS.each_with_index do |s, i|
    run("core/str_num/#{i}") { [s.to_i, s.to_f, (s.to_d rescue $!), s.to_r, s.to_c, (Integer(s, exception: false)), (Float(s, exception: false)), (BigDecimal(s, exception: false))] }
    run("core/str_conv/#{i}") { [(s.to_date rescue $!), (s.to_time rescue $!), (s.to_datetime rescue $!), s.inquiry.zero?, s.squish, s.truncate(3), s.to_param, s.to_query("k"), s.html_safe.to_s, s.is_utf8?] }
  end
  NUMS.each_with_index do |n, i|
    run("core/num_fs/#{i}") { [n.to_fs, (n.to_fs(:delimited) rescue $!), (n.to_fs(:rounded, precision: 2) rescue $!), (n.to_fs(:human) rescue $!), (n.to_fs(:human_size) rescue $!), (n.to_fs(:percentage) rescue $!), (n.to_fs(:currency) rescue $!), (n.to_fs(:phone) rescue $!)] }
    run("core/num_conv/#{i}") { [(n.to_d rescue $!), n.to_param, n.to_query("k"), n.as_json, n.to_json, (n.round(2) rescue $!), (n.in_milliseconds rescue $!), (n.seconds rescue $!), (n.byte rescue $!), (n.kilobytes rescue $!), (n.megabytes rescue $!), (n.multiple_of?(3) rescue $!), (n.ordinalize rescue $!)] }
    run("core/num_dur/#{i}") { [(n.days rescue $!), (n.months rescue $!), (n.years rescue $!), (n.minutes.in_seconds rescue $!)] }
  end
end
$out.close
