# Differential harness, round 2: `bundle exec ruby harness2.rb OUT [SURFACE...]` inside a Rails checkout.
# Surfaces: view (HTML helpers and form builder), types (Active Model / Active Record casting and dirty
# tracking), sql (relation chains on the SQLite, PostgreSQL and MySQL visitors), recognize (path -> params ->
# url_for). Inputs reuse round 1's generators (harness.rb, same seed) and then continue the same random stream,
# all before Rails loads. Each case writes "surface/function/index<TAB>result-or-exception"; HTML results also
# get a "~norm" line with attributes sorted, so attribute-order changes can be told apart from content changes.
ARGV_SAVE = ARGV.dup
src = File.read(File.join(__dir__, "harness.rb")).split("# ---- Load Rails").first
ARGV.replace(["/dev/null"])
eval(src, binding, "harness.rb")
OUT2 = ARGV_SAVE.shift
ONLY2 = ARGV_SAVE

# ---- Inputs ---------------------------------------------------------------------------------------------
def rhtml(depth = 0)
  parts = Array.new(R.rand(1..4)) do
    case R.rand(depth > 1 ? 4 : 8)
    when 0, 1 then rstr(10)
    when 2 then pick(["&amp;", "&lt;", "&#39;", "&nbsp;", "&", "<", ">", "\"", "'", "\n", "\n\n", "\r\n", "  "])
    when 3 then pick(["<br>", "<br/>", "<hr>", "<!-- c -->", "<![CDATA[x]]>", "<script>alert(1)</script>", "<img src=x onerror=alert(1)>"])
    else
      tag = pick(%w[p a b i em strong div span ul li script style iframe img table td form input svg math])
      attrs = Array.new(R.rand(3)).map { "#{pick(%w[href src class style onclick title id data-x target rel])}=\"#{pick(["javascript:alert(1)", "http://x.org/?a=1&b=2", rstr(5), "", "x\" onmouseover=\"y", "data:text/html,x", "/p"])}\"" }.join(" ")
      "<#{tag}#{attrs.empty? ? "" : " " + attrs}>#{rhtml(depth + 1)}</#{tag}>"
    end
  end
  parts.join
end
HTML_INPUTS = ["", " ", "plain", "a\nb", "a\n\nb", "a\r\n\r\nb\nc", "<p>x</p>", "<b>bold</b> & <i>it</i>",
  "<a href=\"javascript:alert(1)\">x</a>", "<script>x</script>y", "<<b>>", "</p>", "<p", "a < b > c", "&amp;&lt;",
  "<img src=x onerror=alert(1)>", "<iframe src=//x></iframe>", "<div style=\"background:url(javascript:x)\">x</div>",
  "line1\n\n\nline2", "😀 <b>é</b>", "<!-- <script> -->", "<svg><script>x</script></svg>", "<math><mi>x</mi></math>"] +
  Array.new(N) { rhtml }

def ropts
  Array.new(R.rand(4)).to_h { [pick(ATTR_KEYS + %w[placeholder size maxlength autocomplete include_hidden form multiple] + [rstr(4)]).to_sym, rattr_val] }
end
PERSON_ATTRS = %i[name age admin role tags country_id birthday created_at bio score].freeze
def rperson
  {
    name: pick([nil, "", rstr(8), "<b>x</b>", "a\"b", "x" * 40]),
    age: pick([nil, 0, R.rand(-5..120), "12", "abc", 1.5]),
    admin: pick([nil, true, false, "1", "0", "yes", "", 1]),
    role: pick([nil, "admin", "user", "", :admin, "<x>", 3]),
    tags: pick([nil, [], [1, 2], ["1", "3"], ["a"], "1", [nil]]),
    country_id: pick([nil, 1, 2, "2", 99, ""]),
    birthday: pick([nil, [:date, R.rand(-30_000..30_000)], "2026-02-30", "", "2026-11-04"]),
    created_at: pick([nil, [:time, R.rand(0..2_000_000_000), 0, pick(ZONES)], "2026-11-04 10:00"]),
    bio: pick([nil, "", rstr(20), "a\nb", "</textarea><script>x</script>"]),
    score: pick([nil, 1.25, [:dec, "10.50"], "1e3", -0.0]),
  }
end
FORM_CASES = Array.new(N) do
  { person: rperson, opts: ropts, html: ropts,
    sel: { include_blank: pick([nil, true, false, "--", ""]), prompt: pick([nil, true, "Pick <one>"]), selected: pick([nil, "admin", 2, [1, 2]]),
           disabled: pick([nil, "user", [1], ->(_) { false }].first(3)), multiple: pick([nil, true]), include_hidden: pick([nil, false]) }.compact,
    choices: pick([%w[admin user], [["Admin", "admin"], ["User <u>", "user"]], { "Group" => %w[admin], "<G>" => [["User", "user"]] }, [], [[1, 1], [2, 2]], [["A", "admin", { disabled: true, class: "x" }]]]) }
end
TEXT_CASES = Array.new(N) do
  { s: pick(HTML_INPUTS), n: pick([0, 1, 2, -1, 1.5, "3", nil, 10**6]), w: rword, phrase: pick(["a", "x", "<b>", "", ["a", "e"], [:re, "[aeiou]+"], "é", " "]),
    len: pick([0, 1, 3, 10, 30, 1000]), sep: pick([nil, " ", ".", "\n", ""]), omission: pick([nil, "…", "<b>...</b>", ""]),
    radius: pick([0, 1, 5, 100]), tags: pick([nil, %w[a b], %w[script], %w[p br], []]), attrs: pick([nil, %w[href], %w[onclick style], []]),
    from: R.rand(-100_000_000..100_000_000), to: pick([0, R.rand(-200_000_000..200_000_000), R.rand(-200..200)]),
    zone: pick(ZONES) }
end

TYPE_NAMES = %i[big_integer binary boolean date datetime decimal float immutable_string integer string time json
  decimal_precision integer_limit2 datetime_precision0 time_precision3 string_limit decimal_without_scale
  pg_array pg_range pg_hstore pg_inet pg_cidr pg_uuid pg_money pg_point pg_bit pg_interval pg_jsonb pg_enum pg_xml
  pg_date_array pg_timestamptz pg_bytea mysql_unsigned_integer].freeze
def rtypeval
  case R.rand(16)
  when 0 then nil
  when 1 then pick(["", " ", "\t", "  1 ", "0", "1", "-1", "t", "f", "true", "FALSE", "on", "off", "nil", "null"])
  when 2 then R.rand(-10**20..10**20)
  when 3 then pick([2**31, 2**31 - 1, -2**31, -2**31 - 1, 2**63, 2**32, 32_768, -32_769, 0])
  when 4 then pick([0.1, -0.0, 1e20, 1.5, Float::NAN, Float::INFINITY, -Float::INFINITY, 2.675, 1e-7])
  when 5 then [:dec, pick(["1.005", "-0", "1e400", "123456789.123456789", "0.1", "NaN", "Infinity"])]
  when 6 then pick(["2026-11-04", "2026-02-29", "2024-02-29", "2026-13-01", "26-11-4", "11/04/2026", "2026-11-04T10:20:30Z",
    "2026-11-04 10:20:30.123456789", "2026-11-04 10:20:30 +05:30", "10:20", "25:61:61", "24:00:00", "0001-01-01", "9999-12-31 23:59:59.999999",
    "2026-03-08 02:30:00", "2026-10-25 02:30:00", "-0001-01-01", "2026-11-04 10:20:30.5 PST", "infinity", "-infinity", "1-1-1"])
  when 7 then [:date, R.rand(-800_000..800_000)]
  when 8 then [:time, R.rand(-60_000_000_000..60_000_000_000), R.rand(1_000_000), pick(ZONES)]
  when 9 then rstr(10)
  when 10 then pick(["{}", "[]", "{\"a\":1}", "[1,2", "null", "\"x\"", "{a: 1}", "1", "true", "{\"a\":{\"b\":[1,null]}}"])
  when 11 then pick([{}, { "a" => 1 }, { a: [1, nil] }, [], [1, [2, "3"]], [nil]])
  when 12 then pick(["{1,2,3}", "{}", "{NULL}", "{\"a,b\",c}", "{{1,2},{3,4}}", "[1,5)", "(,]", "empty", "\"a\"=>\"b\", \"c\"=>NULL", "192.168.0.1/24", "::1", "not-an-ip",
    "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", "{A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11}", "a0eebc999c0b4ef8bb6d6bb9bd380a11", "$1,234.50", "-$0.99", "(1.5,2)", "(1,2", "101", "x101",
    "P1Y2M3DT4H5M6.5S", "1 day 02:00:00", "<a/>", "\\x0001ff", "1.2.3.4"])
  when 13 then [:range, pick([nil, 1, "a", 1.5]), pick([nil, 5, "z", 2.5]), R.rand(2) == 0]
  when 14 then [:bin, Array.new(R.rand(6)) { R.rand(256) }]
  else pick([:sym, true, false, [1, 2], "1,234", "1_000", "0x1A", "1e3", "12abc", " 12", "١٢", "Ⅻ"])
  end
end
TYPE_INPUTS = Array.new(N) { [rtypeval, rtypeval] }
TYPE_ZONES = ["UTC", "America/New_York", "Asia/Kolkata", "Pacific/Chatham"].freeze

AR_OPS2 = AR_OPS + %i[merge merge_or and from_sub where_like where_gt where_in_sub optimizer reverse lock with]
AR_INPUTS2 = Array.new(N) do
  Array.new(1 + R.rand(4)) do
    op = pick(AR_OPS2)
    arg = case op
          when :merge, :merge_or, :and then pick([{ author: { name: rstr(3) } }, { comments: { body: nil } }, { id: [1, 2] }, :order, :joins])
          when :where_like then rstr(4)
          when :where_gt then [pick(%i[views score published_at created_on id]), rarval]
          when :order, :reorder then Array.new(1 + R.rand(2)) { pick([pick(AR_COLS), [:desc, pick(AR_COLS)], [:str, "title DESC"], [:arel, pick(AR_COLS)], [:hash_dir, pick(AR_COLS), pick(%w[asc desc])]]) }
          when :joins, :left_joins, :includes then pick([:author, :comments, [:author, :comments], { comments: :post }])
          when :group, :select then Array.new(1 + R.rand(2)) { pick(AR_COLS + [:str]) }
          when :having then R.rand(10)
          when :limit, :offset then pick([0, 1, 10, nil, "5"])
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

SEGS2 = %w[posts 1 42 edit new comments admin users u1 pages about files a b c.txt search en de fr api v1 v2 photos
  shallow sessions profile x.json x.y %20 %2F ü .. . - _ a%2Fb ~ + * ( ) ; , = @ ! $].freeze
REC_INPUTS = ["/", "/posts", "/posts/1", "/posts/1.json", "/posts/1/edit", "/posts/new", "/posts/1/comments/2",
  "/comments/2", "/admin/users/5", "/api/v1/photos/3.json", "/api/v2/photos/3", "/pages/about", "/files/a/b/c.txt",
  "/en/localized/3", "/localized/3", "/search", "/search/2", "/profile", "/sessions/new", "/legacy/7", "/posts/1%2F2",
  "/posts/%E2%9C%93", "/posts/1.", "/photos/archive/2026/11", "/photos/archive/2026", "/u/x.y.z", "/posts/1/comments/new.xml"] +
  Array.new(N) { "/" + Array.new(R.rand(1..5)) { pick(SEGS2) }.join("/") + pick(["", "", ".json", "/", ".x", ".html.erb"]) }

def rseg
  v = case R.rand(5)
      when 0 then R.rand(10**R.rand(1..12)).to_s
      when 1 then rstr(8, ("a".."z").to_a + %w[- _ . ~ 0 9])
      when 2 then rstr(6)
      when 3 then pick(["a.b", "a..b", "x.json", ".", "-", "%", "%2", "%2F", "%25", "%E2%9C%93", "%FF", "a b", "a+b", "ü", "\u00e9", "😀", "1,2", "a;b", "a=b", "(x)", "a%2Eb"])
      else rstr(4, %w[a 1 %20 %2F %2E . - _ ~ + : @ ! $ & ' * ( ) , ; =])
      end
  R.rand(3) == 0 ? v : v.gsub(/[^A-Za-z0-9\-._~%]/) { |c| c.bytes.map { format("%%%02X", _1) }.join }
end
REC_TEMPLATES = [
  -> { "/posts/#{rseg}" }, -> { "/posts/#{rseg}/edit" }, -> { "/posts/#{rseg}/preview" }, -> { "/posts/#{rseg}/comments" },
  -> { "/posts/#{rseg}/comments/new" }, -> { "/comments/#{rseg}/edit" }, -> { "/admin/users/#{rseg}" }, -> { "/api/v1/photos/#{rseg}" },
  -> { "/api/v2/photos/#{rseg}" }, -> { "/photos/archive/#{pick([R.rand(1000..9999).to_s, rseg])}" }, -> { "/photos/archive/#{R.rand(1900..2100)}/#{pick([R.rand(0..13).to_s, "01", "001", rseg])}" },
  -> { "/pages/#{rseg}" }, -> { "/files/#{Array.new(R.rand(1..4)) { rseg }.join("/")}" }, -> { "/#{pick(%w[en de fr EN])}/localized/#{rseg}" },
  -> { "/localized/#{rseg}" }, -> { "/search/#{rseg}" }, -> { "/u/#{rseg}" }, -> { "/legacy/#{rseg}" }, -> { "/sessions/login" }, -> { "/sessions/#{rseg}" },
]
REC_INPUTS2 = Array.new(N * 3) { pick(REC_TEMPLATES).call + pick(["", "", "", ".json", ".html", ".xml", "/", ".", ".a.b", "?x=1"]) }

DEC_INPUTS = Array.new(N) do
  pick([[:dec, format("%.#{R.rand(0..14)}f", (R.rand - 0.5) * 10**R.rand(0..12))], [:dec, pick(["1e-20", "1E+5", "-0.005", "0.5", "1.5", "2.5", "-2.5", "99999.995", "1e2", "12.345678901234567890123"])],
    (R.rand - 0.5) * 10**R.rand(-3..8), R.rand(-10**9..10**9), pick(["1.005", "  3.14 ", "1,5", "abc", "", "1e3", "-", ".5", "5."]), Rational(R.rand(1..100), R.rand(1..100))])
end
DEC_TYPES = [[nil, nil], [5, 2], [10, 0], [3, 3], [20, 10], [8, -2], [nil, 2], [5, nil], [38, 18]].freeze
UUID_INPUTS = ["a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", "A0EEBC99-9C0B-4EF8-BB6D-6BB9BD380A11", "{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}",
  "a0eebc999c0b4ef8bb6d6bb9bd380a11", "a0ee-bc99-9c0b-4ef8-bb6d-6bb9-bd38-0a11", "{a0eebc99-9c0b4ef8-bb6d6bb9-bd380a11}", "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a1",
  "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a111", "g0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", " a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11\n",
  "", nil, 1, "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11 ", "{a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11", "a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11}", "00000000-0000-0000-0000-000000000000"] +
  Array.new(N) { h = "0123456789abcdefABCDEF"; parts = [8, 4, 4, 4, 12].map { |n| Array.new(n + pick([0, 0, 0, 1, -1])) { pick(h.chars + (R.rand(30) == 0 ? ["g", " "] : [])) }.join }
    raw = pick([parts.join("-"), parts.join, "{" + parts.join("-") + "}", parts.each_slice(2).map(&:join).join("-"), parts.join("-").upcase])
    raw }
MODEL_CASES = Array.new(N) { Array.new(3) { %i[title body published views score published_at created_on price status author_id].to_h { |c| [c, rtypeval] } } }

# ---- Load Rails ---------------------------------------------------------------------------------------
require "bigdecimal"
require "set"
require "active_support"
require "active_support/all"
require "action_view"
require "action_controller"
require "action_dispatch"
require "active_record"
require "nokogiri"

$out = File.open(OUT2, "w")
def rep(v)
  s = case v
      when ActiveSupport::SafeBuffer then "SB(#{v.html_safe?})#{v.to_str.inspect}"
      when ActiveSupport::TimeWithZone then "TWZ #{v.inspect} [#{v.time_zone.name}] #{v.to_r}"
      when Time then "T #{v.inspect} #{v.utc_offset} #{v.zone.inspect}"
      when DateTime then "DT #{v.inspect}"
      when BigDecimal then "BD #{v.to_s} prec?#{v.precision}"
      when ActiveSupport::Duration then "D #{v.inspect} #{v.parts.sort_by { |k, _| k.to_s }.inspect}"
      when String then (v.frozen? ? "F:" : "") + (v.encoding == Encoding::UTF_8 ? v.inspect : "#{v.encoding}:#{v.inspect}")
      when Array then "[" + v.map { rep(_1) }.join(", ") + "]"
      when Hash then "{" + v.map { |k, x| "#{rep(k)}=>#{rep(x)}" }.join(", ") + "}"
      when Range then "Range(#{rep(v.begin)}#{v.exclude_end? ? "..." : ".."}#{rep(v.end)})"
      else "#{v.class}:#{v.inspect}"
      end
  s = s.gsub(/0x\h{6,}/, "0x")
  s.size > 4000 ? s[0, 4000] + "…" : s
end
def norm_html(s)
  frag = Nokogiri::HTML5.fragment(s.to_str)
  frag.traverse { |n| next unless n.element?; attrs = n.attribute_nodes.map { [_1.name, _1.value] }.sort; attrs.each { |k, _| n.remove_attribute(k) }; attrs.each { |k, v| n[k] = v } }
  frag.to_html.inspect
rescue => e
  "norm-error #{e.class}"
end
def run(key, html: false)
  v = nil
  r = begin
    v = yield
    rep(v)
  rescue Exception => e
    raise if e.is_a?(Interrupt) || e.is_a?(NoMemoryError)
    v = nil
    "!#{e.class}: #{e.message.to_s.gsub("\n", "\\n").gsub(/0x\h{6,}/, "0x").gsub(/#<[A-Z][\w:]*:0x>/, "#<obj>")[0, 400]}"
  end
  $out.puts "#{key}\t#{r}"
  $out.puts "#{key}~norm\t#{norm_html(v)}" if html && v.is_a?(String)
end
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
def section2(name) = (ONLY2.empty? || ONLY2.include?(name)) && yield
def tval(v)
  case v
  when Array
    case v[0]
    when :dec then BigDecimal(v[1]) rescue v[1]
    when :date then Date.new(2000, 1, 1) + v[1]
    when :time then Time.at(v[1], v[2]).in_time_zone(v[3])
    when :range then (v[3] ? (v[1]...v[2]) : (v[1]..v[2]) rescue "#{v[1]}..#{v[2]}")
    when :bin then v[1].pack("C*")
    else v.map { tval(_1) }
    end
  else v
  end
end

# ---- View helpers -----------------------------------------------------------------------------------------
class Person
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :name; attribute :age; attribute :admin; attribute :role; attribute :tags; attribute :country_id
  attribute :birthday; attribute :created_at; attribute :bio; attribute :score
  def persisted? = false
  def id = 7
end
Country = Struct.new(:id, :name, :cities)
City = Struct.new(:id, :name)
COUNTRIES = [Country.new(1, "Österreich", [City.new(10, "Wien")]), Country.new(2, "<Danger>", [City.new(20, "A&B"), City.new(21, "")]), Country.new(nil, "Nil", [])].freeze
section2("view") do
  I18n.available_locales = [:en]
  av = ActionView::Base.empty
  FORM_CASES.each_with_index do |c, i|
    p = Person.new(c[:person].transform_values { tval(_1) })
    f = ActionView::Helpers::FormBuilder.new(:person, p, av, {})
    plain = ->(x) { ENV["VIEW_PLAIN"] ? x.reject { |k, v| (v.is_a?(Hash) && !%i[data aria].include?(k)) || %i[hidden open].include?(k) || k.to_s.strip.empty? } : x }
    o = aval(plain.(c[:opts])); h = aval(plain.(c[:html])); sel = c[:sel]
    k = "view/form"
    run("#{k}/text_field/#{i}", html: true) { f.text_field(:name, o) }
    run("#{k}/number_field/#{i}", html: true) { f.number_field(:age, o) }
    run("#{k}/hidden_field/#{i}", html: true) { f.hidden_field(:role, o) }
    run("#{k}/password_field/#{i}", html: true) { f.password_field(:name, o) }
    run("#{k}/email_field/#{i}", html: true) { f.email_field(:name, o) }
    run("#{k}/text_area/#{i}", html: true) { f.text_area(:bio, o) }
    run("#{k}/date_field/#{i}", html: true) { f.date_field(:birthday, o) }
    run("#{k}/datetime_field/#{i}", html: true) { f.datetime_local_field(:created_at, o) }
    run("#{k}/time_field/#{i}", html: true) { f.time_field(:created_at, o) }
    run("#{k}/check_box/#{i}", html: true) { f.check_box(:admin, o) }
    run("#{k}/check_box_values/#{i}", html: true) { f.check_box(:role, o, "admin", "none") }
    run("#{k}/radio_button/#{i}", html: true) { f.radio_button(:role, pick(["admin", "user", "", "<x>", 3]), o) }
    run("#{k}/label/#{i}", html: true) { f.label(:name, c[:person][:name], o) }
    run("#{k}/label_block/#{i}", html: true) { f.label(:bio, o) { "<b>#{c[:person][:bio]}</b>".html_safe } }
    run("#{k}/select/#{i}", html: true) { f.select(:role, c[:choices], sel, h) }
    run("#{k}/select_tags/#{i}", html: true) { f.select(:tags, c[:choices], sel.merge(multiple: true), h) }
    run("#{k}/collection_select/#{i}", html: true) { f.collection_select(:country_id, COUNTRIES, :id, :name, sel, h) }
    run("#{k}/grouped_select/#{i}", html: true) { f.grouped_collection_select(:country_id, COUNTRIES, :cities, :name, :id, :name, sel, h) }
    run("#{k}/collection_check_boxes/#{i}", html: true) { f.collection_check_boxes(:tags, COUNTRIES, :id, :name, sel, h) }
    run("#{k}/collection_radio/#{i}", html: true) { f.collection_radio_buttons(:country_id, COUNTRIES, :id, :name, sel, h) }
    run("#{k}/options_for_select/#{i}", html: true) { av.options_for_select(c[:choices].is_a?(Hash) ? c[:choices].values.flatten(1) : c[:choices], sel[:selected]) }
    run("#{k}/grouped_options/#{i}", html: true) { av.grouped_options_for_select(c[:choices].is_a?(Hash) ? c[:choices] : { "G" => c[:choices] }, sel[:selected], prompt: sel[:prompt]) }
    run("#{k}/select_tag/#{i}", html: true) { av.select_tag(c[:person][:name].to_s, av.options_for_select(%w[a b]), sel.slice(:include_blank, :prompt, :multiple).merge(h)) }
    run("#{k}/fields/#{i}", html: true) { av.fields(:person, model: p) { |ff| ff.text_field(:name) + ff.check_box(:admin, o) } }
    if i % 10 == 0
      run("#{k}/date_select/#{i}", html: true) { f.date_select(:birthday, { start_year: 2020, end_year: 2022, include_blank: sel[:include_blank], prompt: sel[:prompt] }.compact, h) }
      run("#{k}/datetime_select/#{i}", html: true) { f.datetime_select(:created_at, { start_year: 2026, end_year: 2026, minute_step: 15, ampm: i % 20 == 0 }, h) }
      run("#{k}/time_select/#{i}", html: true) { f.time_select(:created_at, { include_seconds: true, prompt: sel[:prompt] }.compact, h) }
      run("#{k}/time_zone_select/#{i}", html: true) { f.time_zone_select(:role, ActiveSupport::TimeZone.us_zones, sel.slice(:include_blank), h) }
    end
    run("#{k}/button/#{i}", html: true) { [f.submit(c[:person][:name], h), f.button(c[:person][:name], h)].join }
    run("#{k}/value/#{i}", html: true) { f.text_field(:age, o.merge(value: c[:person][:score].then { tval(_1) })) }
  end
  TEXT_CASES.each_with_index do |c, i|
    s = c[:s]; ph = c[:phrase].is_a?(Array) && c[:phrase][0] == :re ? Regexp.new(c[:phrase][1]) : c[:phrase]
    k = "view/text"
    run("#{k}/pluralize/#{i}") { [av.pluralize(c[:n], c[:w]), av.pluralize(c[:n], c[:w], plural: "#{c[:w]}z")] }
    run("#{k}/truncate/#{i}", html: true) { av.truncate(s, length: c[:len], separator: c[:sep], omission: c[:omission] || "...") }
    run("#{k}/truncate_raw/#{i}", html: true) { av.truncate(s.html_safe, length: c[:len], escape: false) { "<a>more</a>" } }
    run("#{k}/simple_format/#{i}", html: true) { av.simple_format(s, { class: c[:w] }, wrapper_tag: pick(%w[p div span]), sanitize: c[:len].odd?) }
    run("#{k}/simple_format_opts/#{i}", html: true) { av.simple_format(s, {}, sanitize_options: { tags: c[:tags] || %w[b], attributes: c[:attrs] || [] }) }
    run("#{k}/highlight/#{i}", html: true) { av.highlight(s, ph) }
    run("#{k}/highlight_block/#{i}", html: true) { av.highlight(s, ph, sanitize: c[:len].even?) { |m| "<mark class=\"#{c[:w]}\">#{m}</mark>" } }
    run("#{k}/highlight_tpl/#{i}", html: true) { av.highlight(s, ph, highlighter: '<em>\1</em>') }
    run("#{k}/excerpt/#{i}", html: true) { av.excerpt(s, ph.is_a?(Array) ? ph.first : ph, radius: c[:radius], omission: c[:omission] || "...", separator: c[:sep] || "") }
    run("#{k}/word_wrap/#{i}", html: true) { av.word_wrap(s, line_width: [c[:len], 1].max, break_sequence: c[:sep] || "\n") }
    run("#{k}/sanitize/#{i}", html: true) { av.sanitize(s, tags: c[:tags], attributes: c[:attrs]) }
    run("#{k}/sanitize_default/#{i}", html: true) { av.sanitize(s) }
    run("#{k}/strip_tags/#{i}", html: true) { av.strip_tags(s) }
    run("#{k}/strip_links/#{i}", html: true) { av.strip_links(s) }
    run("#{k}/sanitize_css/#{i}") { av.sanitize_css(s) }
    run("#{k}/auto_discovery/#{i}", html: true) { av.auto_discovery_link_tag(:rss, "/feed?x=#{c[:w]}", title: s) }
    run("#{k}/number/#{i}", html: true) { v = c[:n]; [av.number_to_currency(v, unit: c[:omission]), av.number_to_percentage(v, precision: c[:radius] % 4), av.number_to_human(v, units: { unit: c[:w], thousand: "<k>" }), av.number_to_human_size(v), av.number_with_delimiter(v, delimiter: c[:sep]), av.number_to_phone(v, area_code: true)].map(&:to_s).join("|") }
    run("#{k}/distance/#{i}") { Time.use_zone(c[:zone]) { f = Time.at(c[:from]); t = Time.at(c[:from] + c[:to]); [av.distance_of_time_in_words(f, t), av.distance_of_time_in_words(f, t, include_seconds: true), av.distance_of_time_in_words(f.to_date, t.to_date), av.distance_of_time_in_words(c[:to].abs)] } }
    run("#{k}/time_tag/#{i}", html: true) { Time.use_zone(c[:zone]) { [av.time_tag(Time.zone.at(c[:from])), av.time_tag(Time.zone.at(c[:from]).to_date, s), av.time_tag(Time.zone.at(c[:from]), format: :short)].join } }
    run("#{k}/tag_helpers/#{i}", html: true) { [av.content_tag(:p, s, class: [c[:w], nil, s], data: { x: s, y: [1, s] }), av.tag.span(s, aria: { label: s, hidden: c[:n] }), av.link_to(s, "/x?q=#{c[:w]}", title: s, data: { confirm: s }), av.mail_to("#{c[:w]}@x.org", s, subject: s, body: s), av.phone_to(c[:n].to_s, s)].join }
  end
end

# ---- Types --------------------------------------------------------------------------------------------------
def load_types
  require "active_record/connection_adapters/postgresql_adapter"
  require "active_record/connection_adapters/mysql2_adapter"
  pg = ActiveRecord::ConnectionAdapters::PostgreSQL::OID
  am = ActiveModel::Type
  {
    big_integer: am::BigInteger.new, binary: am::Binary.new, boolean: am::Boolean.new, date: am::Date.new, datetime: am::DateTime.new,
    decimal: am::Decimal.new, float: am::Float.new, immutable_string: am::ImmutableString.new, integer: am::Integer.new, string: am::String.new,
    time: am::Time.new, json: ActiveRecord::Type::Json.new, decimal_precision: am::Decimal.new(precision: 5, scale: 2),
    integer_limit2: am::Integer.new(limit: 2), datetime_precision0: am::DateTime.new(precision: 0), time_precision3: am::Time.new(precision: 3),
    string_limit: am::String.new(limit: 3), decimal_without_scale: ActiveRecord::Type::DecimalWithoutScale.new,
    pg_array: pg::Array.new(am::Integer.new), pg_range: pg::Range.new(am::Integer.new, :int4range), pg_hstore: pg::Hstore.new,
    pg_inet: pg::Inet.new, pg_cidr: pg::Cidr.new, pg_uuid: pg::Uuid.new, pg_money: pg::Money.new, pg_point: pg::Point.new,
    pg_bit: pg::Bit.new, pg_interval: pg::Interval.new, pg_jsonb: pg::Jsonb.new, pg_enum: pg::Enum.new, pg_xml: pg::Xml.new,
    pg_date_array: pg::Array.new(pg::Date.new), pg_timestamptz: pg::TimestampWithTimeZone.new, pg_bytea: pg::Bytea.new,
    mysql_unsigned_integer: ActiveRecord::Type::UnsignedInteger.new,
  }
end
class TypedThing
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
end
section2("types") do
  types = load_types
  TYPE_NAMES.each { |n| TypedThing.attribute(n, types.fetch(n)) }
  TYPE_ZONES.each do |zone|
    Time.use_zone(zone) do
      TYPE_INPUTS.each_with_index do |(a, b), i|
        next if zone != "UTC" && i % 4 != 0
        va = tval(a); vb = tval(b)
        types.each do |name, t|
          k = "types/#{name}/#{zone}/#{i}"
          run("#{k}/cast") { t.cast(va) }
          run("#{k}/serialize") { t.serialize(t.cast(va)) }
          run("#{k}/serialize_raw") { t.serialize(va) }
          run("#{k}/deserialize") { t.deserialize(va.is_a?(String) || va.nil? ? va : va.to_s) }
          run("#{k}/serializable") { t.serializable?(va) }
          run("#{k}/changed") { old = t.cast(va); [t.changed?(old, t.cast(vb), vb), t.changed?(old, t.cast(va), va), t.changed_in_place?(t.serialize(old), old)] }
        end
        run("types/dirty/#{zone}/#{i}") do
          th = TypedThing.new
          TYPE_NAMES.each { |n| th.public_send("#{n}=", va) rescue nil }
          th.changes_applied
          TYPE_NAMES.each { |n| th.public_send("#{n}=", vb) rescue nil }
          first = th.changed.sort
          th.changes_applied
          TYPE_NAMES.each { |n| th.public_send("#{n}=", vb) rescue nil }
          [first, th.changed.sort]
        end
      end
    end
  end
end

section2("types2") do
  load_types
  pg = ActiveRecord::ConnectionAdapters::PostgreSQL::OID
  DEC_TYPES.each do |prec, scale|
    t = ActiveModel::Type::Decimal.new(precision: prec, scale: scale)
    DEC_INPUTS.each_with_index do |v, i|
      x = tval(v)
      run("types2/decimal_#{prec}_#{scale}/#{i}") { c = t.cast(x); [c, c.is_a?(BigDecimal) ? [c.precision, c.scale] : nil, t.serialize(c), t.changed?(c, t.cast(x.to_s), x.to_s)] }
    end
  end
  [ActiveModel::Type::BigInteger.new, ActiveModel::Type::Integer.new(limit: 8), ActiveModel::Type::Float.new].each do |t|
    DEC_INPUTS.each_with_index { |v, i| run("types2/#{t.class.name.demodulize}#{t.limit}/#{i}") { x = tval(v); [t.cast(x), t.cast(x.to_s), t.cast("#{x}abc"), t.cast(" #{x}")] } }
  end
  u = pg::Uuid.new
  UUID_INPUTS.each_with_index { |v, i| run("types2/uuid/#{i}") { [u.cast(v), u.deserialize(v), u.serialize(v), u.changed?(u.cast(v), u.cast(v.to_s.upcase), v)] } }
  sz = ActiveRecord::Type::Serialized.new(ActiveModel::Type::String.new, ActiveRecord::Coders::JSON.new)
  imm = ActiveRecord::Type::Serialized.new(ActiveModel::Type::ImmutableString.new, ActiveRecord::Coders::JSON.new)
  TYPE_INPUTS.first(500).each_with_index do |(a, _), i|
    x = tval(a)
    [[:serialized, sz], [:serialized_imm, imm]].each do |n, t|
      run("types2/#{n}/#{i}") { c = t.cast(x); raw = t.serialize(c); d = t.deserialize(raw); m = d.is_a?(Hash) ? d.merge("z" => 1) : d.is_a?(Array) ? d + [1] : d.is_a?(String) ? d + "!" : d; [raw, d, t.changed_in_place?(raw, d), (d.is_a?(String) && !d.frozen? ? (d << "x"; t.changed_in_place?(raw, d)) : :skip)] }
    end
  end
end

# ---- SQL on three visitors ----------------------------------------------------------------------------------
def define_models
  return if defined?(::Post)
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
  ActiveRecord::Base.connection.execute("INSERT INTO authors (id, name, created_at, updated_at) VALUES (1, 'a', '2026-01-01', '2026-01-01'), (2, 'b''c', '2026-01-01', '2026-01-01')")
  20.times { |n| ActiveRecord::Base.connection.execute("INSERT INTO posts (id, title, body, published, views, score, published_at, author_id, status, created_on, price) VALUES (#{n + 1}, 't#{n % 5}', #{n.even? ? "NULL" : "'b'"}, #{n % 2}, #{n * 3}, #{n / 3.0}, '2026-0#{1 + n % 9}-01 10:00:00', #{1 + n % 3}, #{n % 3}, '2026-01-#{10 + n}', #{n}.5)") }
  10.times { |n| ActiveRecord::Base.connection.execute("INSERT INTO comments (id, post_id, body) VALUES (#{n + 1}, #{1 + n % 4}, 'c#{n}')") }
end
module PureQuoting
  def quote_string(s) = s.gsub("\\", "\\\\\\\\").gsub("'", "''")
end
def offline_adapters
  require "active_record/connection_adapters/postgresql_adapter"
  require "active_record/connection_adapters/mysql2_adapter"
  pg = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.new(adapter: "postgresql", database: "x", prepared_statements: false)
  my = ActiveRecord::ConnectionAdapters::Mysql2Adapter.new(adapter: "mysql2", database: "x", prepared_statements: false)
  [pg, my].each { |a| a.singleton_class.prepend(PureQuoting) }
  my.define_singleton_method(:get_database_version) { ActiveRecord::ConnectionAdapters::AbstractAdapter::Version.new("8.0.36") }
  my.define_singleton_method(:database_version) { get_database_version }
  my.define_singleton_method(:mariadb?) { false }
  pg.define_singleton_method(:get_database_version) { 170000 }
  pg.define_singleton_method(:database_version) { 170000 }
  { pg: pg, mysql: my }
end
section2("sql") do
  define_models
  adapters = offline_adapters
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
  merged = lambda do |arg|
    case arg
    when :order then Post.order(:id)
    when :joins then Post.joins(:author)
    when Hash then arg.key?(:id) ? Post.where(arg) : Post.joins(arg.keys.first).where(arg)
    end
  end
  AR_INPUTS2.each_with_index do |ops, i|
    rel = begin
      ops.inject(Post.all) do |r, (op, arg)|
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
        when :merge then r.merge(merged.(arg))
        when :merge_or then r.or(merged.(arg))
        when :and then r.and(merged.(arg))
        when :from_sub then r.from(Post.where(views: 1..), :posts)
        when :where_like then r.where(Post.arel_table[:title].matches("%#{Post.sanitize_sql_like(arg)}%"))
        when :where_gt then r.where(arg[0] => conv.(arg[1])..)
        when :where_in_sub then r.where(author_id: Author.where(name: arg.is_a?(Hash) ? "a" : "b").select(:id))
        when :optimizer then r.optimizer_hints("NO_INDEX_MERGE(posts)")
        when :reverse then r.reverse_order
        when :lock then r.lock
        when :with then r.with(recent: Post.where(views: 1..)).joins("JOIN recent ON recent.id = posts.id")
        end
      end
    rescue => e
      e
    end
    if rel.is_a?(Exception)
      run("sql/build/#{i}") { raise rel }
      next
    end
    run("sql/sqlite/#{i}") { rel.to_sql }
    adapters.each { |name, a| run("sql/#{name}/#{i}") { a.to_sql(rel.arel) } }
    run("sql/rows/#{i}") { rel.limit_value && rel.limit_value.to_i > 1000 ? nil : rel.to_a.map { |p| p.attributes.values_at("id", "title") rescue p.attributes.to_a } }
  end
end

section2("model") do
  define_models
  ActiveRecord::Base.time_zone_aware_attributes = true
  MODEL_CASES.each_with_index do |(a, b, c), i|
    conv = ->(h) { h.transform_values { tval(_1) }.tap { |x| x[:status] = %w[draft published archived bogus].fetch(i % 4) } }
    zone = TYPE_ZONES[i % TYPE_ZONES.size]
    Time.use_zone(zone) do
      run("model/new/#{i}") { p = Post.new(conv.(a)); [p.attributes, p.changed.sort, p.attributes_before_type_cast.transform_values(&:inspect), p.valid?] }
      run("model/assign/#{i}") { p = Post.new(conv.(a)); p.assign_attributes(conv.(b)); [p.changes.transform_values(&:inspect), p.changed_attributes.keys.sort] }
      run("model/save/#{i}") do
        p = Post.new(conv.(a))
        saved = (p.save! rescue $!.class)
        r = p.persisted? ? Post.find(p.id) : nil
        r2 = r && (r.assign_attributes(conv.(c)); [r.changed.sort, r.changes.transform_values(&:inspect), (r.save! rescue $!.class), r.saved_changes.keys.sort, r.previous_changes.keys.sort])
        rr = r && Post.find(p.id)
        srt = ->(h) { h && h.except("id").sort.to_h }
        [saved, srt.(r && r.attributes), r2 && [r2[0], r2[1].sort.to_h, *r2[2..]], srt.(rr && rr.attributes)]
      end
      run("model/order/#{i}") { p = Post.new(conv.(a)); r = (p.save! && Post.find(p.id) rescue nil); [r && r.attributes.keys, r && r.attribute_names, r && r.inspect.sub(/id: \d+/, "id: _")] }
      run("model/dup_nan/#{i}") { p = Post.new(conv.(a)); d = p.dup; p.attributes.keys.reject { |k| v = p.attributes[k]; v == d.attributes[k] || (v.respond_to?(:nan?) && v.nan? && d.attributes[k].nan?) } }
      run("model/dup/#{i}") { p = Post.new(conv.(a)); d = p.dup; cl = p.clone(freeze: true); [d.attributes == p.attributes, d.changed.sort, cl.frozen?, (cl.title = "x" rescue $!.class), p.serializable_hash.keys.sort, p.as_json.except("id")] }
      run("model/where/#{i}") { h = conv.(b).slice(:title, :views, :published, :created_on, :price); Post.where(h).to_sql }
    end
  end
end

# ---- Recognition round trip ---------------------------------------------------------------------------------
%w[posts admin/users pages files posts/comments comments home search localized api/v1/photos api/v2/photos photos sessions profiles users].each do |c|
  name = c.split("/").map(&:camelize).join("::") + "Controller"
  mod = name.split("::")[0..-2].inject(Object) { |m, n| m.const_defined?(n, false) ? m.const_get(n) : m.const_set(n, Module.new) }
  mod.const_set(name.split("::").last, Class.new(ActionController::Base)) unless mod.const_defined?(name.split("::").last, false)
end
section2("recognize") do
  rs = ActionDispatch::Routing::RouteSet.new
  rs.draw do
    root "home#index"
    concern(:commentable) { resources :comments, shallow: true }
    resources :posts, concerns: :commentable do
      get :preview, on: :member
      collection { get :search }
    end
    namespace(:admin) { resources :users, only: %i[index show] }
    namespace(:api) do
      namespace(:v1) { resources :photos, only: %i[index show] }
      scope(module: :v2, path: "v2", as: :v2) { resources :photos, only: :show, constraints: { id: /\d+/ } }
    end
    get "photos/archive/:year(/:month)", to: "photos#archive", as: :photo_archive, constraints: { year: /\d{4}/, month: /\d{1,2}/ }
    get "pages/:slug", to: "pages#show", as: :page, constraints: { slug: /[a-z0-9\-]+/ }
    get "files/*path", to: "files#show", as: :file, format: false
    get "search(/:page)", to: "search#index", as: :search, defaults: { page: 1 }
    scope("(:locale)", locale: /en|de/) { get "localized/:id", to: "localized#show", as: :localized }
    resource :profile, only: %i[show edit update]
    resources :sessions, only: %i[new create destroy], path_names: { new: "login" }
    get "u/:id", to: "users#show", as: :user, constraints: { id: /[^\/]+/ }
    get "legacy/:id", to: redirect("/posts/%{id}")
  end
  (REC_INPUTS + REC_INPUTS2).each_with_index do |path, i|
    %w[GET POST PATCH PUT DELETE].each do |verb|
      params = nil
      run("recognize/path/#{verb}/#{i}") { params = rs.recognize_path(path, method: verb) }
      next unless params
      run("recognize/back/#{verb}/#{i}") { rs.path_for(params) }
      run("recognize/same/#{verb}/#{i}") { rs.path_for(params) == path }
      run("recognize/url_for/#{verb}/#{i}") { rs.url_for(params.merge(host: "example.org", only_path: true)) }
      run("recognize/named/#{verb}/#{i}") { r = rs.routes.find { |rt| rt.defaults.slice(:controller, :action) == params.slice(:controller, :action) && rt.name }; r && rs.url_helpers.public_send("#{r.name}_path", **params.except(:controller, :action)) }
    end
  end
end
$out.close
