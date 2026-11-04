# Differential harness: run with `bundle exec ruby harness.rb OUT [SURFACE...]` inside a Rails checkout.
# Inputs are generated from a fixed seed with core Ruby only, before Rails loads, so both sides see the
# same inputs. Each case writes "surface/function/index<TAB>result-or-exception".
SEED = Integer(ENV.fetch("SEED", "20261104"))
N = Integer(ENV.fetch("N", "2000"))
OUT = ARGV.shift
ONLY = ARGV

R = Random.new(SEED)
def pick(a) = a[R.rand(a.size)]
ALPHA = (("a".."z").to_a + ("A".."Z").to_a + ("0".."9").to_a + [" ", "_", "-", "/", ":", ".", "'", "\"", "&", "<", ">",
  "%", "+", "=", "?", "#", "[", "]", "Ä", "é", "ß", "Æ", "ø", "日", "本", "\u00a0", "\t", "\n", "\u2028", "😀", "İ", "ı"]).freeze
WORDS = %w[person people octopus octopi status news series axis matrix index quiz ox mouse crisis sheep fish
  datum data equipment information child children man woman cow virus alias bus shoe house move tooth goose
  user user_id post comment admin category address analysis basis diagnosis half wife knife leaf medium
  HTTP API URL ID Html JSON xml SSL].freeze
def rstr(max = 16, alpha = ALPHA) = Array.new(R.rand(max + 1)) { pick(alpha) }.join
def rword
  case R.rand(6)
  when 0 then rstr(12)
  when 1 then pick(WORDS)
  when 2 then Array.new(1 + R.rand(3)) { pick(WORDS) }.join(pick(["_", " ", "-", "", "/", "::"]))
  when 3 then Array.new(1 + R.rand(3)) { pick(WORDS).capitalize }.join(pick(["", "::", "/"]))
  when 4 then pick(WORDS).upcase + pick(WORDS)
  else rstr(8, ("a".."z").to_a + ["_", "A", "B", "9"])
  end
end

EDGE_WORDS = ["", " ", "a", "A", "_", "__", "-", "::", "/", "person", "People", "octopus", "CamelCase", "camelCase",
  "snake_case", "HTTPServer", "HTTPServerError", "html_tidy", "ApplicationController", "Admin::UsersController",
  "admin/users", "admin/user_settings", "the_quick_brown_fox", "über_cool", "Ærøskøbing", "  spaces  ", "with-dash",
  "x1y2", "ID", "user_id", "_leading", "trailing_", "double__underscore", "ACRONYM", "status", "statuses", "news",
  "series", "axis", "matrix", "index", "quiz", "ox", "oxen", "mouse", "crisis", "café", "日本語", "foo.bar",
  "foo::bar", "Foo::BarBaz", "foo/bar_baz", "SSLError", "IPhone", "iPhone", "ÉCOLE", "İstanbul", "straße",
  "Hello World", "hello world!", "1st place", "123", "x" * 300, "a b  c", "\tTab", "line\nbreak", "😀 emoji",
  "foo_bar_id", "FooBarID", "API::V1::UsersController", "Sheep", "fish", "equipment", "Information",
  "half", "wife", "knife", "leaves", "analyses", "bases", "data", "media", "virus", "viri", "alias", "aliases"].freeze

INFL_INPUTS = EDGE_WORDS + Array.new(N) { rword }

NUM_EDGE = [[:i, 0], [:f, -0.0], [:i, 1], [:i, -1], [:f, 0.5], [:f, 0.005], [:f, 1.005], [:f, 999.995], [:i, 1000],
  [:i, 1023], [:i, 1024], [:i, 1_048_576], [:f, 1e15], [:f, 1e21], [:f, -1234567.891], [:f, Float::INFINITY],
  [:f, -Float::INFINITY], [:f, Float::NAN], [:s, "123"], [:s, "abc"], [:s, "1,234"], [:s, "-0"], [:s, " 12 "],
  [:s, "1e3"], [:s, "0x1A"], [:n, nil], [:d, "0.1"], [:d, "123456789.123456789"], [:d, "-0.0005"], [:i, 10**30],
  [:r, [1, 3]], [:f, 0.1 + 0.2], [:f, 2.675], [:f, 1.15], [:f, 9.995], [:i, 999_999], [:i, 999_500],
  [:i, 1_000_000_000_000_000], [:f, 5e-324], [:s, "12.5%"], [:s, "<b>1</b>"]].freeze
NUM_INPUTS = NUM_EDGE + Array.new(N) do
  case R.rand(6)
  when 0 then [:i, R.rand(-10**12..10**12)]
  when 1 then [:i, R.rand(-2000..2000)]
  when 2 then [:f, (R.rand - 0.5) * 10**R.rand(-6..16)]
  when 3 then [:f, (R.rand(-100_000..100_000) / 1000.0)]
  when 4 then [:d, format("%.#{R.rand(0..12)}f", (R.rand - 0.5) * 10**R.rand(0..14))]
  else [:s, pick(["%d", "%.2f", "%d,%03d", "%e"]) % [R.rand(-99999..99999), R.rand(0..999)]]
  end
end
PHONE_INPUTS = ["", "5551234", "1235551234", "+1 (555) 123-4567", "12345678901", "abc", "555 123 4567 x89"] +
  Array.new(N / 4) { Array.new(R.rand(4..14)) { R.rand(10) }.join }

ZONES = ["UTC", "America/New_York", "Europe/Berlin", "Asia/Kolkata", "Australia/Lord_Howe", "Pacific/Apia",
  "America/Sao_Paulo", "Pacific/Chatham", "Europe/London", "America/St_Johns"].freeze
TIME_EDGE = [0, 1_773_039_599, 1_773_039_600, 1_774_745_999, 1_774_746_000, 1_792_889_999, 1_792_890_000,
  1_793_512_799, 1_793_512_800, 951_782_400, 1_709_164_800, 1_709_251_199, 2_147_483_647, -1, 946_684_799,
  1_798_761_599, 1_767_225_599, 1_767_225_600, 1_772_323_199, 1_780_000_000].freeze
TIME_INPUTS = TIME_EDGE.map { [_1, 0] } + Array.new(N / 4) { [R.rand(-500_000_000..2_200_000_000), pick([0, 0, R.rand(1_000_000)])] }
DUR_UNITS = %i[seconds minutes hours days weeks months years].freeze
DUR_INPUTS = [[[:seconds, 0]], [[:months, 1]], [[:months, -1]], [[:years, 1]], [[:days, 1]], [[:weeks, 1]],
  [[:months, 1], [:days, 1]], [[:days, 1.5]], [[:months, 0.5]], [[:years, 0.25]], [[:seconds, 0.001]],
  [[:hours, 25]], [[:days, 30]], [[:days, 31]], [[:months, 12]], [[:years, -1], [:months, 13]], [[:seconds, 86_400]],
  [[:minutes, -90]], [[:weeks, 52]], [[:seconds, 1.5]]] +
  Array.new(N / 4) { Array.new(1 + R.rand(3)) { [pick(DUR_UNITS), pick([R.rand(-50..50), R.rand(-1000..1000), (R.rand(-100..100) / 4.0)])] } }
ISO_DUR = ["P1Y2M3DT4H5M6S", "PT0.5S", "P1W", "-P1D", "P1.5D", "invalid", "P", "PT", "P0D", "PT1H", "P1M",
  "PT1M", "P1Y1W", "PT-1S", "P1DT", "P,5D", "P1,5D", "P1.5Y", "PT1.25H", "P10000Y", "+P1D", "p1d", "P1D ", " P1D",
  "P1Y2M3W4DT5H6M7.8S", "PT0S", "PT36H", "P2W3D"] + Array.new(N / 8) { "P" + rstr(8, %w[1 2 3 . , Y M W D T H S - 0]) }
TIME_STRINGS = ["2026-03-08 02:30", "2026-03-29 02:30:00", "2026-11-01 01:30", "2026-10-25 02:30", "2026-02-29",
  "2024-02-29", "2026-13-01", "12:00", "noon", "", "  ", "2026-01-01T00:00:00Z", "2026-01-01T00:00:00+05:30",
  "2026-01-01 00:00:00 -0800", "Thu, 05 Nov 2026 10:00:00 GMT", "20260101", "1/2/2026", "2026-W10", "garbage",
  "2026-06-15T12:00:00.123456789Z", "1970-01-01", "0001-01-01", "9999-12-31 23:59:59", "2026-06-15 25:00",
  "2026-06-15T12:00:00.5+01:00", "T12:00"] + Array.new(N / 8) { format("%04d-%02d-%02d %02d:%02d:%02d", R.rand(1..9999), R.rand(0..13), R.rand(0..32), R.rand(0..25), R.rand(0..61), R.rand(0..61)) }

def rscalar
  case R.rand(10)
  when 0 then nil
  when 1 then R.rand(2) == 0
  when 2 then R.rand(-1000..1000)
  when 3 then (R.rand - 0.5) * 10**R.rand(0..6)
  when 4 then rstr(6).to_sym
  else rstr(10)
  end
end
def rnested(depth = 0)
  return rscalar if depth > 2 || R.rand(3) == 0
  if R.rand(2) == 0
    Array.new(R.rand(4)) { rnested(depth + 1) }
  else
    Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(4).to_sym, R.rand(10), "a b", "x[y]", ""]), rnested(depth + 1)] }
  end
end
QUERY_INPUTS = [{}, { a: nil }, { a: [] }, { a: {} }, { "a b" => "c d" }, { a: [1, 2] }, { a: { b: { c: 1 } } },
  { a: [{ b: 1 }, { b: 2 }] }, { a: true, b: false }, { "x[y]" => "z" }, { a: [nil] }, { a: [[1, 2]] }, { a: :sym },
  { 1 => 2 }, { a: "&=?#" }, { a: "ü" }, [1, 2], [], "str", nil, 1, { a: [{}] }, { a: [[]] }] + Array.new(N) { rnested }

def rjson(depth = 0)
  case R.rand(depth > 2 ? 8 : 11)
  when 0 then nil
  when 1 then R.rand(2) == 0
  when 2 then R.rand(-10**20..10**20)
  when 3 then [:f, pick([(R.rand - 0.5) * 10**R.rand(-10..25), Float::NAN, Float::INFINITY, -0.0, 0.1, 1e20, 1e-7])]
  when 4 then [:d, format("%.#{R.rand(0..8)}f", (R.rand - 0.5) * 10**R.rand(0..12))]
  when 5 then [:t, R.rand(-100_000_000..2_200_000_000), R.rand(1_000_000), pick(ZONES)]
  when 6 then [:date, R.rand(-100_000..100_000)]
  when 7 then rstr(12)
  when 8 then Array.new(R.rand(4)) { rjson(depth + 1) }
  when 9 then Array.new(R.rand(4)).to_h { [pick([rstr(5), rstr(4).to_sym, R.rand(100)]), rjson(depth + 1)] }
  else [:sym, rstr(5)]
  end
end
JSON_INPUTS = ["<script>", "\u2028\u2029", "a&b", "\"quoted\"", "\\", "\x00\x1f", "é日😀", "</script>", "'", "\x7f",
  [:f, Float::NAN], [:f, 1e100], [:f, 0.1], [:d, "1.10"], [:d, "1e400"], [:t, 0, 0, "UTC"], [:t, 0, 123_456, "Asia/Kolkata"],
  [:date, 0], [:sym, "sym"], [:range, 1, 5], [:set, [1, 2]], [:struct, 1, "x"], [:regexp, "a.b"], [:bad_utf8],
  [:ostruct], [:dt, 0], [:dur, 3600], [:bigint, 2**64], { "a" => { b: [1, nil] } }] + Array.new(N) { rjson }
JSON_DECODE = ['{"a":1}', '[1,2', '"x"', "1", "null", '{"a":"2026-01-01T00:00:00Z"}', '{"a":"2026-01-01"}', "",
  " ", '{"a":NaN}', "[1e400]", '{"a":"\u2028"}', '{"__proto__":1}', "[-0]", "[1.0]", '{"a":1,"a":2}', "\"\\ud800\""] +
  Array.new(N / 4) { rstr(10, ['{', '}', '[', ']', '"', ':', ',', '1', 'a', ' ', '.', 'e', '-', 'n', 'u', 'l', 't', 'r']) }

ESC_EDGE = ["", "&", "&amp;", "&amp", "&#39;", "&#x27;", "&#123;", "&#xZZ;", "&lt;&lt;", "<>\"'&", "\u2028", "</script>",
  "<!--", "-->", "\x00", "é", "&nbsp;", "&NotAName;", "&#1234567;", "\\u003c", "a b", "%41", "日本", "😀", "\r\n",
  "javascript:alert(1)", "data-x", "1foo", "foo bar", "-x", ".x", "x:y", "\u0080"]
ESC_INPUTS = ESC_EDGE + Array.new(N) { rstr(14) }
def rattr_val(depth = 0)
  case R.rand(depth > 0 ? 7 : 9)
  when 0 then nil
  when 1 then R.rand(2) == 0
  when 2 then R.rand(-100..100)
  when 3 then [:sym, rstr(5)]
  when 4 then [:safe, rstr(8)]
  when 5, 6 then rstr(10)
  when 7 then Array.new(R.rand(4)) { rattr_val(1) }
  else Array.new(R.rand(3)).to_h { [rstr(4), rattr_val(1)] }
  end
end
ATTR_KEYS = %w[class id data aria title href style disabled checked required multiple readonly value name
  onclick rel type for selected hidden open autofocus x-data data-turbo].freeze
TAG_INPUTS = Array.new(N) do
  { name: pick(%w[div span p a input br img option button section my-tag foo_bar svg]),
    content: pick([nil, rstr(10), [:safe, rstr(10)], ""]),
    attrs: Array.new(R.rand(5)).to_h { [pick(ATTR_KEYS + [rstr(5)]), rattr_val] } }
end

ROUTE_GEN = Array.new(N) do
  base = pick([
    { controller: "posts", action: "index" }, { controller: "posts", action: "show" }, { controller: "posts", action: "edit" },
    { controller: "admin/users", action: "show" }, { controller: "pages", action: "show" }, { controller: "files", action: "show" },
    { controller: "posts/comments", action: "index" }, { controller: "comments", action: "show" }, { controller: "home", action: "index" },
    { controller: "missing", action: "x" }, { action: "show" }, { controller: "search", action: "index" }])
  extra = {}
  extra[:id] = pick([rstr(8), R.rand(1000), nil, "", "a/b", "a.b", "1.json", [:obj, R.rand(100)], "ü ö", "%2F"]) if R.rand(2) == 0
  extra[:post_id] = pick([R.rand(100), rstr(5)]) if R.rand(4) == 0
  extra[:slug] = rstr(10) if R.rand(3) == 0
  extra[:path] = pick(["a/b/c", "a b", "", "x.y", rstr(10)]) if R.rand(4) == 0
  extra[:locale] = pick(["en", "de", nil, "", "fr-CA"]) if R.rand(3) == 0
  extra[:format] = pick(["json", "html", nil, "", "a.b", "x y"]) if R.rand(3) == 0
  extra[:anchor] = pick(["top", "a b", "", "x#y", nil]) if R.rand(5) == 0
  extra[:q] = rnested(1) if R.rand(3) == 0
  extra[:page] = pick([1, "2", nil]) if R.rand(4) == 0
  extra[:trailing_slash] = true if R.rand(8) == 0
  extra[:only_path] = pick([true, false]) if R.rand(2) == 0
  extra[:host] = pick(["example.org", "x.example.com:8080", "", "ex ample.com"]) if R.rand(6) == 0
  extra[:protocol] = pick(["https", "https://", "ftp", "//"]) if R.rand(6) == 0
  extra[:port] = pick([80, 443, 3000, nil, "8080"]) if R.rand(8) == 0
  extra[:params] = rnested(1) if R.rand(8) == 0
  extra[:script_name] = pick(["/app", "", "/"]) if R.rand(8) == 0
  base.merge(extra)
end
NAMED_GEN = Array.new(N / 2) do
  [pick(%i[posts_path post_path edit_post_path new_post_path post_comments_path post_comment_path admin_user_path page_path
    file_path root_path search_path localized_path posts_url post_url]),
   Array.new(R.rand(3)) { pick([R.rand(100), rstr(6), nil, "a/b", "x.y", [:obj, R.rand(9)]]) },
   R.rand(2) == 0 ? {} : Array.new(R.rand(3)).to_h { [pick(%i[format anchor locale q id only_path page]), pick([rstr(4), nil, 1, rnested(1)])] }]
end
SEGS = %w[posts 1 2 edit new comments admin users pages files search en de a b x.json x.y %20 %2F ü .. . - _ a%2Fb ~ + *].freeze
ROUTE_REC = ["/", "", "/posts", "/posts/", "/posts/1", "/posts/1.json", "/posts/1/edit", "/posts/new", "/posts/1/comments",
  "/admin/users/5", "/pages/about", "/pages/a.b", "/files/a/b/c.txt", "/en/localized", "/localized", "/search?q=x",
  "/posts/%E2%9C%93", "/posts/1%2F2", "//posts", "/POSTS", "/posts/1.", "/posts/.json", "/posts/1..json"] +
  Array.new(N) { "/" + Array.new(R.rand(1..4)) { pick(SEGS) }.join("/") + pick(["", "", ".json", "/", ".x"]) }

AR_COLS = %i[id title body published views score published_at author_id status headline created_on].freeze
def rarval
  case R.rand(14)
  when 0 then nil
  when 1 then R.rand(2) == 0
  when 2 then R.rand(-5..100)
  when 3 then rstr(6)
  when 4 then Array.new(R.rand(4)) { pick([R.rand(10), nil, rstr(3)]) }
  when 5 then []
  when 6 then [:range, R.rand(0..5), pick([R.rand(5..10), nil]), R.rand(2) == 0]
  when 7 then [:range, nil, R.rand(0..10), R.rand(2) == 0]
  when 8 then [:date, R.rand(0..20_000)]
  when 9 then [:time, R.rand(0..2_000_000_000)]
  when 10 then (R.rand * 100).round(3)
  when 11 then [:sym, pick(%w[draft published archived bogus])]
  when 12 then [:dec, format("%.3f", R.rand * 100)]
  else [:sub]
  end
end
def rcond = Array.new(1 + R.rand(2)).to_h { [pick(AR_COLS), rarval] }
AR_OPS = %i[where where_not or order joins left_joins includes group having limit offset distinct select reorder
  unscope_order rewhere in_order_of where_assoc where_string where_named not_and invert_where excluding none_or
  where_tuple order_nulls].freeze
AR_INPUTS = Array.new(N) do
  Array.new(1 + R.rand(4)) do
    op = pick(AR_OPS)
    arg = case op
          when :order, :reorder then Array.new(1 + R.rand(2)) { pick([pick(AR_COLS), [:desc, pick(AR_COLS)], [:str, "title DESC"], [:arel, pick(AR_COLS)], [:hash_dir, pick(AR_COLS), pick(%w[asc desc ASC DESC bogus])]]) }
          when :joins, :left_joins, :includes then pick([:author, :comments, [:author, :comments], { comments: :post }])
          when :group, :select then Array.new(1 + R.rand(2)) { pick(AR_COLS + [:str]) }
          when :having then R.rand(10)
          when :limit, :offset then pick([0, 1, 10, nil, "5", -1])
          when :in_order_of then [pick(%i[id status title]), Array.new(R.rand(4)) { pick([R.rand(5), "draft", "x", nil]) }]
          when :where_assoc then [pick([:author, :comments]), pick([{ name: rstr(4) }, { id: [1, 2] }, { body: nil }])]
          when :where_string then [rstr(4), R.rand(10)]
          when :where_named then { t: rstr(4), n: R.rand(10) }
          when :where_tuple then Array.new(R.rand(3)) { [R.rand(5), rstr(2)] }
          when :order_nulls then [pick(AR_COLS), pick(%i[nulls_first nulls_last])]
          else rcond
          end
    [op, arg]
  end
end

# ---- Load Rails ---------------------------------------------------------------------------------------
require "bigdecimal"
require "set"
require "ostruct"
require "active_support"
require "active_support/all"
require "action_view"
require "action_controller"
require "action_dispatch"
require "active_record"

$out = File.open(OUT, "w")
def rep(v)
  s = case v
      when ActiveSupport::SafeBuffer then "SB(#{v.html_safe?}#{",F" if v.frozen?})#{v.to_str.inspect}"
      when ActiveSupport::TimeWithZone then "TWZ #{v.inspect} [#{v.time_zone.name}] #{v.to_r}"
      when Time then "T #{v.inspect}"
      when ActiveSupport::Duration then "D #{v.inspect} #{v.parts.sort_by { |k, _| k.to_s }.inspect} #{v.value.inspect}"
      when String then (v.frozen? ? "F:" : "") + (v.encoding == Encoding::UTF_8 ? v.inspect : "#{v.encoding}:#{v.inspect}")
      when Array then "[" + v.map { rep(_1) }.join(", ") + "]"
      when Hash then "{" + v.map { |k, x| "#{rep(k)}=>#{rep(x)}" }.join(", ") + "}"
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

# ---- Inflections ----------------------------------------------------------------------------------------
section("inflect") do
  fns = {
    pluralize: ->(s) { s.pluralize }, pluralize2: ->(s) { s.pluralize(2) }, pluralize1: ->(s) { s.pluralize(1) },
    singularize: ->(s) { s.singularize }, camelize: ->(s) { s.camelize }, camelize_lower: ->(s) { s.camelize(:lower) },
    underscore: ->(s) { s.underscore }, titleize: ->(s) { s.titleize }, titleize_keep_id: ->(s) { s.titleize(keep_id_suffix: true) },
    humanize: ->(s) { s.humanize }, humanize_nocap: ->(s) { s.humanize(capitalize: false) },
    humanize_keep_id: ->(s) { s.humanize(keep_id_suffix: true) }, tableize: ->(s) { s.tableize },
    classify: ->(s) { s.classify }, dasherize: ->(s) { s.dasherize }, parameterize: ->(s) { s.parameterize },
    parameterize_us: ->(s) { s.parameterize(separator: "_", preserve_case: true) }, parameterize_none: ->(s) { s.parameterize(separator: "") },
    transliterate: ->(s) { ActiveSupport::Inflector.transliterate(s) }, demodulize: ->(s) { s.demodulize },
    deconstantize: ->(s) { s.deconstantize }, foreign_key: ->(s) { s.foreign_key }, foreign_key_nous: ->(s) { s.foreign_key(false) },
    squish: ->(s) { s.squish }, truncate: ->(s) { s.truncate(10) }, truncate_sep: ->(s) { s.truncate(12, separator: " ", omission: "…") },
    truncate_words: ->(s) { s.truncate_words(2) }, truncate_bytes: ->(s) { s.truncate_bytes(7) }, upcase_first: ->(s) { s.upcase_first },
    downcase_first: ->(s) { s.downcase_first }, remove: ->(s) { s.remove(/a/) }, indent: ->(s) { s.indent(2) },
    to_sentence: ->(s) { s.split(/[ _]/).to_sentence }, at: ->(s) { [s.first(3), s.last(2), s.from(2), s.to(1)] },
    starts_ends: ->(s) { [s.starts_with?("a"), s.ends_with?("s")] }, inquiry: ->(s) { s.inquiry.person? },
    safe_constantize: ->(s) { s.safe_constantize.inspect }, ordinalize: ->(s) { s.size.ordinalize + (s.size - 50).ordinalize },
    mb_chars: ->(s) { s.mb_chars.to_s } , is_utf8: ->(s) { s.is_utf8? }, to_time: ->(s) { s.to_time(:utc) }, to_date: ->(s) { s.to_date },
    exclude: ->(s) { s.exclude?("a") }, html_safe: ->(s) { s.html_safe }, strip_heredoc: ->(s) { s.strip_heredoc },
  }
  INFL_INPUTS.each_with_index do |s, i|
    fns.each { |n, f| run("inflect/#{n}/#{i}") { f.(s.dup) } }
  end
  -1000.upto(1000) { |n| run("inflect/ordinal_int/#{n}") { [n.ordinal, n.ordinalize] } }
end

# ---- Numbers --------------------------------------------------------------------------------------------
def num(spec)
  t, v = spec
  case t
  when :i, :f, :s, :n then v
  when :d then BigDecimal(v)
  when :r then Rational(*v)
  end
end
section("number") do
  I18n.available_locales = [:en, :de]
  I18n.backend.store_translations(:de, number: { format: { separator: ",", delimiter: ".", precision: 3 },
    currency: { format: { unit: "€", format: "%n %u", separator: ",", delimiter: "." } },
    human: { storage_units: { format: "%n %u", units: { byte: "Byte", kb: "KB", mb: "MB", gb: "GB", tb: "TB" } } } })
  I18n.backend.store_translations(:en, distance: { unit: "m", thousand: "km", million: "Mm" })
  NH = ActiveSupport::NumberHelper
  av = ActionView::Base.empty
  opts = {
    currency: [:number_to_currency, [{}, { unit: "€", format: "%n %u", separator: ",", delimiter: "." }, { precision: 0 },
      { negative_format: "(%u%n)" }, { locale: :de }, { precision: 3, round_mode: :down }, { strip_insignificant_zeros: true }, { unit: "<b>$</b>" }]],
    human: [:number_to_human, [{}, { precision: 2 }, { significant: false }, { units: { unit: "m", thousand: "km" } },
      { format: "%n%u", precision: 1 }, { strip_insignificant_zeros: false }, { units: :distance }, { round_mode: :up }]],
    human_size: [:number_to_human_size, [{}, { precision: 2 }, { significant: false }, { precision: 1, strip_insignificant_zeros: false }, { locale: :de }]],
    percentage: [:number_to_percentage, [{}, { precision: 0 }, { strip_insignificant_zeros: true }, { format: "%n %" }, { significant: true, precision: 2 }]],
    delimiter: [:number_to_delimited, [{}, { delimiter: "." , separator: "," }, { delimiter_pattern: /(\d+?)(?=(\d\d)+(\d)(?!\d))/ }]],
    rounded: [:number_to_rounded, [{}, { precision: 2 }, { significant: true }, { precision: 2, strip_insignificant_zeros: true },
      { precision: 0, round_mode: :half_even }, { precision: 5, significant: true, strip_insignificant_zeros: true }, { precision: nil }, { precision: -1 }]],
  }
  NUM_INPUTS.each_with_index do |spec, i|
    opts.each do |name, (m, sets)|
      sets.each_with_index do |o, j|
        run("number/#{name}#{j}/#{i}") { NH.public_send(m, num(spec), o) }
      end
    end
    run("number/av_currency/#{i}") { av.number_to_currency(num(spec)) }
    run("number/av_currency_raise/#{i}") { av.number_to_currency(num(spec), raise: true) }
    run("number/av_human_size/#{i}") { av.number_to_human_size(num(spec)) }
    run("number/av_delimited/#{i}") { av.number_with_delimiter(num(spec)) }
    run("number/av_precision/#{i}") { av.number_with_precision(num(spec), precision: 1) }
    run("number/to_fs/#{i}") { v = num(spec); v.respond_to?(:to_fs) ? [v.to_fs(:currency), v.to_fs(:delimited), v.to_fs(:human), v.to_fs(:percentage, precision: 1)] : v }
  end
  PHONE_INPUTS.each_with_index do |p, i|
    [{}, { area_code: true }, { country_code: 1, extension: "12" }, { delimiter: " ", pattern: /(\d{3})(\d{4})$/ }, { raise: true }].each_with_index do |o, j|
      run("number/phone#{j}/#{i}") { NH.number_to_phone(p, o) }
    end
    run("number/av_phone/#{i}") { av.number_to_phone(p, area_code: true) }
  end
end

# ---- Time, Date, Duration -------------------------------------------------------------------------------
def dur(spec) = spec.sum(0.seconds) { |u, n| n.public_send(u) }
section("time") do
  durs = DUR_INPUTS.map { dur(_1) rescue nil }
  DUR_INPUTS.each_with_index do |spec, i|
    run("time/dur_build/#{i}") { d = dur(spec); [d, d.iso8601, d.iso8601(precision: 2), d.to_i, d.in_days, d.in_months, d.inspect] }
    run("time/dur_rebuild/#{i}") { ActiveSupport::Duration.build(dur(spec).to_i) }
    run("time/dur_math/#{i}") { d = dur(spec); [d * 2, d / 2, -d, d + 1, d - 1.day, d % 7.days, d <=> 30.days, d == d.to_i] }
  end
  ISO_DUR.each_with_index do |s, i|
    run("time/dur_parse/#{i}") { d = ActiveSupport::Duration.parse(s); [d, d.iso8601] }
  end
  ZONES.each do |z|
    zone = ActiveSupport::TimeZone[z]
    TIME_INPUTS.each_with_index do |(sec, usec), i|
      k = "#{z}/#{i}"
      run("time/twz/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t, t.dst?, t.utc_offset, t.formatted_offset, t.zone] }
      run("time/fmt/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t.to_fs(:db), t.to_fs(:long), t.to_fs(:rfc822), t.to_fs(:iso8601), t.to_fs(:number), t.iso8601(3), t.xmlschema, t.httpdate, t.to_s, t.inspect, t.to_json] }
      run("time/edges/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t.beginning_of_day, t.end_of_day, t.beginning_of_week, t.beginning_of_week(:sunday), t.end_of_month, t.beginning_of_quarter, t.end_of_year, t.middle_of_day, t.beginning_of_hour, t.end_of_minute] }
      run("time/change/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t.change(hour: 2), t.change(hour: 2, min: 30), t.change(day: 31), t.change(usec: 0), t.change(offset: "+09:00"), t.change(zone: "Asia/Tokyo")] }
      run("time/advance/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t.advance(months: 1, days: -1), t.advance(hours: 24), t.advance(days: 1), t.advance(weeks: 1, seconds: 0.5), t.next_month, t.prev_year, t.next_occurring(:monday), t.prev_occurring(:friday), t.since(86_400), t.ago(3600)] }
      run("time/dates/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); d = t.to_date; [d, d + 1.month, d - 1.year, d.end_of_month, d.beginning_of_week, d.next_weekday, d.prev_weekday, d.to_fs(:long), d.to_fs(:db), d.to_time, d.in_time_zone(zone), d.beginning_of_day, d.end_of_day, d.all_week, d.on_weekend?, Time.days_in_month(d.month, d.year), d.to_fs(:rfc822), d.xmlschema] }
      run("time/compare/#{k}") { t = Time.at(sec, usec).in_time_zone(zone); [t.today?, t.past?, t.future?, t <=> t.utc, t.eql?(t.utc), t == t.to_datetime, t.to_datetime, t.to_i, t.to_f, t.to_r, t.round(1), t.floor, t.ceil, t.localtime("+01:00")] rescue $! }
      durs.each_with_index do |d, j|
        next unless d && (j % 25 == i % 25)
        run("time/plus/#{k}/#{j}") { t = Time.at(sec, usec).in_time_zone(zone); [t + d, t - d, d.since(t), d.ago(t), (t.to_date + d)] }
      end
    end
    TIME_STRINGS.each_with_index do |s, i|
      run("time/parse/#{z}/#{i}") { zone.parse(s) }
      run("time/strptime/#{z}/#{i}") { zone.strptime(s, "%Y-%m-%d %H:%M:%S") }
      run("time/iso8601/#{z}/#{i}") { zone.iso8601(s) }
      run("time/local/#{z}/#{i}") { a = s.scan(/\d+/).map(&:to_i).first(6); a.empty? ? nil : zone.local(*a) }
    end
    run("time/zone_meta/#{z}") { [zone.name, zone.tzinfo.name, zone.formatted_offset, zone.utc_offset, zone.to_s, zone.at(0), zone.now.class] }
  end
  TIME_STRINGS.each_with_index do |s, i|
    run("time/str_to_time/#{i}") { [s.to_time, s.to_time(:utc), s.to_date, s.to_datetime] }
    run("time/date_parse/#{i}") { Date.parse(s).to_fs(:long) }
  end
  [0, 1, 29, 30, 44, 45, 89, 90, 1439, 1440, 2519, 2520, 43_199, 43_200, 86_399, 86_400, 525_599, 525_600, 788_400, 1_051_200, 1_051_199, 10**7].each_with_index do |m, i|
    [m * 60, m * 60 + 29, m * 60 + 30, -m * 60].each_with_index do |secs, j|
      run("time/distance/#{i}/#{j}") { av = ActionView::Base.empty; [av.distance_of_time_in_words(0, secs), av.distance_of_time_in_words(0, secs, include_seconds: true), av.distance_of_time_in_words(0, secs, scope: "datetime.distance_in_words")] }
    end
  end
end

# ---- to_query / to_param --------------------------------------------------------------------------------
section("query") do
  QUERY_INPUTS.each_with_index do |v, i|
    run("query/to_query/#{i}") { v.respond_to?(:to_query) ? v.to_query("ns") : nil }
    run("query/to_param/#{i}") { v.to_param }
    run("query/hash_to_query/#{i}") { v.is_a?(Hash) ? v.to_query : [v].to_query("k") }
    run("query/rack_roundtrip/#{i}") { v.is_a?(Hash) ? Rack::Utils.parse_nested_query(v.to_query) : nil }
    run("query/object_to_query/#{i}") { { "k" => v }.to_query }
  end
end

# ---- JSON -----------------------------------------------------------------------------------------------
JStruct = Struct.new(:a, :b)
def jval(v)
  case v
  when Array
    case v[0]
    when :f then v[1]
    when :d then BigDecimal(v[1])
    when :t then Time.at(v[1], v[2]).in_time_zone(v[3])
    when :date then Date.new(2000, 1, 1) + v[1]
    when :sym then v[1].to_sym
    when :range then (v[1]..v[2])
    when :set then Set.new(v[1])
    when :struct then JStruct.new(v[1], v[2])
    when :regexp then Regexp.new(v[1])
    when :bad_utf8 then "a\xffb".dup.force_encoding("UTF-8")
    when :ostruct then OpenStruct.new(a: 1)
    when :dt then DateTime.new(2026, 1, 1, 12, 0, 0.5r, "+02:00")
    when :dur then v[1].seconds
    when :bigint then v[1]
    else v.map { jval(_1) }
    end
  when Hash then v.to_h { |k, x| [k, jval(x)] }
  else v
  end
end
section("json") do
  JSON_INPUTS.each_with_index do |raw, i|
    run("json/encode/#{i}") { ActiveSupport::JSON.encode(jval(raw)) }
    run("json/to_json/#{i}") { jval(raw).to_json }
    run("json/as_json/#{i}") { jval(raw).as_json }
    run("json/generate/#{i}") { JSON.generate(jval(raw)) }
    run("json/encode_opts/#{i}") { ActiveSupport::JSON.encode(jval(raw), only: "a") }
    run("json/no_escape/#{i}") { begin; ActiveSupport.escape_html_entities_in_json = false; ActiveSupport::JSON.encode(jval(raw)); ensure; ActiveSupport.escape_html_entities_in_json = true; end }
    run("json/precision0/#{i}") { begin; ActiveSupport::JSON::Encoding.time_precision = 0; ActiveSupport::JSON.encode(jval(raw)); ensure; ActiveSupport::JSON::Encoding.time_precision = 3; end }
    run("json/use_standard/#{i}") { begin; ActiveSupport.use_standard_json_time_format = false; jval(raw).to_json; ensure; ActiveSupport.use_standard_json_time_format = true; end }
    run("json/pretty/#{i}") { JSON.pretty_generate(jval(raw).as_json) }
  end
  JSON_DECODE.each_with_index do |s, i|
    run("json/decode/#{i}") { ActiveSupport::JSON.decode(s) }
    run("json/decode_times/#{i}") { begin; ActiveSupport.parse_json_times = true; ActiveSupport::JSON.decode(s); ensure; ActiveSupport.parse_json_times = false; end }
  end
end

# ---- Escaping, SafeBuffer, tag helpers ------------------------------------------------------------------
def aval(v)
  case v
  when Array
    case v[0]
    when :sym then v[1].to_sym
    when :safe then v[1].html_safe
    else v.map { aval(_1) }
    end
  when Hash then v.transform_values { aval(_1) }
  else v
  end
end
section("escape") do
  av = ActionView::Base.empty
  ESC_INPUTS.each_with_index do |s, i|
    o = ESC_INPUTS[(i * 7 + 3) % ESC_INPUTS.size]
    run("escape/html_escape/#{i}") { ERB::Util.html_escape(s) }
    run("escape/unwrapped/#{i}") { ERB::Util.unwrapped_html_escape(s) }
    run("escape/html_escape_once/#{i}") { ERB::Util.html_escape_once(s) }
    run("escape/json_escape/#{i}") { ERB::Util.json_escape(s) }
    run("escape/url_encode/#{i}") { ERB::Util.url_encode(s) }
    run("escape/xml_name_escape/#{i}") { ERB::Util.xml_name_escape(s) }
    run("escape/tokenize/#{i}") { ERB::Util.tokenize(s) } if ERB::Util.respond_to?(:tokenize)
    run("escape/sb_concat/#{i}") { b = s.html_safe; [b + o, b << o, b.safe_concat(o), b.concat(o.html_safe), o.html_safe + s] }
    run("escape/sb_ops/#{i}") { b = s.html_safe; [b * 2, b % [], b[0, 2], b.gsub("a", "<"), b.sub(/./) { "&" }, b.upcase, b.strip, b.split(" "), b.squish, b.to_param, b.dup, b.clone, b.encode("UTF-16LE")] }
    run("escape/sb_format/#{i}") { "%s|%s".html_safe % [s, s.html_safe] }
    run("escape/sb_interp/#{i}") { b = ActiveSupport::SafeBuffer.new; b << s; b.insert(0, o); b.prepend("<"); b.replace(b.to_str); [b, b.html_safe?] }
    run("escape/escape_js/#{i}") { av.escape_javascript(s) }
    run("escape/strip_tags/#{i}") { av.strip_tags(s + "<b>x</b>") }
    run("escape/strip_links/#{i}") { av.strip_links("<a href='x'>#{s}</a>") }
    run("escape/sanitize/#{i}") { av.sanitize("<p onclick='x'>#{s}</p><script>1</script>") }
    run("escape/simple_format/#{i}") { av.simple_format(s) }
    run("escape/truncate/#{i}") { [av.truncate(s, length: 8), av.truncate(s, length: 8, escape: false), av.truncate(s.html_safe, length: 8)] }
    run("escape/highlight/#{i}") { av.highlight(s, s.first(2)) }
    run("escape/excerpt/#{i}") { av.excerpt(s, s[1, 2].to_s, radius: 2) }
    run("escape/word_wrap/#{i}") { av.word_wrap(s, line_width: 4) }
    run("escape/link_to/#{i}") { [av.link_to(s, s), av.link_to(s.html_safe, "/x?a=#{s}"), av.mail_to(s), av.button_to(s, "/p")] }
    run("escape/tag_content/#{i}") { [av.content_tag(:p, s), av.tag.div(s), av.content_tag(:p) { s }, av.tag.p(s.html_safe)] }
    run("escape/tag_name/#{i}") { av.content_tag(s, "x") }
    run("escape/cdata/#{i}") { [av.cdata_section(s), av.escape_once(s)] }
    run("escape/javascript_tag/#{i}") { av.javascript_tag(s) }
    run("escape/safe_join/#{i}") { [av.safe_join([s, o.html_safe], s), av.safe_join([[s], s]), av.to_sentence([s, o]) ] }
    run("escape/raw/#{i}") { [av.raw(s), ERB::Util.h(s), ERB::Util.h(s.html_safe)] }
  end
  TAG_INPUTS.each_with_index do |t, i|
    attrs = aval(t[:attrs])
    content = aval(t[:content])
    run("escape/tag_builder/#{i}") { av.tag.public_send(t[:name].tr("-", "_"), content, **attrs.transform_keys(&:to_sym)) }
    run("escape/content_tag/#{i}") { av.content_tag(t[:name], content, attrs) }
    run("escape/content_tag_noesc/#{i}") { av.content_tag(t[:name], content, attrs, false) }
    run("escape/tag_open/#{i}") { av.tag(t[:name], attrs, true) }
    run("escape/tag_attributes/#{i}") { av.tag.attributes(attrs) }
    run("escape/class_names/#{i}") { [av.class_names(*attrs.values), av.token_list(attrs)] }
    run("escape/tag_options/#{i}") { av.tag.tag_options(attrs) }
    run("escape/link_attrs/#{i}") { av.link_to(content.to_s, "/x", attrs) }
    run("escape/form_tags/#{i}") { [av.text_field_tag(t[:name], content, attrs), av.hidden_field_tag(t[:name], content), av.check_box_tag(t[:name], content, true, attrs), av.label_tag(t[:name], content), av.select_tag(t[:name], av.options_for_select([[content.to_s, content.to_s], ["<x>", 1]], content.to_s))] }
  end
end

# ---- Routes ---------------------------------------------------------------------------------------------
%w[posts admin/users pages files posts/comments comments home search localized].each do |c|
  name = c.split("/").map(&:camelize).join("::") + "Controller"
  mod = name.split("::")[0..-2].inject(Object) { |m, n| m.const_defined?(n, false) ? m.const_get(n) : m.const_set(n, Module.new) }
  mod.const_set(name.split("::").last, Class.new(ActionController::Base)) unless mod.const_defined?(name.split("::").last, false)
end
RObj = Struct.new(:id) do
  def to_param = id.nil? ? nil : "obj-#{id}"
  def persisted? = true
  def model_name = ActiveModel::Name.new(self.class, nil, "Post")
end
section("routes") do
  rs = ActionDispatch::Routing::RouteSet.new
  rs.draw do
    root "home#index"
    resources :posts do
      resources :comments
      get :preview, on: :member
      get :search, on: :collection
    end
    namespace(:admin) { resources :users, only: %i[index show] }
    get "pages/:slug", to: "pages#show", as: :page, constraints: { slug: /[a-z0-9\-]+/ }
    get "files/*path", to: "files#show", as: :file, format: false
    get "search(/:page)", to: "search#index", as: :search, defaults: { page: 1 }
    scope "(:locale)", locale: /en|de/ do
      get "localized", to: "localized#index", as: :localized
    end
    get "legacy/:id", to: redirect("/posts/%{id}")
  end
  rs.default_url_options = { host: "www.example.com" }
  h = Class.new { include rs.url_helpers }.new
  conv = ->(v) { v.is_a?(Array) && v[0] == :obj ? RObj.new(v[1]) : v }
  ROUTE_GEN.each_with_index do |opts, i|
    o = opts.transform_values { conv.(_1) }
    run("routes/url_for/#{i}") { h.url_for(o) }
    run("routes/url_for_path/#{i}") { h.url_for(o.merge(only_path: true)) }
    run("routes/extras/#{i}") { rs.generate_extras(o.except(:only_path, :host, :protocol, :port, :anchor, :trailing_slash, :script_name, :params)) }
  end
  NAMED_GEN.each_with_index do |(m, args, kw), i|
    run("routes/named/#{i}") { h.public_send(m, *args.map { conv.(_1) }, **kw) }
  end
  ROUTE_REC.each_with_index do |path, i|
    %w[GET POST PATCH DELETE].each do |verb|
      run("routes/recognize/#{verb}/#{i}") { rs.recognize_path(path, method: verb) }
    end
    run("routes/recognize_url/#{i}") { rs.recognize_path("http://www.example.com#{path}") }
  end
  run("routes/inspect") { rs.routes.map { |r| [r.name, r.verb, r.path.spec.to_s, r.defaults, r.requirements.transform_values(&:to_s)] } }
end

# ---- Active Record / Arel SQL ---------------------------------------------------------------------------
section("arel") do
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define do
    create_table(:authors) { |t| t.string :name; t.timestamps }
    create_table(:posts) do |t|
      t.string :title; t.text :body; t.boolean :published; t.integer :views; t.float :score
      t.datetime :published_at; t.references :author; t.integer :status; t.date :created_on; t.decimal :price, precision: 8, scale: 2
    end
    create_table(:comments) { |t| t.references :post; t.text :body }
  end
  Object.const_set(:Author, Class.new(ActiveRecord::Base) { has_many :posts })
  Object.const_set(:Comment, Class.new(ActiveRecord::Base) { belongs_to :post })
  Object.const_set(:Post, Class.new(ActiveRecord::Base) do
    belongs_to :author
    has_many :comments
    enum :status, { draft: 0, published: 1, archived: 2 }, prefix: true
    alias_attribute :headline, :title
  end)
  conv = lambda do |v|
    case v
    when Array
      case v[0]
      when :range then v[3] ? (v[1]...v[2]) : (v[1]..v[2])
      when :date then Date.new(1990, 1, 1) + v[1]
      when :time then Time.at(v[1]).utc
      when :sym then v[1].to_sym
      when :dec then BigDecimal(v[1])
      when :sub then Author.select(:id).where(name: "x")
      else v.map { conv.(_1) }
      end
    when Hash then v.to_h { |k, x| [k, conv.(x)] }
    else v
    end
  end
  ord = lambda do |a|
    case a
    when Symbol then a
    when Array
      case a[0]
      when :desc then { a[1] => :desc }
      when :str then a[1]
      when :arel then Post.arel_table[a[1]].desc
      when :hash_dir then { a[1] => a[2] }
      end
    end
  end
  AR_INPUTS.each_with_index do |ops, i|
    run("arel/sql/#{i}") do
      rel = ops.inject(Post.all) do |r, (op, arg)|
        case op
        when :where then r.where(conv.(arg))
        when :where_not then r.where.not(conv.(arg))
        when :or then r.where(conv.(arg).first(1).to_h).or(Post.where(conv.(arg)))
        when :order then r.order(*arg.map(&ord))
        when :reorder then r.reorder(*arg.map(&ord))
        when :joins then r.joins(arg)
        when :left_joins then r.left_joins(arg)
        when :includes then r.includes(arg).references(arg)
        when :group then r.group(*arg.map { _1 == :str ? "posts.title" : _1 })
        when :select then r.select(*arg.map { _1 == :str ? "posts.title AS t" : _1 })
        when :having then r.group(:author_id).having("COUNT(*) > ?", arg)
        when :limit then r.limit(arg)
        when :offset then r.offset(arg)
        when :distinct then r.distinct
        when :unscope_order then r.unscope(:order)
        when :rewhere then r.rewhere(conv.(arg))
        when :in_order_of then r.in_order_of(*arg)
        when :where_assoc then r.joins(arg[0]).where(arg[0] => arg[1])
        when :where_string then r.where("title = ? AND views > ?", *arg)
        when :where_named then r.where("title = :t OR views < :n", arg)
        when :not_and then r.where.not(conv.(arg)).where.not(id: nil)
        when :invert_where then r.where(conv.(arg)).invert_where
        when :excluding then r.excluding(Post.new(id: 3))
        when :none_or then r.none.or(Post.where(id: 1))
        when :where_tuple then r.where([:views, :title] => arg)
        when :order_nulls then r.order(Post.arel_table[arg[0]].asc.public_send(arg[1]))
        end
      end
      rel.to_sql
    end
  end
  arel = Post.arel_table
  ESC_INPUTS.first(300).each_with_index do |s, i|
    run("arel/preds/#{i}") { [arel[:title].eq(s), arel[:title].matches("%#{s}%"), arel[:title].does_not_match(s, "\\", true), arel[:title].in([s, nil]), arel[:views].between(1..s.size)].map(&:to_sql) }
    run("arel/sanitize/#{i}") { [Post.sanitize_sql_like(s), Post.sanitize_sql_array(["a = ?", s]), Post.sanitize_sql_for_order(s), Post.where(title: s).to_sql, Post.where("title LIKE ?", s).to_sql] }
    run("arel/quote/#{i}") { c = Post.lease_connection rescue Post.connection; [c.quote(s), c.quote_column_name(s), c.quote_table_name(s)] }
  end
end
$out.close
